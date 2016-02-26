#!/bin/bash


PY_SITE="`python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())"`"
PIP="`which pip`"
VERBOSE=""

function ppmessage_options()
{ 
    if [ "$2" = "-v" ];
    then
        VERBOSE="1"
    else
        VERBOSE=""
    fi
}

function ppmessage_err()
{
    echo "EEEE) $1"
    echo
    exit 1
}

function ppmessage_check_path()
{
    if [ ! -f ./dist.sh  ];
    then
        ppmessage_err "you should run under the first-level path of ppmessage!"
    fi
}

function ppmessage_help()
{
    echo "Usage:
  $0 <command> [options]

Commands:
  init-ppmessage              Init ppmessage databases and materials.
  local-oauth                 Set OAuth's domain name to local.
  dev                         Install development mode with current working directory.
  undev                       Uninstall development mode.
  status                      Show the status of installation mode.
  run                         Start ppmessage in foreground.
  proc                        Show the ppmessage processes.
  start                       Start ppmessage service.
  stop                        Stop ppmessage service.
  restart                     Restart ppmessage service.
  log                         View the ppmessage logs.
  ppmessage                   Deploy ppmessage.
  app-win32                   Create window desktop app.
  app-win64                   Create window desktop app.
  app-mac                     Create mac os x desktop app.
  app-android                 Create mac os x desktop app.
  app-ios                     Create mac os x desktop app.
  app-auto-update             Update app version in server

Options:
  -v                          Give more output.
"
}

function ppmessage_need_root()
{
    if [ $UID -ne 0 ];
    then
        ppmessage_err "you should run in root, or use sudo!"
    fi
}

function ppmessage_exec()
{
    if [ $VERBOSE ];
    then
        $*
    else
        $* >/dev/null 2>/dev/null
    fi
}

function ppmessage_init()
{
    case "$1" in
        ppmessage)
            ;;
        *)
            ppmessage_help
            return
            ;;
    esac

    cd ppmessage/init
    ppmessage_exec sh ./init-all-$1.sh
    cd - >/dev/null
}

function ppmessage_init_cache()
{
    cd ppmessage/init
    ppmessage_exec python db2cache.py
    cd - >/dev/null
}

function ppmessage_local_oauth()
{
    ppmessage_exec mysql -uroot -ptest ppmessage<<EOF
UPDATE oauth_settings SET domain_name = '127.0.0.1';
EOF
}

function ppmessage_dist()
{
    if [ -e tmp ];
    then
        ppmessage_err "uncleaned tmp, please remove it manually!"
    fi

    mkdir -p tmp
    cp -r ppmessage tmp/

    ppmessage_exec python -m compileall tmp/ppmessage

    if [ $? != 0 ];
    then
        ppmessage_err "compile failed!"
    fi

    find tmp/ppmessage/*/* -name \*.py |xargs rm
    cp setup.py tmp/
    cp setup.py tmp/ppmessage/

    cd tmp
    ppmessage_exec python setup.py bdist_egg install_egg_info
    if [ $? != 0 ];
    then
        ppmessage_err 'make egg failed!'
    fi

    cp -r dist ..
    cd - >/dev/null

    rm -fr tmp
}

function ppmessage_dev()
{
    if [ ! -d $PY_SITE ];
    then
        ppmessage_err 'can not find site-packages!'
    else
        echo "`pwd`" > $PY_SITE/ppmessage.pth
    fi
}

function ppmessage_undev()
{
    if [ ! -d $PY_SITE ];
    then
        ppmessage_err 'can not find site-packages!'
    elif [ -f "$PY_SITE/ppmessage.pth" ];
    then
        rm -f "$PY_SITE/ppmessage.pth"
    fi
}

function ppmessage_dev_status()
{
    if [ -f "$PY_SITE/ppmessage.pth" ];
    then
        echo "PPMESSAGE is installed in dev-mode."
    else
        echo "PPMESSAGE is not installed in dev-mode."
    fi
}

function ppmessage_working_path()
{
    cd /tmp

    WORKING_DIR="`python <<EOF
import os

try:
    import ppmessage

    print os.path.dirname(ppmessage.__file__)
except:
    pass

EOF`"

    cd - >/dev/null

    if [ -z "$WORKING_DIR" ];
    then
        echo 'can not find the working path of PPMESSAGE!'
    else
        echo 'PPMESSAGE.working_path =' $WORKING_DIR
    fi
}

function ppmessage_status()
{
    info="`$PIP show ppmessage 2>/dev/null`"
    if [ "$info" ];
    then
        echo "PPMESSAGE is installed in production-mode."
    else
        echo "PPMESSAGE is not installed in production-mode."
    fi
}

function ppmessage_run()
{
    ppmessage_exec supervisord -n -c ppmessage/conf/supervisord.nginx.conf
}

function ppmessage_proc()
{
    ps axu|grep "\-m ppmessage\."|grep -v grep
}

function ppmessage_supervisord_proc()
{
    ps axu|grep python|grep -v "\-m ppmessage\."|grep ppmessage|grep "\.py"|grep -v grep
}

function ppmessage_start()
{
    ppmessage_exec supervisord -c ppmessage/conf/supervisord.nginx.conf
}

function ppmessage_stop()
{
    SPID="`ps axu|grep supervisord|grep -v grep|awk '{print $2}'`"
    if [ -z $SPID ];
    then
        return
    fi

    ppmessage_exec kill $SPID
}

function ppmessage_log()
{
    if [ ! -d /usr/local/var/log ];
    then
        ppmessage_err "can not find ppmessage's log path!"
    fi

    tail -F /usr/local/var/log/*.log
}

function ppmessage_log_api()
{
    if [ ! -d /usr/local/var/log ];
    then
        ppmessage_err "can not find ppmessage's log path!"
    fi

    tail -F /usr/local/var/log/ppmessage-api-8922.log
}

function ppmessage_log_dis()
{
    if [ ! -d /usr/local/var/log ];
    then
        ppmessage_err "can not find ppmessage's log path!"
    fi

    tail -F /usr/local/var/log/ppmessage-dispatcher-8923.log
}

function ppmessage_log_pcs()
{
    if [ ! -d /usr/local/var/log ];
    then
        ppmessage_err "can not find ppmessage's log path!"
    fi

    tail -F /usr/local/var/log/ppmessage-pcsocket-8931.log
}

function ppmessage_log_cac()
{
    if [ ! -d /usr/local/var/log ];
    then
        ppmessage_err "can not find ppmessage's log path!"
    fi

    tail -F /usr/local/var/log/ppmessage-cache-8929.log
}

function ppmessage_log_mon()
{
    if [ ! -d /usr/local/var/log ];
    then
        ppmessage_err "can not find ppmessage's log path!"
    fi

    tail -F /usr/local/var/log/ppmessage-monitor-8937.log
}

function ppmessage_log_upl()
{
    if [ ! -d /usr/local/var/log ];
    then
        ppmessage_err "can not find ppmessage's log path!"
    fi

    tail -F /usr/local/var/log/ppmessage-upload-8928.log
}

function ppmessage_ppmessage()
{
    cat ppmessage/core/constant.py | sed -i.bak 's/DEV_MODE = True/DEV_MODE = False/g' ppmessage/core/constant.py
    cd ppmessage/ppcom/jquery/gulp; gulp; cd -
    cd ppmessage/pcapp/ppmessage-pc; gulp; cd -
    cd ppmessage/web/assets/build; gulp; cd -
}

function ppmessage_localhost()
{
    cat ppmessage/core/constant.py | sed -i.bak 's/DEV_MODE = False/DEV_MODE = True/g' ppmessage/core/constant.py
    cd ppmessage/ppcom/jquery/gulp; gulp --env dev; cd -
    cd ppmessage/pcapp/ppmessage-pc; gulp --env dev; cd -
    cd ppmessage/web/assets/build; gulp; cd -
}

function ppmessage_app_win32()
{
    cd ppmessage/pcapp/ppmessage-pc; npm run pack:win32; cd -;
}

function ppmessage_app_win64()
{
    cd ppmessage/pcapp/ppmessage-pc; npm run pack:win64; cd -;
}

function ppmessage_app_mac()
{
    cd ppmessage/pcapp/ppmessage-pc; npm run pack:osx; cd -;
}

function ppmessage_app_android()
{
    echo "Android";
    # cordova platform rm android; cordova platform add android; 
    cd ppmessage/pcapp/ppmessage-pc; cordova build android --release -- --gradleArg=-PcdvBuildMultipleApks=false; cd -;
    
}

function ppmessage_app_ios()
{
    echo "create iOS ipa";
    echo "cordova platform add ios first"
    # cordova platform rm ios; cordova platform add ios;
    cd ppmessage/pcapp/ppmessage-pc; cordova build ios --release --device --codeSignIdentity="iOS Distribution" --provisioningProfile="b00c5be6-cc46-4776-b7c3-02915a5c44ec"; cd -;
    
}

function ppmessage_app_dist_clean()
{
    PORTAL_DIST_DIR="ppmessage/web/assets/static/yvertical/portal/resources/app"
    rm -rf $PORTAL_DIST_DIR/ppmessage.*
}

function ppmessage_app_dist()
{
    echo "dist apps to portal download";
    PORTAL_DIST_DIR="ppmessage/web/assets/static/yvertical/portal/resources/app"
    
    ANDROID_APK_FILE="ppmessage/pcapp/ppmessage-pc/platforms/android/build/outputs/apk/android-release.apk"
    if [ -f $ANDROID_APK_FILE ];
    then
        cp $ANDROID_APK_FILE $PORTAL_DIST_DIR/ppmessage.apk 
    fi

    IOS_IPA_FILE="ppmessage/pcapp/ppmessage-pc/platforms/ios/build/device/ppmessage.ipa"
    if [ -f $IOS_IPA_FILE ];
    then
        cp $IOS_IPA_FILE $PORTAL_DIST_DIR
    fi

    MAC_DMG_FILE="ppmessage/pcapp/ppmessage-pc/electron/dist/osx/ppmessage.dmg"
    if [ -f $MAC_DMG_FILE ];
    then
        cp $MAC_DMG_FILE $PORTAL_DIST_DIR
    fi
    
    WIN64_INS_FILE="ppmessage/pcapp/ppmessage-pc/electron/dist/win64/ppmessage-win64-setup.exe"
    if [ -f $WIN64_INS_FILE ];
    then
        cp $WIN64_INS_FILE $PORTAL_DIST_DIR
    fi

    WIN32_INS_FILE="ppmessage/pcapp/ppmessage-pc/electron/dist/win32/ppmessage-win32-setup.exe"
    if [ -f $WIN32_INS_FILE ];
    then
        cp $WIN32_INS_FILE $PORTAL_DIST_DIR
    fi

}

function ppmessage_app_scp()
{
    echo "scp local apps to ppmessage.cn";
    LOCAL_APPS="ppmessage/web/assets/static/yvertical/portal/resources/app/ppmessage*"
    PPMESSAGE_CN_DIST_DIR="~/ppmessage/ppmessage/web/assets/static/yvertical/portal/resources/app/"

    expect <<EOF
    set timeout -1
    spawn bash -c "scp $LOCAL_APPS root@ppmessage.cn:$PPMESSAGE_CN_DIST_DIR"
    expect "*password:"
    send "YVERTICAL1q2w3e4r5t\n"
    expect eof
EOF
    
}

function ppmessage_app_auto_update()
{
    echo "ppmessage.cn auto update app info"
    expect <<EOF
    set timeout -1
    spawn bash -c "ssh root@ppmessage.cn 'cd ppmessage/ppmessage/init; python let-app-autoupdate.py'" 
    expect "*password:"
    send "YVERTICAL1q2w3e4r5t\n"
    expect eof
EOF
}

function ppmessage_app_scp_test()
{
    echo "scp local apps to 123.57.154.168";
    LOCAL_APPS="ppmessage/web/assets/static/yvertical/portal/resources/app/ppmessage*"
    PPMESSAGE_CN_DIST_DIR="~/ppmessage/ppmessage/web/assets/static/yvertical/portal/resources/app/"

    expect <<EOF
    set timeout -1
    spawn bash -c "scp $LOCAL_APPS root@123.57.154.168:$PPMESSAGE_CN_DIST_DIR"
    expect "*password:"
    send "YVERTICAL1q2w3e4r5t\n"
    expect eof
EOF
    
}

function ppmessage_app_auto_update_test()
{
    echo "123.57.154.168 auto update app info"
    expect <<EOF
    set timeout -1
    spawn bash -c "ssh root@123.57.154.168 'cd ppmessage/ppmessage/init; python let-app-autoupdate.py'" 
    expect "*password:"
    send "YVERTICAL1q2w3e4r5t\n"
    expect eof
EOF
}

### MAIN ###

echo

ppmessage_options $*
ppmessage_check_path

case "$1" in
    init-ppmessage)
        ppmessage_init ppmessage
        ;;

    init-cache)
        ppmessage_init_cache
        ;;

    local-oauth)
        ppmessage_local_oauth
        ;;

    dev)
        ppmessage_need_root
        ppmessage_dev
        echo "done!"
        ;;

    undev)
        ppmessage_need_root
        ppmessage_undev
        echo "done!"
        ;;

    status)
        ppmessage_dev_status
        ppmessage_status
        ppmessage_working_path
        ;;

    run)
        ppmessage_run
        ;;

    proc)
        ppmessage_proc
        ppmessage_supervisord_proc
        ;;

    start)
        ppmessage_start
        ;;

    stop)
        ppmessage_stop
        ;;

    restart)
        ppmessage_stop
        ppmessage_start
        ;;

    log)
        ppmessage_log
        ;;
    
    ppmessage)
        ppmessage_ppmessage
        ;;

    localhost)
        ppmessage_localhost
        ;;

    app-win32)
        ppmessage_app_win32
        ;;

    app-win64)
        ppmessage_app_win64
        ;;

    app-mac)
        ppmessage_app_mac
        ;;

    app-android)
        ppmessage_app_android
        ;;

    app-ios)
        ppmessage_app_ios
        ;;

    app-dist)
        ppmessage_app_dist
        ;;

    app-dist-clean)
        ppmessage_app_dist_clean
        ;;

    app-scp)
        ppmessage_app_scp
        ;;

    app-auto-update)
        ppmessage_app_auto_update
        ;;

    app-scp-test)
        ppmessage_app_scp_test
        ;;

    app-auto-update-test)
        ppmessage_app_auto_update_test
        ;;
    
    *)
        ppmessage_help
        exit 0
        ;;
esac


echo
exit 0
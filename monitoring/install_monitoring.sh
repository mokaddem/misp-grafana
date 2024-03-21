#!/bin/bash

set -e

Color_Off='\033[0m'       # Text Reset
BCyan='\033[1;36m'        # Bold Cyan
BGreen='\033[1;32m'       # Bold Green
BYellow='\033[1;33m'       # Bold Yellow
BRed='\033[1;31m'       # Bold Red

DBPASSWORD_MONITORING_USER="$(openssl rand -hex 32)"
INSTANCE_NAME=""

installZMQ() {
    echoProgress "MISP ZeroMQ" "installing" "Installing MISP ZMQ python requirements"
    pushd ..
    pushd src/
    sudo apt-get update && sudo apt-get install python3-venv
    python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
    echoProgress "MISP ZeroMQ" "done" "\n"
    popd
    popd
}

configureZMQ() {
    echoProgress "MISP ZeroMQ" "configuring" "Configuring MISP ZMQ python"
    pushd ..
    pushd src/
    vim .env
    echoProgress "MISP ZeroMQ" "done" "\n"
    popd
    popd
}

changeLogFormat() {
    echoProgress "Apache2" "configure" "Configuring apache2 to use time to serve request\n"
    echo "Make sure the \`combined\` log entry is set to the following:"
    echo ''
    echo 'LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\" %D" combined'
    echo ''
    echo 'Configuration file should be located here:'
    echo '/etc/apache2/apache2.conf'
    echo ''
    echo 'Make sure to restart apache2 afterward:'
    echo 'service apache2 restart'
    echoProgress "Apache2" "done" "\n"
}

enableMySQLPerfMonitoring() {
    echoProgress "MySQL" "configure" "Configuring MySQL Performance schema\n"
    echo "Enable MySQL Performance monitoring"
    echo "Make sure the performance_schema is enabled:"
    echo "[mysqld]"
    echo "performance_schema=ON"
    echo ""
    echo 'Configuration file should be located here:'
    echo '/etc/mysql/conf.d/mysql.cnf'
    echo ''
    echo 'Make sure to restart apache2 afterward:'
    echo 'service mysql restart'
    echoProgress "MySQL" "done" "\n"
}

createMonitoringUser() {
    echoProgress "MySQL" "user" "Creating monitoring user"
    echo "Create a monitoring user for the performance schema:"
    echo ""
    echo "CREATE USER 'monitoring'@'localhost' IDENTIFIED BY '$DBPASSWORD_MONITORING_USER';"
    echo "GRANT SELECT ON *.* TO 'monitoring'@'localhost';"
    echo "FLUSH PRIVILEGES;"
    echoProgress "MySQL" "done" "\n"
}

installTelegraf() {
    echoProgress "Telegraf" "installing" "Installing Telegraf"
    curl -s https://repos.influxdata.com/influxdata-archive_compat.key > influxdata-archive_compat.key
    echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdata-archive_compat.key' | sha256sum -c && cat influxdata-archive_compat.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
    echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | sudo tee /etc/apt/sources.list.d/influxdata.list
    sudo apt-get update && sudo apt-get install telegraf
    echoProgress "Telegraf" "done" "\n"
}

genTelegrafConfig() {
    echoProgress "Telegraf" "configuring" "Configuring Telegraf config"
    sed "s/{{\s*instance_name\s*}}/$INSTANCE_NAME/g" telegraf.conf.template > telegraf.conf
    sed "s/{{\s*db_password_monitoring_user\s*}}/$DBPASSWORD_MONITORING_USER/g" telegraf.conf.template > telegraf.conf
    echoProgress "Telegraf" "done" "\n"
}

configureMISP() {
    echoProgress "MISP" "configuring" "Configuring to fully benefit from the monitoring"
    echo "/var/www/MISP/app/Command/cake Admin setSetting MISP.log_paranoid 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting MISP.log_paranoid_skip_db 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting MISP.log_user_ips 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting MISP.log_user_ips_authkeys 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting MISP.log_auth 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting Plugin.ZeroMQ_enable 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting Plugin.ZeroMQ_event_notifications_enable 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting Plugin.ZeroMQ_object_notifications_enable 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting Plugin.ZeroMQ_object_reference_notifications_enable 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting Plugin.ZeroMQ_attribute_notifications_enable 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting Plugin.ZeroMQ_tag_notifications_enable 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting Plugin.ZeroMQ_sighting_notifications_enable 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting Plugin.ZeroMQ_user_notifications_enable 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting Plugin.ZeroMQ_organisation_notifications_enable 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting Plugin.ZeroMQ_audit_notifications_enable 1"
    echo "/var/www/MISP/app/Command/cake Admin setSetting Plugin.ZeroMQ_warninglist_notifications_enable 1"
    echoProgress "MISP" "done" "\n"
}

setupRebootSafe() {
    echo "
[Unit]
Description=MISP instance monitoring service
After=mysqld.service

[Service]
Type=simple
Restart=always
RestartSec=3
User=root
WorkingDirectory=$PWD
ExecStart=bash start_monitoring.sh
Environment=\"instancename=$INSTANCE_NAME\"

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/misp_monitoring.service

systemctl enable misp_monitoring
systemctl start misp_monitoring
}

waitForNextStep() {
    local message="$1"
    local return=$2
    echo -e " >> Next step: $BYellow$message$Color_Off"

    while true; do
        read -p "Do you want to continue (y) or do you want to skip (s)?: " y
        case $y in
            [Yy]* ) 
            eval $return="y"
                break;;
            [Ss]* ) 
            eval $return="s"
                break;;
            * )
                echo "Please enter y to continue.";;
        esac
    done
}

echoProgress() {
    local scope="$1"
    local step="$2"
    local message="$3"
    echo -e " >> $BGreen$scope$Color_Off :: $BCyan$step$Color_Off - $message"
}

getInstanceName() {
    read -p "Enter the name of the instance: " name
    echo "$name"
}


echo -e ""
echo -e "This utility will guide you on installing and configuring the monitoring tools."
echo -e ""
echo -e "Please make sure to have $BRed another shell accessible$Color_Off as you'll be required to paste some commands"
echo -e ""
echo -e ""

# Get instance name
INSTANCE_NAME=$(getInstanceName)

# ZeroMQ
waitForNextStep "ZeroMQ - Installation" userinput
if [ "$userinput" == "y" ]
    then installZMQ
fi
waitForNextStep "ZeroMQ - Configuration" userinput
if [ "$userinput" == "y" ]
    then configureZMQ
fi

# Apache2
waitForNextStep "Apache2 - LogFormat" userinput
if [ "$userinput" == "y" ]
    then changeLogFormat
fi

# MySQL
waitForNextStep "MySQL - Performance Schema" userinput
if [ "$userinput" == "y" ]
    then enableMySQLPerfMonitoring
fi
waitForNextStep "MySQL - Monitoring User" userinput
if [ "$userinput" == "y" ]
    then createMonitoringUser
fi


# Telgraf
## Generate telegraf configuration
waitForNextStep "Telegraf - Configuration" userinput
if [ "$userinput" == "y" ]
    then genTelegrafConfig
fi

## Install telegraf
waitForNextStep "Telegraf - Installation" userinput
if [ "$userinput" == "y" ]
    then installTelegraf
fi

# MISP
## Configure MISP
waitForNextStep "MISP - Configuration" userinput
if [ "$userinput" == "y" ]
    then configureMISP
fi

# Reboot safe
## Configure a service for both ZeroMQ and Telegraf
waitForNextStep "Reboot safe - Setup" userinput
if [ "$userinput" == "y" ]
    then setupRebootSafe
fi

echoProgress "Installation" "done" "\n"

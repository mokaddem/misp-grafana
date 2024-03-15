#!/bin/bash

set -e

Color_Off='\033[0m'       # Text Reset
BCyan='\033[1;36m'        # Bold Cyan
BGreen='\033[1;32m'       # Bold Green
BYellow='\033[1;33m'       # Bold Yellow

DBPASSWORD_MONITORING_USER="$(openssl rand -hex 32)"

installZMQ() {
    echoProgress "MISP ZeroMQ" "installing" "Installing MISP ZMQ python requirements"
    cd ../src/
    sudo apt-get update && sudo apt-get install python3-venv
    python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
    echoProgress "MISP ZeroMQ" "done" "\n"
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
    local name=$(getInstanceName)
    sed "s/{{\s*instance_name\s*}}/$name/g" telegraf.conf.template > telegraf.conf
    sed "s/{{\s*db_password_monitoring_user\s*}}/$DBPASSWORD_MONITORING_USER/g" telegraf.conf.template > telegraf.conf
    echoProgress "Telegraf" "done" "\n"
}

waitForNextStep() {
    local message="$1"
    echo -e " >> Next step: $BYellow$message$Color_Off"

    while true; do
        read -p "Do you want to continue? (y): " y
        case $y in
            [Yy]* ) 
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


echo ""
echo "This utility will guide you on installing and configuring the monitoring tools."
echo "Please make sure to have another shell accessible as you'll be required to paste some commands"
echo ""
waitForNextStep "ZeroMQ - Installation"

# ZeroMQ
installZMQ
waitForNextStep "Apache2 - LogFormat"

# Apache2
changeLogFormat
waitForNextStep "MySQL - Performance Schema"

# MySQL
enableMySQLPerfMonitoring
waitForNextStep "MySQL - Monitoring User"
createMonitoringUser
waitForNextStep "Telegraf - Configuration"

# Telgraf
## Generate telegraf configuration
genTelegrafConfig
waitForNextStep "Telegraf - Installation"

## Install telegraf
installTelegraf
echoProgress "Installation" "done" "\n"
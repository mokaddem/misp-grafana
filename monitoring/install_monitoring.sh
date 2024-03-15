#!/bin/bash

Color_Off='\033[0m'       # Text Reset
BCyan='\033[1;36m'        # Bold Cyan
BGreen='\033[1;32m'       # Bold Green

DBPASSWORD_MONITORING_USER="$(openssl rand -hex 32)"

# Telgraf
## Generate telegraf configuration
genTelegrafConfig
waitForNextStep

## Install telegraf
installTelegraf
waitForNextStep

# MySQL
enableMySQLPerfMonitoring
waitForNextStep
createMonitoringUser

# Apache2
changeLogFormat
waitForNextStep

# ZeroMQ
installZMQ


function installZMQ() {
    echoProgress "MISP ZeroMQ" "installing" "Installing MISP ZMQ python requirements"
    cd src/
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
}

function changeLogFormat() {
    echo "Make sure the `combined` log entry is set to the following:"
    echo ''
    echo 'Configuration file should be located here:'
    echo '/etc/apache2/apache2.conf'
    echo ''
    echo 'Make sure to restart apache2 afterward:'
    echo 'service apache2 restart'
}

function enableMySQLPerfMonitoring() {
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
}

function createMonitoringUser() {
    echoProgress "MySQL" "user" "Creating monitoring user"
    echo "Create a monitoring user for the performance schema:"
    echo ""
    echo "CREATE USER 'monitoring'@'localhost' IDENTIFIED BY '$DBPASSWORD_MONITORING_USER';"
    echo "GRANT SELECT ON *.* TO 'monitoring'@'localhost';"
    echo "FLUSH PRIVILEGES;"
}

function installTelegraf() {
    echoProgress "Telegraf" "installing" "Installing Telegraf"
    curl -s https://repos.influxdata.com/influxdata-archive_compat.key > influxdata-archive_compat.key
    echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdata-archive_compat.key' | sha256sum -c && cat influxdata-archive_compat.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
    echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | sudo tee /etc/apt/sources.list.d/influxdata.list
    sudo apt-get update && sudo apt-get install telegraf
}

function genTelegrafConfig() {
    local echoProgress "Telegraf" "configuring" "Configuring Telegraf config"
    local name=$(get_name)
    sed "s/{{\s*instance_name\s*}}/$name/g" telegraf.conf.template > telegraf.conf
    sed "s/{{\s*db_password_monitoring_user\s*}}/$DBPASSWORD_MONITORING_USER/g" telegraf.conf.template > telegraf.conf
}

function waitForNextStep() {
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

function echoProgress() {
    local scope="$1"
    local step="$2"
    local message="$3"
    echo -e " >> $BGreen$scope$Color_Off :: $BCyan$step$Color_Off - $message"
}

function getInstanceName() {
    read -p "Enter the name of the instance: " name
    echo "$name"
}
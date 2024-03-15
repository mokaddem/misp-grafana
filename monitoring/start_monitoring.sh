#!/bin/bash

screen -dmS "MISP monitoring InfluxDB"
sleep 0.1
screen -S "mispsync-server" -X screen -t "telegraf" bash -c "telegraf --config telegraf.conf"
screen -S "mispsync-server" -X screen -t "misp zeromq" bash -c "redis-server"
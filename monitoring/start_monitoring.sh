#!/bin/bash

name="$instancename"
if [ -z "$name" ]; then
    echo '$instancename is empty.'
    echo 'Make sure the variable is defined in the environment before running this script.'
    exit 1
fi

screenname="MISP monitoring InfluxDB"
gnuscreenpid=$(screen -ls | grep "$screenname" | cut -f2 | cut -d'.' -f1)

if $gnuscreenpid; then
    screen -X -S $gnuscreenpid quit
fi

screen -dmS "$screenname"
sleep 0.1
screen -S "mispsync-server" -X screen -t "telegraf" bash -c "telegraf --config telegraf.conf"
screen -S "mispsync-server" -X screen -t "misp zeromq" bash -c "python3 push_zmq_to_influxdb.py -id $name"
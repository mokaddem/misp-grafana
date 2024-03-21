#!/bin/bash
set -e

name="$instancename"
if [ -z "$name" ]; then
    echo '$instancename is empty.'
    echo 'Make sure the variable is defined in the environment before running this script.'
    exit 1
fi

screenname="MISP monitoring InfluxDB"
gnuscreenpid=$(screen -ls | grep "$screenname" | cut -f2 | cut -d'.' -f1)

if [ -n "$gnuscreenpid" ]; then
    screen -X -S "$gnuscreenpid" quit
    sleep 1
fi

screen -dmS "$screenname"
sleep 0.5
screen -S "$screenname" -X screen -t "telegraf" bash -c "telegraf --config telegraf.conf; read x"
screen -S "$screenname" -X screen -t "misp zeromq" bash -c "python3 push_zmq_to_influxdb.py -id $name; read x"
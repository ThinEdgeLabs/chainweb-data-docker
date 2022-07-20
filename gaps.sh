#!/bin/bash

if [[ ! -f /tmp/backfill ]]; then
    echo -e "Fill not complited...skipped..."  
fi

date_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
echo -e "Fill was started at $date_timestamp" >> /tmp/fill_history.log
/usr/local/bin/chainweb-data fill --service-host=$CHAINWEB_NODE_HOST --p2p-host=$CHAINWEB_NODE_HOST --service-port=$CHAINWEB_NODE_SERVICE_PORT --p2p-port=$CHAINWEB_NODE_P2P_PORT --dbuser=postgres --dbpass=postgres --dbname=postgres
date_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
echo -e "Fill was ended at $date_timestamp" >> /tmp/fill_history.log

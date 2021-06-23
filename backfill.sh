#!/bin/bash
# chainweb-data db sync script
check=$(curl -SsL -k -m 15 https://172.15.0.1:30004/chainweb/0.0/mainnet01/cut | jq .height)
if [[ "$check" == "" ]]; then
  until [ $check != "" ] ; do
    check=$(curl -SsL -k -m 15 https://172.15.0.1:30004/chainweb/0.0/mainnet01/cut | jq .height)
    echo -e "Awaiting for KDA node..."
    sleep 300
  done
fi

if [[ -f /tmp/backfill ]]; then
  echo -e "Backfill already done! skipped..."
  exit
fi

x=0
until [ $x == 1 ] ; do

  sleep 1000
  server_check=$(ps aux | grep idle | wc -l)
  
  if [[ "$server_check" == 2 ]]; then
  
    date_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "Backfill started at $date_timestamp"
    chainweb-data backfill --service-host=172.15.0.1 --p2p-host=172.15.0.1 --service-port=30005 --p2p-port=30004 --dbuser=postgres --dbpass=postgres --dbname=postgres +RTS -N 
    sleep 10
    progress_check=$(cat $(ls /var/log/supervisor | grep chainweb-backfill-stdout | awk {'print "/var/log/supervisor/"$1'} ) | tail -n1 | egrep -o -E '[0-9]+\.[0-9]+' | egrep -o -E '[0-9]+' | head -n1 )
    date_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "Backfill progress: $progress_check %, stopped at $date_timestamp"

     if [[ "$progress_check" -ge 70 ]]; then
       x=1
       echo -e "Backfill Complited!" >> /tmp/backfill
       sleep 10
       echo -e "Running gaps..."
       chainweb-data gaps --service-host=172.15.0.1 --p2p-host=172.15.0.1 --service-port=30005 --p2p-port=30004 --dbuser=postgres --dbpass=postgres --dbname=postgres
       echo -e "Added crone job for gaps..."
       (crontab -l -u "$USER" 2>/dev/null; echo "30 22 * * *  /bin/bash /gaps.sh > /tmp/gaps_output.log 2>&1") | crontab -
     fi
    
  fi
done

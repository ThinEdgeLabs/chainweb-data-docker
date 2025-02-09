#!/bin/bash
# chainweb-data db sync script

check=$(curl -SsL -k -m 15 "https://$CHAINWEB_NODE_HOST:$CHAINWEB_NODE_P2P_PORT/chainweb/0.0/$NETWORK_ID/cut" | jq .height)
if [[ "$check" == "" ]]; then
  until [[ "$check" != "" ]] ; do
    check=$(curl -SsL -k -m 15 "https://$CHAINWEB_NODE_HOST:$CHAINWEB_NODE_P2P_PORT/chainweb/0.0/$NETWORK_ID/cut" | jq .height)
    echo -e "Waiting for KDA node..."
    sleep 300
  done
fi

if [[ -f /tmp/backfill ]]; then
    echo -e "Running fill as gaps..."
    chainweb-data fill --service-host=$CHAINWEB_NODE_HOST --p2p-host=$CHAINWEB_NODE_HOST --service-port=$CHAINWEB_NODE_SERVICE_PORT --p2p-port=$CHAINWEB_NODE_P2P_PORT --dbuser=postgres --dbpass=postgres --dbname=postgres
    echo -e "Restarting chainweb-data..."
    kill -9 $(ps aux | grep 'chainweb-data server --port 8888' | awk '{ print $2 }' | head -n1)
    exit
fi

x=0
backfill_count=0

until [[ "$x" == 1 ]] ; do

  if [[ -f /usr/local/bin/chainweb-data ]]; then
   # give time postgres to run
    if [[ "$backfill_count" == 0 ]]; then
      sleep 600
    else
      sleep 10
    fi
  else
    # Allow time to build chainweb-data binary and for postgres to run
    sleep 1000
  fi

  server_check=$(ps aux | grep idle | wc -l)

  if [[ "$server_check" == 2 ]]; then

    date_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "Fill started at $date_timestamp"
    chainweb-data fill --service-host=$CHAINWEB_NODE_HOST --p2p-host=$CHAINWEB_NODE_HOST --service-port=$CHAINWEB_NODE_SERVICE_PORT --p2p-port=$CHAINWEB_NODE_P2P_PORT --dbuser=postgres --dbpass=postgres --dbname=postgres +RTS -N
    sleep 10
    progress_check=$(cat $(ls /var/log/supervisor | grep chainweb-backfill-stdout | awk {'print "/var/log/supervisor/"$1'} ) | egrep -o 'Progress:.*[0-9]+\.[0-9]+.*' | egrep -o '[0-9]+\.[0-9]+' | tail -n1)
    date_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    fill_complite=cat $(ls /var/log/supervisor | grep chainweb-backfill-stdout | awk {'print "/var/log/supervisor/"$1'} ) | egrep -o 'Filled in 0 missing blocks.' | tail -n1
    backfill_count=$((backfill_count+1))

     if [[ "$progress_check" != "" ]]; then
      echo -e "Fill progress: $progress_check %, stopped at $date_timestamp, counter: $backfill_count"
     else
      echo -e "Fill stopped at $date_timestamp, counter: $backfill_count"
     fi

     if [[ "$progress_check" -ge 99 || "$fill_complite" != "" ]]; then
       x=1
       echo -e "Fill Complited!" >> /tmp/backfill
       echo -e "Restarting chainweb-data..."
       kill -9 $(ps aux | grep 'chainweb-data server --port 8888' | awk '{ print $2 }' | head -n1)
       if [[ ! -f /tmp/crone ]]; then
         sleep 120
         echo -e "Added crone job for fill as gaps..."
         (crontab -l -u "$USER" 2>/dev/null; echo "30 22 * * *  /bin/bash /gaps.sh > /tmp/fill_output.log 2>&1") | crontab -
         echo -e "Cron job added!" >> /tmp/crone
       else
         echo -e "Cron job already exist..."
       fi
       exit
     fi


     if [[ "$backfill_count" == 2 ]] ; then
        x=1
        echo -e "Fill Complited!" >> /tmp/backfill
        echo -e "Restarting chainweb-data..."
        kill -9 $(ps aux | grep 'chainweb-data server --port 8888' | awk '{ print $2 }' | head -n1)
        if [[ ! -f /tmp/crone ]]; then
          sleep 120
          echo -e "Added crone job for fill as gaps..."
          (crontab -l -u "$USER" 2>/dev/null; echo "30 22 * * *  /bin/bash /gaps.sh > /tmp/fill_output.log 2>&1") | crontab -
          echo -e "Crone job added!" >> /tmp/crone
         else
          echo -e "Crone job already exist..."
        fi
        exit
      fi
  fi
done

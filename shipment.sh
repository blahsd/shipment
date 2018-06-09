NUM_TRIES=1
SLEEP_TIME=10
LOCAL_DESTINATION=~/"Downloads/Shipment"
LOCAL_RUNTIME=~/"dev/proj/shipment/"
LOCAL_WATCH=~/"Downloads/watch"
REMOTE_USER="blahsd"
REMOTE_HOST="star.seedhost.eu"
REMOTE_SOURCE="/home19/blahsd/downloads/completed"
REMOTE_WATCH="/home19/blahsd/downloads/watch"
verbose='true'
wetRun='true'
updated='false'
cleanup='false'
checkDeliveries='false'
onlycheck='false'
help='false'
while getopts 'vwcdho' flag; do
  case "${flag}" in
    w) wetRun='false' ;;          # Debug mode. Saves no modification to the file lists.
    v) verbose='true' ;;          #
    c) cleanup='true' ;;
    d) checkDeliveries='true' ;;  # Prints out local deliveries
    h) help='true' ;;
    o) onlycheck='true' ;;
  esac
done


function checkForShipment {
                                  #list all the remote files in listStocked
  ssh $REMOTE_USER@$REMOTE_HOST ls $REMOTE_SOURCE > $LOCAL_RUNTIME/listStocked

  IFS=$'\n'                       #make newlines the only separator

  for f in $(cat $LOCAL_RUNTIME/listStocked)   #for each file in listStocked, check if it's in listShipped
  do
    if grep -Fqx $f $LOCAL_RUNTIME/listShipped
    then
      :
    else
      if $verbose
      then
        echo "Payload found $f. Transferring..."
      fi
      printf -v sanitizedFilename  "%q\n" $f #sanitize input

      scp -r $REMOTE_USER@$REMOTE_HOST:$REMOTE_SOURCE/"$sanitizedFilename" $LOCAL_DESTINATION

      if $wetRun
      then
        echo "$f" >> $LOCAL_RUNTIME/listShipped
      fi

      updated='true'

    fi
  done
  if $updated
  then
    :
  else
    echo "No new payload found."
  fi
}

if $help
then
  echo """
  -w  wetRun      makes no modification to the files lists
  -c  cleanup     cleans up the local delivered payloads
  -d  deliveries  prints the local delivered payloads
  -h  help        prints this help page
  -o  onlycheck   doesn't make downloads
  """
  exit
fi

if $checkDeliveries || $onlycheck
then
  echo "Checking for locally delivered payloads..."
  tree $LOCAL_DESTINATION || ls $LOCAL_DESTINATION
fi

if $cleanup
then
  read -p "Clean up local Shipment/? This will delete everything. [y/N]" -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    echo "Cleaning up local Shipment/ ..."
    rm -rf $LOCAL_DESTINATION/*
    echo "Local Shipment/ cleaned up."
  fi
fi

if $onlycheck
then
  exit
fi

# /dev/null is a receptacle for unwanted output. It does nothing with it.
scp -r $LOCAL_WATCH/*.torrent $REMOTE_USER@$REMOTE_HOST:$REMOTE_WATCH > /dev/null 2>&1
echo "Local watch/ uploaded to remote."
rm $LOCAL_WATCH/*.torrent > /dev/null 2>&1
echo "Local watch/ cleaned up."


if $updated
then
  exit
fi

if $verbose
then
  echo "Querying remote server for payload. Checking..."
  fi
checkForShipment

#I know, this is dirty. I mean, dirtier than all the rest. But it works.
find $LOCAL_DESTINATION -name "*.flac" -exec ffmpeg -y -i {} -codec:a libmp3lame -q:a 0 -map_metadata 0 -id3v2_version 3 -write_id3v1 1 {}.mp3 \;
find $LOCAL_DESTINATION -name '*.mp3' -exec mv {} ~/Music/iTunes/iTunes\ Media/Automatically\ Add\ to\ iTunes.localized \;

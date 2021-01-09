#!/bin/bash
#
# WeMo Control Script
# 
# based on
# rich@netmagi.com
#
#
#

tmp=/tmp/$RANDOM
touch $tmp

CURL_MAX_WAIT=0.035
MAX_CHECK=35
EXPECTED=6
HOMENET=192.168.0
ports=(49154 49153 49152)
# tplink dhcp pool starts at 100
DHCP_POOL_BASE=100

# set -x

function portTest(){
  port=$1
  addr=$2
  # printf "testing %s:%d\n" $addr $port
  PORTTEST=$(curl -s -m ${CURL_MAX_WAIT} $addr:$port/setup.xml | grep -i "belkin")
  if [[ "$PORTTEST" != "" ]];
    then 
      printf "%s:%d\n" $addr $port >> $tmp
    fi
}


function scan(){
total=$(wc -l $tmp | awk '{print $1}')

sent=0
while [[ $total < $EXPECTED ]]
do
  :> $tmp
  for((oct=0; oct<$MAX_CHECK; oct++)); 
  do
    for port in ${ports[@]}
    do
      sent=$(($sent+1))
      total=$(wc -l $tmp | awk '{print $1}')
      printf "requests sent: %5d found: %3d expected: %d                   \r" $sent $total $EXPECTED
      IP=$(printf "%s.%s" $HOMENET $(($DHCP_POOL_BASE + $oct)))
      # IP="${HOMENET}.${oct}"
      portTest $port $IP &
    done
  done
  wait
done
printf "requests sent: %5d found: %3d expected: %d\n" $sent $total $EXPECTED
# echo -en "                                                                  \r"
# we have the ips and ports in the tmp file

}

function report(){
echo "reporting, please stand by...."
while read line
do
  name=$(getFriendlyName "$line")
  state=$(getState "$line")
  msg=$(printf "found [%-12s] at [%-18s] with state=[%s]\n" "${name}" "${line}" "${state}")
  echo "$msg"
done < $tmp

}

function toggle(){
ip_port=$1
state=""
try=0

while [[ "$state" == "" && $try < 5 ]]
do
  try=$(($try+1))
  state=$(getState "$ip_port")
done

if [[ "${state}" == "ON" ]]
then
  off "$ip_port"
elif [[ "${state}" == "OFF" ]]
then
  on "$ip_port"
else
  echo "failed to get current state"
fi
}

function flip(){
  input=$1
  scan

  while read line
  do
    name=$(getFriendlyName "$line")
    search=$(echo "$name" | grep $input)
    if [[ "$search" != "" ]]
    then
      echo "toggling $name at $line"
      toggle "$line"
      break
    fi
  done < $tmp

  if [[ "$search" == "" ]]
  then
    echo "no results for wemo named $input"
  fi
}

function getState(){
  ip_port=$1
  curl -0 -A '' -X POST -H 'Accept: ' -H 'Content-type: text/xml; charset="utf-8"' -H "SOAPACTION: \"urn:Belkin:service:basicevent:1#GetBinaryState\"" --data '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetBinaryState xmlns:u="urn:Belkin:service:basicevent:1"><BinaryState>1</BinaryState></u:GetBinaryState></s:Body></s:Envelope>' -s http://$ip_port/upnp/control/basicevent1 | 
grep "<BinaryState"  | cut -d">" -f2 | cut -d "<" -f1 | sed 's/0/OFF/g' | sed 's/1/ON/g' 
}

function on(){
  ip_port=$1
  curl -0 -A '' -X POST -H 'Accept: ' -H 'Content-type: text/xml; charset="utf-8"' -H "SOAPACTION: \"urn:Belkin:service:basicevent:1#SetBinaryState\"" --data '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:SetBinaryState xmlns:u="urn:Belkin:service:basicevent:1"><BinaryState>1</BinaryState></u:SetBinaryState></s:Body></s:Envelope>' -s http://$ip_port/upnp/control/basicevent1 |
grep "<BinaryState"  | cut -d">" -f2 | cut -d "<" -f1 > /dev/null
}

function off(){
  ip_port=$1
  curl -0 -A '' -X POST -H 'Accept: ' -H 'Content-type: text/xml; charset="utf-8"' -H "SOAPACTION: \"urn:Belkin:service:basicevent:1#SetBinaryState\"" --data '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:SetBinaryState xmlns:u="urn:Belkin:service:basicevent:1"><BinaryState>0</BinaryState></u:SetBinaryState></s:Body></s:Envelope>' -s http://$ip_port/upnp/control/basicevent1 |
grep "<BinaryState"  | cut -d">" -f2 | cut -d "<" -f1 > /dev/null
}

function getSignalStrength(){
  ip_port=$1
  curl -0 -A '' -X POST -H 'Accept: ' -H 'Content-type: text/xml; charset="utf-8"' -H "SOAPACTION: \"urn:Belkin:service:basicevent:1#GetSignalStrength\"" --data '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetSignalStrength xmlns:u="urn:Belkin:service:basicevent:1"><GetSignalStrength>0</GetSignalStrength></u:GetSignalStrength></s:Body></s:Envelope>' -s http://$ip_port/upnp/control/basicevent1 |
grep "<SignalStrength"  | cut -d">" -f2 | cut -d "<" -f1
}

function getFriendlyName(){
  ip_port=$1
  curl -0 -A '' -X POST -H 'Accept: ' -H 'Content-type: text/xml; charset="utf-8"' -H "SOAPACTION: \"urn:Belkin:service:basicevent:1#GetFriendlyName\"" --data '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetFriendlyName xmlns:u="urn:Belkin:service:basicevent:1"><GetFriendlyName>0</GetFriendlyName></u:GetFriendlyName></s:Body></s:Envelope>' -s http://$ip_port/upnp/control/basicevent1 | grep "<FriendlyName"  | cut -d">" -f2 | cut -d "<" -f1
}

COMMAND=$1
IP_PORT=$2

if [ "$1" = "" ]
	then
		echo "Usage: ./wemo_control toggle|scan|on|off|state|signal|name 'IP_ADDRESS:PORT'"
    echo "Usage: ./wemo_control flip friendly_name"
		exit
fi

case $1 in
        "on")
                on "$IP_PORT"
                ;;
        "off")
                off "$IP_PORT"
                ;;
        "state")
                getState "$IP_PORT"
                ;;
        "signal")
                getSignalStrength "$IP_PORT"
                ;;
        "name")
                getFriendlyName "$IP_PORT"
                ;;
        "toggle")
        		toggle "$IP_PORT"
        		;;
        "flip")
            # toggle by name
            name="$IP_PORT"
            flip "$name"
            ;;
        "scan")
        		scan
            report
        		;;
        *)
            echo $(printf "unknown command: %s" $1)
            exit 1
esac

rm $tmp

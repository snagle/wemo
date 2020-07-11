#!/bin/bash
#
# WeMo Control Script
# 
# based on
# rich@netmagi.com
#
#
#
CURL_MAX_WAIT=0.035
MAX_CHECK=35
EXPECTED=6

#set -x


function portTest(){
  port=$1
  PORTTEST=$(curl -s -m ${CURL_MAX_WAIT} $IP:$port/setup.xml | grep -i "belkin")
}

function setPort(){

if [[ "${PORT}" != "" ]]
then
  return
fi

if [[ $IP != "" ]]
then
  for check in 49154 49153 49152
  do
    portTest $check
    if [[ "$PORTTEST" != "" ]]
	  then
	    PORT=$check
      break
    else
      PORT=""
    fi
  done
fi
}

function scan(){
HOMENET=192.168.1

# i expect to find at least 5 devices within the first 15 ips
# because i set them to have static ips from 246-250
# if i dont find all of them keep trying until you do

found=0
total=0
echo "scanning..."
while [[ $total < $EXPECTED ]]
do
total=0
	#for((oct=256; oct>240; oct--)); 
	for((oct=0; oct<$MAX_CHECK; oct++)); 
	  do 
	  IP="${HOMENET}.${oct}"
	  echo -en "$IP                                \r"; 
	  PORT=""
	  setPort
	  if [[ "${PORT}" != "" ]]
	  then
		  found=1
		  total=$(($total+1))
		  name=$(getFriendlyName)
		  state=$(getState)
		  msg=$(printf "found [%-12s] at [%-12s] [%s] with state=[%s]\n" "${name}" "${IP}" "${PORT}" "${state}")
		  echo "$msg"
	  fi
	done
	if [[ $total < $EXPECTED ]]
	then
	  echo $(printf "found %d but expected to find %d. re-scanning" $total $EXPECTED)
	fi
done
if [[ $found == 0 ]]
then
  echo "no wemos found :("
else
  echo -en "               \r"
fi

}

function toggle(){
state=""
try=0

while [[ "$state" == "" && $try < 5 ]]
do
  try=$(($try+1))
  state=$(getState)
done

if [[ "${state}" == "ON" ]]
then
  off
elif [[ "${state}" == "OFF" ]]
then
  on
else
  echo "failed to get current state"
fi
}

function getState(){
setPort

			curl -0 -A '' -X POST -H 'Accept: ' -H 'Content-type: text/xml; charset="utf-8"' -H "SOAPACTION: \"urn:Belkin:service:basicevent:1#GetBinaryState\"" --data '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetBinaryState xmlns:u="urn:Belkin:service:basicevent:1"><BinaryState>1</BinaryState></u:GetBinaryState></s:Body></s:Envelope>' -s http://$IP:$PORT/upnp/control/basicevent1 | 
grep "<BinaryState"  | cut -d">" -f2 | cut -d "<" -f1 | sed 's/0/OFF/g' | sed 's/1/ON/g' 
}

function on(){
setPort

			curl -0 -A '' -X POST -H 'Accept: ' -H 'Content-type: text/xml; charset="utf-8"' -H "SOAPACTION: \"urn:Belkin:service:basicevent:1#SetBinaryState\"" --data '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:SetBinaryState xmlns:u="urn:Belkin:service:basicevent:1"><BinaryState>1</BinaryState></u:SetBinaryState></s:Body></s:Envelope>' -s http://$IP:$PORT/upnp/control/basicevent1 |
grep "<BinaryState"  | cut -d">" -f2 | cut -d "<" -f1 > /dev/null
}

function off(){
setPort

			curl -0 -A '' -X POST -H 'Accept: ' -H 'Content-type: text/xml; charset="utf-8"' -H "SOAPACTION: \"urn:Belkin:service:basicevent:1#SetBinaryState\"" --data '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:SetBinaryState xmlns:u="urn:Belkin:service:basicevent:1"><BinaryState>0</BinaryState></u:SetBinaryState></s:Body></s:Envelope>' -s http://$IP:$PORT/upnp/control/basicevent1 |
grep "<BinaryState"  | cut -d">" -f2 | cut -d "<" -f1 > /dev/null
}

function getSignalStrength(){
setPort

                        curl -0 -A '' -X POST -H 'Accept: ' -H 'Content-type: text/xml; charset="utf-8"' -H "SOAPACTION: \"urn:Belkin:service:basicevent:1#GetSignalStrength\"" --data '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetSignalStrength xmlns:u="urn:Belkin:service:basicevent:1"><GetSignalStrength>0</GetSignalStrength></u:GetSignalStrength></s:Body></s:Envelope>' -s http://$IP:$PORT/upnp/control/basicevent1 |
grep "<SignalStrength"  | cut -d">" -f2 | cut -d "<" -f1
}

function getFriendlyName(){
setPort

			curl -0 -A '' -X POST -H 'Accept: ' -H 'Content-type: text/xml; charset="utf-8"' -H "SOAPACTION: \"urn:Belkin:service:basicevent:1#GetFriendlyName\"" --data '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetFriendlyName xmlns:u="urn:Belkin:service:basicevent:1"><GetFriendlyName>0</GetFriendlyName></u:GetFriendlyName></s:Body></s:Envelope>' -s http://$IP:$PORT/upnp/control/basicevent1 | grep "<FriendlyName"  | cut -d">" -f2 | cut -d "<" -f1
}

COMMAND=$1
IP=$2

if [ "$1" = "" ]
	then
		echo "Usage: ./wemo_control toggle|state|signal|name|scan IP_ADDRESS"
		exit
fi

case $1 in
        "on")
                on
                ;;
        "off")
                off
                ;;
        "state")
                getState
                ;;
        "signal")
                getSignalStrength
                ;;
        "name")
                getFriendlyName
                ;;
        "toggle")
        		toggle
        		;;
        "scan")
        		scan
        		;;
        *)
            echo $(printf "unknown command: %s" $1)
            exit 1
esac



#!/bin/bash

usage() {
  echo "Usage: `basename $0` [-k API_KEY]"
  exit 1
}

[ $# -eq 0 ] && usage

# Get parameters by getopts command
while getopts k:? OPTION
do
  case $OPTION in
    k)
      API_KEY=$OPTARG
      ;;
    \?)
      usage
      ;;
  esac
done

# This script must be assign an API key
if [ -z "$API_KEY" ]; then
  echo "You must specify API_KEY with -k option"
  exit
fi

# Check target file status and do something
function check_status() {
  # Status codes
  # 1 - running
  # 2 - suspend
  # 3 - clear DNS
  # 11 - pending to create
  # 22 - pending to suspend
  # 33 - pending to clear DNS
  STATUS_CODE=$1
  JSON_FILE=$2
  PLAYBOOK_BASE=/etc/ansible/ansible-docker/playbooks
  SCRIPT_BASE=/etc/ansible/ansible-sh
  case "$STATUS_CODE" in
    1)
      ;;
    2)
      ;;
    3)
      ;;
    11)
      TARGET=`jq -r .target $JSON_FILE`
      DOMAIN=`jq -r .domain $JSON_FILE`
      $SCRIPT_BASE/create-site.sh $TARGET/$DOMAIN docker.yml --yes
      RESULT=$?
      if [ $RESULT -eq 0 ]; then
        jq -c '.status=1' $JSON_FILE > /tmp/$DOMAIN && mv /tmp/$DOMAIN $JSON_FILE
        curl -X POST https://neticrm.tw/neticrm/ansible/$DOMAIN/$STATUS_CODE?k=$API_KEY
      fi  
      ;;
    22)
      TARGET=`jq -r .target $JSON_FILE`
      DOMAIN=`jq -r .domain $JSON_FILE`
      $SCRIPT_BASE/suspend-site.sh $TARGET/$DOMAIN docker.yml --yes
      RESULT=$?
      if [ $RESULT -eq 0 ]; then
        jq -c '.status=2' $JSON_FILE > /tmp/$DOMAIN && mv /tmp/$DOMAIN $JSON_FILE
        curl -X POST https://neticrm.tw/neticrm/ansible/$DOMAIN/$STATUS_CODE?k=$API_KEY
      fi
      ;;
    33)
      TARGET=`jq -r .target $JSON_FILE`
      DOMAIN=`jq -r .domain $JSON_FILE`
      ansible-playbook $PLAYBOOK_BASE/dns.yml --extra-vars "@$JSON_FILE" --tags remove
      RESULT=$?
      if [ $RESULT -eq 0 ]; then
        jq -c '.status=3' $JSON_FILE > /tmp/$DOMAIN && mv /tmp/$DOMAIN $JSON_FILE
        curl -X POST https://neticrm.tw/neticrm/ansible/$DOMAIN/$STATUS_CODE?k=$API_KEY
      fi
      ;;
  esac
}

FILES="/etc/ansible/target/*/*"
for f in $FILES
do
  if [ "$(( $(date +"%s") - $(stat -c "%Y" $f) ))" -lt "600" ]; then
    STATUS=`jq -r .status $f`
    check_status $STATUS $f
  fi
done

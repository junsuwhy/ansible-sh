#!/bin/bash

# Usage info
show_help() {
cat << EOF
Help: 
  Remove site :
    $0 server1/test.com 
EOF
}

remove_site() {
  VARFILE=$1
  PLAYBOOK=$2
  echo "removing site ..."
  /usr/local/bin/ansible-playbook -v $PLAYBOOK/docker.yml --extra-vars "$VARFILE" --tags=remove
  # above yml will also include follow playbook.
  # ansible-playbook -v $PLAYBOOK/nginx.yml --extra-vars "$VARFILE" --tags=remove
  # ansible-playbook -v $PLAYBOOK/dns.yml --extra-vars "$VARFILE" --tags=remove
  
  echo "done"
}

BASE=/etc/ansible
if [ "$#" -lt 1 ]; then
  show_help
  exit 0
else
  IFS='/' read -r -a INPUT <<< "$1"
  LINODE="${INPUT[0]}"
  SITE="${INPUT[1]}"
  TARGET="$BASE/target/$LINODE"
  PLAYBOOK="$BASE/ansible-docker/playbooks"
  DOCKER=$2
  MAIL="mail.yml"
fi

PROMPT=1
for VAR in "$@"; do
  if [ "$VAR" = "--yes" ]; then
    PROMPT=0
  fi
done

# ====================
if [ -f "$TARGET/$SITE" ]; then
  EXTRAVARS="@$TARGET/$SITE"
  cat << EOF
Command will be execute:
  ansible-playbook docker.yml --extra-vars "$EXTRAVARS" --tags=remove
  ansible-playbook nginx.yml --extra-vars "$EXTRAVARS" --tags=remove
  ansible-playbook dns.yml --extra-vars "$EXTRAVARS" --tags=remove

EOF
  if [ $PROMPT -eq 0 ]; then
    remove_site $EXTRAVARS $PLAYBOOK
  else
    read -p "Are you really want to REMOVE this site? (y/n)" CHOICE 
    case "$CHOICE" in 
      y|Y ) 
        remove_site $EXTRAVARS $PLAYBOOK
        ;;
      n|N ) 
        exit 1
        ;;
      * ) echo "invalid";;
    esac
  fi
else
  echo -e "\e[1;31m[File or target not found]\e[0m"
  show_help
  exit 0
fi


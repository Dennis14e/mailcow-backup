#!/bin/bash

## SETTINGS
CUR_DIR=$(dirname "$(readlink -f "$0")")
CUR_DIR=${CUR_DIR%/}

MAILCOW_DIR="/home/mailcow-dockerized"
MAILCOW_DIR=${MAILCOW_DIR%/}

BACKUP_DIR="$CUR_DIR/vmail"
BACKUP_DIR=${BACKUP_DIR%/}


## DO NOT CHANGE

# WARNING
echo "WARNING! This script has not yet been tested!"
echo "The creator of this script is not responsible for data loss!"

while true
do
  read -p "Continue (y/n)? " choice
  case "$choice" in
    y|Y)
      break;
      ;;
    n|N)
      exit 0
      ;;
    *)
      ;;
  esac
done


# choose file
PS3="Type a number: "
BACKUP_FILEPATH=""
FILE_LIST=$(find "${BACKUP_DIR}/" -maxdepth 1 -type f -name "*.tar.gz")

select FILE_SELECT in $FILE_LIST "Quit"
do
  case $FILE_SELECT in
    *.tar.gz)
      BACKUP_FILEPATH="$FILE_SELECT"
      echo "You selected file \"${FILE_SELECT}\""
      break
      ;;
    "Quit")
      exit 0
      ;;
    *)
      echo "This is not a valid number"
      ;;
  esac
done


# resave filepath
BACKUP_FILENAME=$(basename "$BACKUP_FILEPATH")
BACKUP_FILEPATH="${BACKUP_DIR}/${BACKUP_FILENAME}"

if [ ! -f "$BACKUP_FILEPATH" ]
then
  >&2 echo "File does not exist"
  exit 1
fi


# docker instance id
DOCKER_INSTANCE_ID=$(cd "${MAILCOW_DIR}" && docker-compose ps -q dovecot-mailcow)

if [ $? -ne 0 ] || [ -z "${DOCKER_INSTANCE_ID}" ]
then
  >&2 echo "Can not get docker instance id"
  exit 1
fi


# docker volume name
DOCKER_VOLUME_NAME=$(docker inspect --format '{{ range .Mounts }}{{ if eq .Destination "/var/vmail" }}{{ .Name }}{{ end }}{{ end }}' "${DOCKER_INSTANCE_ID}")

if [ $? -ne 0 ] || [ -z "${DOCKER_VOLUME_NAME}" ]
then
  >&2 echo "Can not get docker volume name"
  exit 1
fi


# docker restore
docker run --rm -it -v "${DOCKER_VOLUME_NAME}:/vmail" -v "${BACKUP_DIR}:/backup" debian:jessie tar xvfz "/backup/${BACKUP_FILENAME}"

if [ $? -ne 0 ]
then
  >&2 echo "An error occurred"
  exit 1
fi


exit 0

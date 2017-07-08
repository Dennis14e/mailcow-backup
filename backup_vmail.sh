#!/bin/bash

# SETTINGS
CUR_DIR=$(dirname "$(readlink -f "$0")")
CUR_DIR=${CUR_DIR%/}

MAILCOW_DIR="/home/mailcow-dockerized"
MAILCOW_DIR=${MAILCOW_DIR%/}

BACKUP_DIR="$CUR_DIR/vmail"
BACKUP_DIR=${BACKUP_DIR%/}

BACKUP_AGE_MAX=7


# DO NOT CHANGE
MAILCOW_CFG="${MAILCOW_DIR}/mailcow.conf"


# check mailcow.conf
echo "Check, if \"${MAILCOW_CFG}\" exists..."
if [ ! -f "${MAILCOW_CFG}" ]
then
  >&2 echo "mailcow.conf not found."
  exit 1
fi


# source variables
#echo "Import mailcow variables..."
#source "${MAILCOW_CFG}"


# check variables
#echo "Check mailcow variables..."
#if [ -z ${DBUSER+x} ] || [ -z ${DBPASS+x} ] || [ -z ${DBNAME+x} ]
#then
#  >&2 echo "variables unset"
#  exit 1
#fi


# Date w/ timezone
BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILENAME="${BACKUP_DATE}_mailcow.tar.gz"
BACKUP_FILEPATH="${BACKUP_DIR}/${BACKUP_FILENAME}"


# check BACKUP_DIR
echo "Check, if \"${BACKUP_DIR}\" exists..."
if [ ! -d "${BACKUP_DIR}" ]
then
  mkdir -p "${BACKUP_DIR}"
  if [ $? -ne 0 ]
  then
    >&2 echo "Can not create \"{$BACKUP_DIR}\""
  fi
fi


# delete older backups
echo "Delete Backups older than ${BACKUP_AGE_MAX} days..."
find "${BACKUP_DIR}" -mindepth 1 -type f -mtime "+${BACKUP_AGE_MAX}" -print -delete


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


# docker backup
docker run --rm -i -v "${DOCKER_VOLUME_NAME}":/vmail -v "${BACKUP_DIR}":/backup debian:jessie tar cvfz "/backup/${BACKUP_FILENAME}" "/vmail"

if [ $? -ne 0 ]
then
  >&2 echo "An error occured"
  exit 1
fi


exit 0

#!/bin/bash

# SETTINGS
CUR_DIR=$(dirname "$(readlink -f "$0")")
CUR_DIR=${CUR_DIR%/}

MAILCOW_DIR="/home/mailcow-dockerized"
MAILCOW_DIR=${MAILCOW_DIR%/}

BACKUP_DIR="$CUR_DIR/mysql"
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
echo "Import mailcow variables..."
source "${MAILCOW_CFG}"


# check variables
echo "Check mailcow variables..."
if [ -z ${DBUSER+x} ] || [ -z ${DBPASS+x} ] || [ -z ${DBNAME+x} ]
then
  >&2 echo "variables unset"
  exit 1
fi


# date + filename
BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILENAME="${BACKUP_DATE}_mailcow.sql"
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


# docker backup
cd "${MAILCOW_DIR}" && docker-compose exec mysql-mailcow mysqldump -u "${DBUSER}" "-p${DBPASS}" "${DBNAME}" > "${BACKUP_FILEPATH}"

if [ $? -ne 0 ]
then
  >&2 echo "An error occurred"
  exit 1
fi


exit 0

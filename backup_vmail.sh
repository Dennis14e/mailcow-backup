#!/bin/bash

# requirements
if [ -z $(which docker-compose) ]; then >&2 echo "Could not find docker-compose."; exit 1; fi
if [ -z $(which docker) ]; then >&2 echo "Could not find docker."; exit 1; fi


# directory of this script
CUR_DIR=$(dirname "$(readlink -f "$0")")
CUR_DIR=${CUR_DIR%/}


# load configuration
if [ ! -f "${CUR_DIR}/backup.conf" ]
then
  >&2 echo "Configuration file \"${CUR_DIR}/backup.conf\" was not found."
  exit 1
fi

echo "Import backup variables."
source "${CUR_DIR}/backup.conf"


# required backup variables available?
if [ -z ${MAILCOW_DIR+x} ] || [ -z ${BACKUP_VMAIL_ENABLED+x} ] || [ -z ${BACKUP_VMAIL_MAX_AGE+x} ] || [ -z ${BACKUP_VMAIL_DIR+x} ]
then
  >&2 echo "Required variables do not exist (backup)."
  exit 1
fi


# Rename variables
BACKUP_ENABLED="${BACKUP_VMAIL_ENABLED}"
BACKUP_MAX_AGE="${BACKUP_VMAIL_MAX_AGE}"
BACKUP_DIR="${BACKUP_VMAIL_DIR}"

# remove trailing slash
MAILCOW_DIR=${MAILCOW_DIR%/}
BACKUP_DIR=${BACKUP_DIR%/}

# absolute/relative path?
if [[ "${BACKUP_DIR}" != /* ]]
then
  BACKUP_DIR="${CUR_DIR}/${BACKUP_DIR}"
fi


# backup enabled?
if [ "${BACKUP_ENABLED}" -ne 1 ]
then
  >&2 echo "Backup is disabled."
  exit 1
fi


# MAX_AGE a number?
if ! [[ "${BACKUP_MAX_AGE}" =~ ^[0-9]+$ ]]
then
  >&2 echo "BACKUP_VMAIL_MAX_AGE is not a number."
  exit 1
fi


# check mailcow installation
if [ ! -f "${MAILCOW_DIR}/mailcow.conf" ]
then
  >&2 echo "File \"${MAILCOW_DIR}/mailcow.conf\" was not found."
  exit 1
else
  echo "File \"${MAILCOW_DIR}/mailcow.conf\" was found."
fi


# date + filename
BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILENAME="${BACKUP_DATE}_mailcow.tar.gz"
BACKUP_FILEPATH="${BACKUP_DIR}/${BACKUP_FILENAME}"


# check BACKUP_DIR
if [ -d "${BACKUP_DIR}" ]
then
  echo "Backup directory \"${BACKUP_DIR}\" exists."
else
  echo "Backup directory \"${BACKUP_DIR}\" does not exists. Try to create it."

  mkdir -p "${BACKUP_DIR}"
  if [ $? -eq 0 ]
  then
    echo "Backup directory has been created."
  else
    >&2 echo "Could not create backup directory."
    exit 1
  fi
fi


# delete older backups
if [ "${BACKUP_MAX_AGE}" -eq 0 ]
then
  echo "Deletion of old backups is disabled. Skipping."
else
  echo "Delete backups older than ${BACKUP_MAX_AGE} days."
  find "${BACKUP_DIR}" -mindepth 1 -type f -mtime "+${BACKUP_MAX_AGE}" -print -delete
fi


# get docker instance id of dovecot-mailcow
DOCKER_INSTANCE_ID=$(cd "${MAILCOW_DIR}" && docker-compose ps -q dovecot-mailcow)

if [ $? -ne 0 ] || [ -z "${DOCKER_INSTANCE_ID}" ]
then
  >&2 echo "Could not get docker instance id."
  exit 1
fi


# get docker volume name
DOCKER_VOLUME_NAME=$(docker inspect --format '{{ range .Mounts }}{{ if eq .Destination "/var/vmail" }}{{ .Name }}{{ end }}{{ end }}' "${DOCKER_INSTANCE_ID}")

if [ $? -ne 0 ] || [ -z "${DOCKER_VOLUME_NAME}" ]
then
  >&2 echo "Could not get docker volume name."
  exit 1
fi


# docker backup
docker run --rm -i -v "${DOCKER_VOLUME_NAME}:/vmail" -v "${BACKUP_DIR}:/backup" debian:jessie tar cvfz "/backup/${BACKUP_FILENAME}" "/vmail"

if [ $? -eq 0 ]
then
  echo "Backup was successfully created: \"${BACKUP_FILEPATH}\"."
else
  >&2 echo "There was an error creating the backup."
  exit 1
fi


exit 0

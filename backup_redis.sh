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
if [ -z ${MAILCOW_DIR+x} ] || [ -z ${BACKUP_REDIS_ENABLED+x} ] || [ -z ${BACKUP_REDIS_MAX_AGE+x} ] || [ -z ${BACKUP_REDIS_DIR+x} ] || [ -z ${BACKUP_REDIS_SLEEPTIME+x} ] || [ -z ${BACKUP_REDIS_MAX_TRY+x} ]
then
  >&2 echo "Required variables do not exist (backup)."
  exit 1
fi


# Rename variables
BACKUP_ENABLED="${BACKUP_REDIS_ENABLED}"
BACKUP_MAX_AGE="${BACKUP_REDIS_MAX_AGE}"
BACKUP_DIR="${BACKUP_REDIS_DIR}"
BACKUP_SLEEPTIME="${BACKUP_REDIS_SLEEPTIME}"
BACKUP_MAX_TRY="${BACKUP_REDIS_MAX_TRY}"

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
  >&2 echo "BACKUP_REDIS_MAX_AGE is not a number."
  exit 1
fi

# SLEEPTIME a number?
if ! [[ "${BACKUP_SLEEPTIME}" =~ ^[0-9]+$ ]]
then
  >&2 echo "BACKUP_REDIS_SLEEPTIME is not a number."
  exit 1
fi

# MAX_TRY a number?
if ! [[ "${BACKUP_MAX_TRY}" =~ ^[0-9]+$ ]]
then
  >&2 echo "BACKUP_REDIS_MAX_TRY is not a number."
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
BACKUP_FILENAME="${BACKUP_DATE}_dump.rdb"
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


# get docker instance id of redis-mailcow
DOCKER_INSTANCE_ID=$(cd "${MAILCOW_DIR}" && docker-compose ps -q redis-mailcow)

if [ $? -ne 0 ] || [ -z "${DOCKER_INSTANCE_ID}" ]
then
  >&2 echo "Could not get docker instance id."
  exit 1
fi


# get docker volume name
DOCKER_VOLUME_NAME=$(docker inspect --format '{{ range .Mounts }}{{ if eq .Destination "/data" }}{{ .Name }}{{ end }}{{ end }}' "${DOCKER_INSTANCE_ID}")

if [ $? -ne 0 ] || [ -z "${DOCKER_VOLUME_NAME}" ]
then
  >&2 echo "Could not get docker volume name."
  exit 1
fi


# start redis-cli bgsave
cd "${MAILCOW_DIR}" && docker-compose exec redis-mailcow redis-cli bgsave


# check if redis-cli bgsave is finished
while [ ${BACKUP_MAX_TRY} -gt 0 ]
do
  BACKUP_MAX_TRY=$((BACKUP_MAX_TRY - 1))
  sleep ${BACKUP_SLEEPTIME}

  REDIS_BGSAVE_IN_PROGRESS=$(cd "${MAILCOW_DIR}" && docker-compose exec redis-mailcow redis-cli info Persistence | awk '/rdb_bgsave_in_progress:0/{print "no"}')
  REDIS_BGSAVE_LAST_STATUS=$(cd "${MAILCOW_DIR}" && docker-compose exec redis-mailcow redis-cli info Persistence | awk '/rdb_last_bgsave_status:ok/{print "ok"}')

  if [ "${REDIS_BGSAVE_IN_PROGRESS}" = "no" ] && [ "${REDIS_BGSAVE_LAST_STATUS}" = "ok" ]
  then
    echo "redis-cli bgsave is finished."
    break
  else
    if [ ${BACKUP_MAX_TRY} -gt 0 ]
    then
      echo "redis-cli bgsave is not yet finished. Try again in ${BACKUP_SLEEPTIME} seconds."
    else
      >&2 echo "redis-cli bgsave was not finished in the given time."
      exit 1
    fi
  fi
done


# docker backup
docker run --rm -i -v "${DOCKER_VOLUME_NAME}:/data" -v "${BACKUP_DIR}:/backup" debian:stretch-slim cp "/data/dump.rdb" "/backup/${BACKUP_FILENAME}"

if [ $? -eq 0 ]
then
  echo "Backup was successfully created: \"${BACKUP_FILEPATH}\"."
else
  >&2 echo "There was an error creating the backup."
  exit 1
fi


exit 0

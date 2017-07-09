#!/bin/bash

# Warning
echo "###################################################"
echo "#  WARNING! This script has not yet been tested!  #"
echo "# No liability is assumed for damage of any kind! #"
echo "###################################################"
echo

while true
do
  read -p "Continue (y/n)? " choice
  case "${choice}" in
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
if [ -z ${MAILCOW_DIR+x} ] || [ -z ${BACKUP_MYSQL_DIR+x} ]
then
  >&2 echo "Required variables do not exist (backup)."
  exit 1
fi


# Rename variables
BACKUP_DIR="${BACKUP_MYSQL_DIR}"

# remove trailing slash
MAILCOW_DIR=${MAILCOW_DIR%/}
BACKUP_DIR=${BACKUP_DIR%/}

# absolute/relative path?
if [[ "${BACKUP_DIR}" != /* ]]
then
  BACKUP_DIR="${CUR_DIR}/${BACKUP_DIR}"
fi


# check mailcow installation
if [ ! -f "${MAILCOW_DIR}/mailcow.conf" ]
then
  >&2 echo "File \"${MAILCOW_DIR}/mailcow.conf\" was not found."
  exit 1
else
  echo "File \"${MAILCOW_DIR}/mailcow.conf\" was found."
fi


# source variables
echo "Import mailcow variables."
source "${MAILCOW_DIR}/mailcow.conf"


# required mailcow variables available?
if [ -z ${DBUSER+x} ] || [ -z ${DBPASS+x} ] || [ -z ${DBNAME+x} ]
then
  >&2 echo "Required variables do not exist (mailcow)."
  exit 1
fi


# choose backup file
BACKUP_FILEPATH=""
FILE_LIST=$(find "${BACKUP_DIR}/" -maxdepth 1 -type f -name "*.sql")
PS3="Type a number: "

echo
echo "Select a backup file:"
select FILE_SELECT in $FILE_LIST "Quit"
do
  case $FILE_SELECT in
    *.sql)
      BACKUP_FILEPATH="${FILE_SELECT}"
      echo "You selected file \"${FILE_SELECT}\"."
      break
      ;;
    "Quit")
      exit 0
      ;;
    *)
      echo "This is not a valid number."
      ;;
  esac
done


# resave filepath
BACKUP_FILENAME=$(basename "${BACKUP_FILEPATH}")
BACKUP_FILEPATH="${BACKUP_DIR}/${BACKUP_FILENAME}"


# check BACKUP_FILEPATH
if [ ! -f "${BACKUP_FILEPATH}" ]
then
  >&2 echo "Backup file does not exist."
  exit 1
fi


# get docker instance id of mysql-mailcow
DOCKER_INSTANCE_ID=$(cd "${MAILCOW_DIR}" && docker-compose ps -q mysql-mailcow)

if [ $? -ne 0 ] || [ -z "${DOCKER_INSTANCE_ID}" ]
then
  >&2 echo "Could not get docker instance id."
  exit 1
fi


# docker restore
docker exec -i "${DOCKER_INSTANCE_ID}" mysql "-u${DBUSER}" "-p${DBPASS}" "${DBNAME}" < "${BACKUP_FILEPATH}"

if [ $? -eq 0 ]
then
  echo "Backup was successfully restored."
else
  >&2 echo "There was an error restoring the backup."
  exit 1
fi


exit 0

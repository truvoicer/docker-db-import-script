#!/bin/bash

ROOT_PATH="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";


declare -A env_data

env_data=(
  [HELP]=${HELP:-false}
  [CREATE_DB]=${CREATE_DB:-false}
  [DB_NAME]=${DB_NAME:-false}
  [DB_DUMP_PATH]=${DB_DUMP_PATH:-"/Users/michaeltoriola/Downloads/staging_sstcore.sql"}
  [DOCKER_DB_DIR]=${DOCKER_DB_DIR:-"/Users/michaeltoriola/Projects/docker/sst/database/mysql"}
  [DB_HOST]=${DB_HOST:-staging_sst_db}
  [DB_USER]=${DB_USER:-root}
  [DB_ROOT_PASSWORD]=${DB_ROOT_PASSWORD:-secret}
  [DB_PASSWORD]=${DB_PASSWORD:-password}
  [DB_CONTAINER]=${DB_CONTAINER:-staging_sst_db}
)


function executeDbImport {
  if [[ "${env_data[DB_DUMP_PATH]}" == false ]]; then
    echo "--DB_DUMP_PATH not found"
    echo "Skipping..."
    exit
  elif [[ ! -f "${env_data[DB_DUMP_PATH]}" ]]; then
    echo "--DB_DUMP_PATH file not found"
    echo "Skipping..."
    exit
  fi
  dbName="$1"
  requested_db_dir="${env_data[DOCKER_DB_DIR]}"
  filename=$(basename -- "${env_data[DB_DUMP_PATH]}")

  if [[ ! -d "$requested_db_dir" ]]; then
    echo "Requested DB dir not found"
    echo "Requested DB dir: $requested_db_dir"
    echo "Skipping..."
    exit
  fi
  if [[ -z "$filename" ]]; then
    echo "Error extracting filename from path"
    echo "Filename: $filename"
    echo "Skipping..."
    exit
  fi

  dockerSql="$MYSQL_LIB_DIR/$filename"
  dockerSqlLocalPath="$requested_db_dir/$filename"
  mysqlContainerSqlLocalPath="/var/lib/mysql/$filename"
  cp "${env_data[DB_DUMP_PATH]}" "$dockerSqlLocalPath"

  if [[ ! -f "$dockerSqlLocalPath" ]]; then
    echo "SQL copy failed: $dockerSqlLocalPath"
    echo "Skipping..."
    exit
  fi

  docker exec "${env_data[DB_CONTAINER]}" mysql -u "${env_data[DB_USER]}" -p"${env_data[DB_ROOT_PASSWORD]}" --database "$dbName" -e "use $dbName; source $mysqlContainerSqlLocalPath;"
  rm $dockerSqlLocalPath
  if [[ -f "$dockerSqlLocalPath" ]]; then
    echo "SQL deletion failed: $dockerSqlLocalPath"
    exit
  fi
}

function executeDbCreate {
  dbName="$1"
  docker exec "${env_data[DB_CONTAINER]}" mysql -u "${env_data[DB_USER]}" -p"${env_data[DB_ROOT_PASSWORD]}" -e "create database $dbName"
}

function createDatabase {
  dbName="$1"
  requested_db_dir="${env_data[DOCKER_DB_DIR]}"
  echo "$dbName"
  echo "$requested_db_dir"
  echo "Creating database: $dbName"
  if [ ! -d "$requested_db_dir/" ]; then
    echo "DB host ${env_data[DB_HOST]} does not exist in databases directory"
    return
  fi
  
  if [ ! -d "$requested_db_dir/$dbName" ]; then
    executeDbCreate "$dbName"
    return
  fi
  echo "DB: $dbName already exists in DB ${site_data[DB_HOST]}"
  echo "Do you want to create another database? [y|n]"
  read createNewDbQuestion

  if [ "$createNewDbQuestion" == "y" ]; then
    echo "Enter a new DB name:"
    read dbName
    executeDbCreate "$dbName"
  fi
}


function array_key_exists {
  #Checks if arguments are entered the correct way
  if [ "$2" != in ]; then
    echo "Incorrect usage."
    echo "Correct usage: exists {key} in {array}"
    return
  fi
  #if array[key] ($3) is set, return set
  #if array[key] ($3) is not set, return nothing
  eval '[ ${'"$3"'[$1]+set} ]'
}

while [ $# -gt 0 ]; do
  param="${1/--/}"
  if [[ $1 == *"--"* ]]; then
    declare $param="$2"

      env_data[$param]="$2"
    # if ! array_key_exists $param in env_data; then
    #   env_data[$param]="$2"
    # fi
  fi
  shift
done


if [ "${env_data[HELP]}" == true ]; then
    echo "Options:"
  echo "${!env_data[@]}"
  exit
fi

if [ "${env_data[DB_NAME]}" == false ]; then
  echo "Error, --DB_NAME not set."
  exit
fi

if [ "${env_data[CREATE_DB]}" == true ]; then
    createDatabase "${env_data[DB_NAME]}"
    echo "Db created..."
fi

executeDbImport "${env_data[DB_NAME]}"

echo "Finished..."
exit
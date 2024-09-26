#!/bin/bash

#./script-upgrade-playground/upgrade.sh --stm_path stream \
# --hrz_path horizon --hrz_source_version 2.5.0 --hrz_target_version 2.5.7 --stm_source_version 1.2.1 --stm_target_version 2.0.0 --playground_path playground \

STREAM_TO_UPDATE=false
HORIZON_TO_UPDATE=false

STREAM_PATH="" #if set, will upgrade Stream
HORIZON_PATH="" #if set, will upgrade Horizon
STREAM_SOURCE_VERSION="" #Mandatory if Stream path specified
HORIZON_SOURCE_VERSION="" #Mandatory if Horizon path specified
STREAM_UPGRADE_VERSION="" #Mandatory if Stream path specified
HORIZON_UPGRADE_VERSION="" #Mandatory if Horizon path specified

PLAYGROUND_PATH="" #Mandatory if Horizon path specified

MONGO_VERSION="7" #Defines the version for the Mongo image
CONTAINER_NAME="" #Will be generated automatically by Docker

usage() (
    printf "Usage: %s [OPTIONS]\n" "$0"
    printf "Options:\n"
    printf "  -h, --help                 Show this help message and exit\n"
    printf "  --playground_path <path>   Set the path to the Playground repository\n"
    printf "  --stm_path <path>          Set the path to the Stream source code directory\n"
    printf "  --stm_source_version <ver> Set the stream source version\n"
    printf "  --stm_target_version <ver> Set the stream target version\n"
    printf "  --hrz_path <path>          Set the path to the Horizon source code directory\n"
    printf "  --hrz_source_version <ver> Set the horizon source version\n"
    printf "  --hrz_target_version <ver> Set the horizon target version\n"
    printf "  -m, --mongo_version <vers> Set the version for the Docker Mongo image"
)

while [ $# -gt 0 ]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    --stm_path)
      STREAM_PATH=$(realpath "$2")
      shift
      shift
      ;;
    --hrz_path)
      HORIZON_PATH=$(realpath "$2")
      shift
      shift
      ;;
    --playground_path)
      PLAYGROUND_PATH=$(realpath "$2")
      shift
      shift
      ;;
    -m|--mongo_version)
      MONGO_VERSION="$2"
      shift
      shift
      ;;
    --stm_source_version)
      STREAM_SOURCE_VERSION="$2"
      shift
      shift
      ;;
    --hrz_source_version)
      HORIZON_SOURCE_VERSION="$2"
      shift
      shift
      ;;
    --stm_target_version)
      STREAM_UPGRADE_VERSION="$2"
      shift
      shift
      ;;
    --hrz_target_version)
      HORIZON_UPGRADE_VERSION="$2"
      shift
      shift
      ;;
    --*|-*)
      echo "Unknown option $1"
      usage
      exit 1
      ;;
  esac
done

# Runs a_Mongo container
# $1: $MONGO_VERSION version for the mongo image
# $2: $DOCKER_MOUNTS different mounting points to the container
run_mongo() {
  CONTAINER_NAME="$( docker run -d ${2} mongo:${1} )"
}

DOCKER_MOUNTS=""

if [ -z "$STREAM_PATH" ] && [ -z "$HORIZON_PATH" ]; then
  echo "Please specify at least the path to Stream's source code or Horizon's source code along with the source version and the target version for the upgrade."
fi

if [ -n "$STREAM_PATH" ]; then
  # Verifies the presence of the versions for Stream's update
  if [ -z "$STREAM_UPGRADE_VERSION" ] || [ -z "$STREAM_SOURCE_VERSION" ]; then
    echo "Please specify the Stream source version and the target version for the upgrade."
    exit 1
  fi
  # Verifies the presence of the last migration script
  if [ ! -e "$STREAM_PATH/src/migration/$STREAM_UPGRADE_VERSION.js" ]
    then
      echo "$STREAM_PATH/src/migration/$STREAM_UPGRADE_VERSION.js"
      cat "$STREAM_PATH/src/migration/$STREAM_UPGRADE_VERSION.js"
      echo "Error with the specified version or Stream's source code path."
      exit 1
    else
      STREAM_TO_UPDATE=true
      DOCKER_MOUNTS="$DOCKER_MOUNTS -v $STREAM_PATH/src:/stream"
  fi
fi

if [ -n "$HORIZON_PATH" ]; then
  # Verifies the presence of the versions for Horizon's update
  if [ -z "$HORIZON_UPGRADE_VERSION" ] || [ -z "$HORIZON_SOURCE_VERSION" ]; then
    echo "Please specify the Horizon source version and the target version for the upgrade."
    exit 1
  fi
  # Verifies the presence of the last migration script
  if [ ! -e "$HORIZON_PATH/src/migration/$HORIZON_UPGRADE_VERSION.js" ]
  then
    echo "Error with the specified version or Horizon's source code path."
    exit 1
  else
    HORIZON_TO_UPDATE=true
    DOCKER_MOUNTS="$DOCKER_MOUNTS -v $HORIZON_PATH/src:/horizon"
  fi
fi

#Checks the playground directory
if [ -z "$PLAYGROUND_PATH" ]; then
  echo "Missing path to the playground directory."
  exit 1
fi
DOCKER_COMPOSE_FILE="docker-compose.yml"
if [ -z "$DOCKER_COMPOSE_FILE" ]
then
  echo "Error with the path to the Playground directory."
  exit 1
else
  DOCKER_MOUNTS="$DOCKER_MOUNTS -v $PLAYGROUND_PATH:/playground"
fi

# Run the Docker command
run_mongo "$MONGO_VERSION" "$DOCKER_MOUNTS"

if [ "$STREAM_TO_UPDATE" ] ; then
  docker exec "$CONTAINER_NAME" mongorestore --db stream /playground/database/dump/stream
  docker exec "$CONTAINER_NAME" /stream/sbin/stream-upgrade -m mongodb://localhost:27017/stream -t "$STREAM_UPGRADE_VERSION" -s "$STREAM_SOURCE_VERSION" -p /stream/migration -y
  docker exec "$CONTAINER_NAME" rm -rf /playground/database/dump/stream
  docker exec "$CONTAINER_NAME" mongodump --out=/playground/database/dump mongodb://localhost:27017/stream
  docker exec "$CONTAINER_NAME" sed -i "s/stream:$STREAM_SOURCE_VERSION/stream:$STREAM_UPGRADE_VERSION/" "/playground/$DOCKER_COMPOSE_FILE"
fi

if [ "$HORIZON_TO_UPDATE" ] ; then
  docker exec "$CONTAINER_NAME" mongorestore --db horizon /playground/database/dump/horizon
  docker exec "$CONTAINER_NAME" /horizon/sbin/horizon-upgrade -m mongodb://localhost:27017/horizon -t "$HORIZON_UPGRADE_VERSION" -s "$HORIZON_SOURCE_VERSION" -p /horizon/migration -y
  docker exec "$CONTAINER_NAME" rm -rf /playground/database/dump/horizon
  docker exec "$CONTAINER_NAME" mongodump --out=/playground/database/dump mongodb://localhost:27017/horizon
  docker exec "$CONTAINER_NAME" sed -i "s/horizon:$HORIZON_SOURCE_VERSION/horizon:$HORIZON_UPGRADE_VERSION/" "/playground/$DOCKER_COMPOSE_FILE"
fi

docker stop "$CONTAINER_NAME" && docker rm "$CONTAINER_NAME"

#!/bin/bash

#------------------------------------------------------------#
# Init
#------------------------------------------------------------#
set -e
trap fail ERR

SCRIPT_NAME=`basename ${0}`

start() {
  echo ""
  echo -e "\033[0;33mScript [${SCRIPT_NAME}] started\033[0m" # print it in yellow
  echo ""
}

success() {
  echo ""
  echo -e "\033[0;32mScript [${SCRIPT_NAME}] completed\033[0m" # print it in green
  echo ""
  exit 0
}

fail() {
  echo ""
  echo -e "\033[0;31mScript [${SCRIPT_NAME}] failed\033[0m" # print it in red
  echo ""
  exit 1
}

check_option_value() {
  if [ -z "$2" -o "${2:0:2}" == "--" ]; then
    echo ""
    echo "Option $1 was passed an invalid value: $2. Perhaps you passed in an empty env var?"
    fail
  fi
}

usage() {
  echo "Usage: $(basename "$0") [-h] [--config CONFIG_FILE_PATH]"
  echo ""
  echo "Options:
  -h, --help                   Display this help message.
  --config CONFIG_FILE_PATH    Set a config file path explicitly other than default."
}

CONFIG_FILE_PATH=""
while :; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  --config)
    check_option_value "$1" "$2"
    CONFIG_FILE_PATH="$2"
    shift 2
    ;;
  *)
    [ -z "$1" ] && break
    echo ""
    echo "Invalid option: [$1]."
    fail
    ;;
  esac
done

if [ -z "${CONFIG_FILE_PATH}" ]; then
  CONFIG_FILE_PATH="$(dirname $0)/../envs/default.conf"
fi

if [ ! -e "${CONFIG_FILE_PATH}" ]; then
  echo ""
  echo "Config file does not exist on [${CONFIG_FILE_PATH}]."
  fail
fi

start
#------------------------------------------------------------#


#------------------------------------------------------------#
# Load Variables
#------------------------------------------------------------#
source ${CONFIG_FILE_PATH}
echo "-------------------------------------"
echo "APP_ID=${APP_ID}"
echo "ENV_ID=${ENV_ID}"
echo "AWS_PROFILE=${AWS_PROFILE}"
echo "AWS_REGION=${AWS_REGION}"
echo "-------------------------------------"
#------------------------------------------------------------#


#------------------------------------------------------------#
# Get Access URL
#------------------------------------------------------------#
URL=http://$(aws cloudformation list-exports --region ${AWS_REGION} --query 'Exports[?Name==`'${APP_ID}-${ENV_ID}-alb-dns-name'`].Value' --output text)
echo ""
echo -e "\033[0;33m------------------------------------------------------------------------------------\033[0m"
echo -e "\033[0;32mURL  ${URL}\033[0m" # print it in green
echo -e "\033[0;33m------------------------------------------------------------------------------------\033[0m"
#------------------------------------------------------------#


success

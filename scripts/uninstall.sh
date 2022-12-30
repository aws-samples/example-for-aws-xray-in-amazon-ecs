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
# Load / Define Variables
#------------------------------------------------------------#
source ${CONFIG_FILE_PATH}
echo "-------------------------------------"
echo "APP_ID=${APP_ID}"
echo "ENV_ID=${ENV_ID}"
echo "AWS_PROFILE=${AWS_PROFILE}"
echo "AWS_REGION=${AWS_REGION}"
echo "-------------------------------------"

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
SUB_APP_IDS=(
  "frontend"
  "bff"
  "backend1"
  "backend2"
)
#------------------------------------------------------------#


#------------------------------------------------------------#
# Delete Service Individual Stack
#------------------------------------------------------------#
for SUB_APP_ID in "${SUB_APP_IDS[@]}" ; do
  CFN_TEMPLATE_TYPE="svc-${SUB_APP_ID}"
  printf "\nDeleting ${APP_ID}-${ENV_ID}-${CFN_TEMPLATE_TYPE}-stack.. \n"
  sam delete \
    --stack-name ${APP_ID}-${ENV_ID}-${CFN_TEMPLATE_TYPE}-stack \
    --region ${AWS_REGION} \
    --no-prompts
done
#------------------------------------------------------------#


#------------------------------------------------------------#
# Delete Container Images and Service Common Stack
#------------------------------------------------------------#
for SUB_APP_ID in "${SUB_APP_IDS[@]}" ; do
  # Delete container images
  ECR_REPOSITORY_NAME=${APP_ID}-${ENV_ID}-${SUB_APP_ID}
  if [ $(aws ecr describe-repositories --query 'length(repositories[?repositoryName==`'${ECR_REPOSITORY_NAME}'`])') -ne 0 ]; then
    printf "\nDeleting image: ${ECR_REPOSITORY_NAME}.. \n"
    aws ecr delete-repository --repository-name "${ECR_REPOSITORY_NAME}" --force
  fi
done

CFN_TEMPLATE_TYPE="svc-base"
printf "\nDeleting ${APP_ID}-${ENV_ID}-${CFN_TEMPLATE_TYPE}-stack.. \n"
sam delete \
  --stack-name ${APP_ID}-${ENV_ID}-${CFN_TEMPLATE_TYPE}-stack \
  --region ${AWS_REGION} \
  --no-prompts
#------------------------------------------------------------#


#------------------------------------------------------------#
# Delete VPC Stack
#------------------------------------------------------------#
CFN_TEMPLATE_TYPE="vpc"
printf "\nDeleting ${APP_ID}-${ENV_ID}-${CFN_TEMPLATE_TYPE}-stack.. \n"
sam delete \
  --stack-name ${APP_ID}-${ENV_ID}-${CFN_TEMPLATE_TYPE}-stack \
  --region ${AWS_REGION} \
  --no-prompts
#------------------------------------------------------------#


success

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
echo "VPC_CIDR=${VPC_CIDR}"
echo "PUBLIC_SUBNET_1_CIDR=${PUBLIC_SUBNET_1_CIDR}"
echo "PUBLIC_SUBNET_2_CIDR=${PUBLIC_SUBNET_2_CIDR}"
echo "PRIVATE_SUBNET_1_CIDR=${PRIVATE_SUBNET_1_CIDR}"
echo "PRIVATE_SUBNET_2_CIDR=${PRIVATE_SUBNET_2_CIDR}"
echo "-------------------------------------"

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
CFN_TEMPLATES_DIR=$(dirname $0)/../templates
APP_DIR=$(dirname $0)/../app
SUB_APP_IDS=(
  "backend2"
  "backend1"
  "bff"
  "frontend"
)
declare -A IMAGE_TAGS
#------------------------------------------------------------#


#------------------------------------------------------------#
# Deploy VPC Stack
#------------------------------------------------------------#
sam deploy \
  --template-file templates/0-vpc.yml \
  --stack-name ${APP_ID}-${ENV_ID}-vpc-stack \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ${AWS_REGION} \
  --parameter-overrides \
    AppId=${APP_ID} \
    EnvId=${ENV_ID} \
    EnvName=${ENV_ID^} \
    VpcCIDR=${VPC_CIDR} \
    PublicSubnet1CIDR=${PUBLIC_SUBNET_1_CIDR} \
    PublicSubnet2CIDR=${PUBLIC_SUBNET_2_CIDR} \
    PrivateSubnet1CIDR=${PRIVATE_SUBNET_1_CIDR} \
    PrivateSubnet2CIDR=${PRIVATE_SUBNET_2_CIDR} \
  --no-fail-on-empty-changeset
#------------------------------------------------------------#


#------------------------------------------------------------#
# Deploy Service Common Stack
#------------------------------------------------------------#
sam deploy \
  --template-file templates/1-svc-base.yml \
  --stack-name ${APP_ID}-${ENV_ID}-svc-base-stack \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ${AWS_REGION} \
  --parameter-overrides \
    AppId=${APP_ID} \
    EnvId=${ENV_ID} \
  --no-fail-on-empty-changeset
#------------------------------------------------------------#


#------------------------------------------------------------#
# Build / Push Container Images
#------------------------------------------------------------#
for SUB_APP_ID in "${SUB_APP_IDS[@]}" ; do
  # Build Container Images
  ECR_DOMAIN=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
  ECR_REPOSITORY_NAME=${APP_ID}-${ENV_ID}-${SUB_APP_ID}
  printf "\nBuilding image: [${ECR_DOMAIN}:${ECR_REPOSITORY_NAME}]..\n"
  docker build -t ${ECR_DOMAIN}/${ECR_REPOSITORY_NAME}:latest ${APP_DIR}/${SUB_APP_ID}
  docker images ${ECR_DOMAIN}/${ECR_REPOSITORY_NAME}:latest

  # Push Container Images
  IMAGE_TAG=$(docker images ${ECR_DOMAIN}/${ECR_REPOSITORY_NAME}:latest --format "{{.ID}}")
  IMAGE_TAGS["${SUB_APP_ID}"]=${IMAGE_TAG}
  printf "\nUploading image: [${ECR_DOMAIN}/${ECR_REPOSITORY_NAME}:${IMAGE_TAG}]..\n"
  NUM_OF_SAME_IMAGES_ON_ECR=$(aws ecr batch-get-image --repository-name ${ECR_REPOSITORY_NAME} --image-ids imageTag=${IMAGE_TAG} --query "length(images)")
  if [ "${NUM_OF_SAME_IMAGES_ON_ECR}" -eq 0 ]; then
    aws ecr get-login-password --region ${AWS_REGION} \
      | docker login --username AWS --password-stdin ${ECR_DOMAIN}
    docker push ${ECR_DOMAIN}/${ECR_REPOSITORY_NAME}:latest
    docker tag ${ECR_DOMAIN}/${ECR_REPOSITORY_NAME}:latest ${ECR_DOMAIN}/${ECR_REPOSITORY_NAME}:${IMAGE_TAG}
    docker push ${ECR_DOMAIN}/${ECR_REPOSITORY_NAME}:${IMAGE_TAG}
  else
    printf "\nProcess skipped. The same image already exists on ECR. [${ECR_DOMAIN}/${ECR_REPOSITORY_NAME}:${IMAGE_TAG}]\n"
  fi
done
#------------------------------------------------------------#


#------------------------------------------------------------#
# Deploy Service Individual Stack
#------------------------------------------------------------#
for SUB_APP_ID in "${SUB_APP_IDS[@]}" ; do
  sam deploy \
    --template-file templates/2-svc-${SUB_APP_ID}.yml \
    --stack-name ${APP_ID}-${ENV_ID}-svc-${SUB_APP_ID}-stack \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${AWS_REGION} \
    --parameter-overrides \
      AppId=${APP_ID} \
      EnvId=${ENV_ID} \
      ImageTag=${IMAGE_TAGS["${SUB_APP_ID}"]} \
    --no-fail-on-empty-changeset
done
#------------------------------------------------------------#


success

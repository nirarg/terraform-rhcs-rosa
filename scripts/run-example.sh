#!/bin/bash

set -e

function runexample::usage() {
	echo "Usage:

	./run-example.sh <example_name>
	"
}

if (( "$#" < 1 )); then
	echo "Error:
	Unsupported command!!!
	"
        runexample::usage
	exit 1
fi

##############################################################
# Change directory to example directory given in arg $1
##############################################################

EXAMPLE_NAME=$1
shift
REPO_ROOT_DIR="$( cd -- "$(dirname "$1")" >/dev/null 2>&1 ; pwd -P )"
EXAMPLE_PATH="${REPO_ROOT_DIR}/examples/${EXAMPLE_NAME}"
if [ ! -d "${EXAMPLE_PATH}" ]; then
	echo "Error:
	Example \"${EXAMPLE_NAME}\" does not exist!!!
  Full path: \"${EXAMPLE_PATH}\"
	"
  exit 1
fi

echo "Running example \"${EXAMPLE_NAME}\" - changing directory to \"${EXAMPLE_PATH}\""
cd ${EXAMPLE_PATH}

##############################################################
# Validate environment variables
##############################################################

## declare an array with all required environment variables
declare -a env_arr=()

## User must define the token for OCM
env_arr+=("RHCS_TOKEN" "TF_VAR_cluster_name")

## For shared VPC scenario, user must provide the shared VPC AWS account details
if [ "${EXAMPLE_NAME}" = "rosa-classic-with-shared-vpc" ]; then
  env_arr+=("TF_VAR_shared_vpc_aws_key" "TF_VAR_shared_vpc_aws_secret" "TF_VAR_shared_vpc_aws_region" "TF_VAR_shared_vpc_aws_account")
fi

## now loop through the above array
NEWLINE=$'\n'
for env_name in "${env_arr[@]}"
do
  echo "**** ${!env_name}"
  if [[ -z "${!env_name}" ]]; then
    undefined_env="${undefined_env}*  ${env_name}${NEWLINE}"
  fi
done

if [[ ! -z "${undefined_env}" ]]; then
	echo "Error:
  The following environment variables are not defined!!!
  ${undefined_env}
	"
  exit 1
fi

##############################################################
# Execute terraform apply command
##############################################################

echo "Running \"terraform init\" ..."
terraform init
echo "\"terraform init\" completed"

set +e

echo "Running \"terraform apply\" ..."
terraform apply -auto-approve || _apply_failed=true
if [ $_apply_failed ]
then
    echo "\"terraform apply\" failed"
else
    echo "\"terraform apply\" completed"
fi

set -e

# echo "Running \"terraform destroy\" ..."
# terraform destroy -auto-approve
# echo "\"terraform destroy\" completed"

if [ $_apply_failed ]
then
	echo "Error:
	terraform apply was failed!!!
	"
  exit 2
fi

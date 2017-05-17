#!/usr/bin/env bash

set -e

SRC_ENV=$1
DST_ENV=$2

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
function red() {
    echo ${RED}${1}${NC}
}

function green() {
    echo ${GREEN}${1}${NC}
}

if [ ! -f "${SRC_ENV}" ]; then
    echo "Usage: ${0} <src> <dst>"
    exit 1
fi
if [ ! -f "${DST_ENV}" ]; then
    echo "Usage: ${0} <src> <dst>"
    exit 1
fi

printf "Sending $(green ${SRC_ENV}) to $(red ${DST_ENV})\n"
printf "Warning: overwrites $(red ${DST_ENV})\n"
echo "Press any key to continue, ctrl+c to cancel"
read

source "${SRC_ENV}"
SRC_MAGENTO_HOST=${MAGENTO_HOST}
SRC_MAGENTO_HOST_USER=${MAGENTO_HOST_USER}
SRC_MAGENTO_HOST_KEY=${MAGENTO_HOST_KEY}
SRC_MAGENTO_LOCATION=${MAGENTO_LOCATION}
SRC_DB_HOST=${DB_HOST}
SRC_DB_PORT=${DB_PORT}
SRC_DB_USER=${DB_USER}
SRC_DB_PASS=${DB_PASS}
SRC_DB_NAME=${DB_NAME}


source "${DST_ENV}"

ssh-add ${SRC_MAGENTO_HOST_KEY}
ssh-add ${MAGENTO_HOST_KEY}

{ echo "SRC_MAGENTO_HOST=\"${SRC_MAGENTO_HOST}\"";
  echo "SRC_MAGENTO_HOST_USER=\"${SRC_MAGENTO_HOST_USER}\"";
  echo "SRC_MAGENTO_LOCATION=\"${SRC_MAGENTO_LOCATION}\"";
  echo "SRC_DB_HOST=\"${SRC_DB_HOST}\"";
  echo "SRC_DB_PORT=\"${SRC_DB_PORT}\"";
  echo "SRC_DB_USER=\"${SRC_DB_USER}\"";
  echo "SRC_DB_PASS=\"${SRC_DB_PASS}\"";
  echo "SRC_DB_NAME=\"${SRC_DB_NAME}\"";
  cat "${DST_ENV}" remote/copy.sh; } | \
    ssh -A  "${MAGENTO_HOST_USER}@${MAGENTO_HOST}" bash

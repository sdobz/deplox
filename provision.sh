#!/bin/bash

if [ ! -f "$1" ]; then
    echo "Usage: provision.sh <env file>"
    exit 1
fi

source "$1"

# Checking sshability...
if [ -z ${MAGENTO_HOST+x} ]; then
    echo "Missing setting in ${1}:"
    echo "MAGENTO_HOST=<ec2....amazon.com>"
    exit 1
fi

if [ -z ${MAGENTO_HOST+x} ]; then
    echo "Missing setting in ${1}:"
    echo "MAGENTO_HOST_USER=<user>"
    exit 1
fi

if [ -z ${MAGENTO_HOST_KEY:x} ]; then
    echo "Missing setting in ${1}:"
    echo "MAGENTO_HOST_KEY=<EC2.rsa>"
    exit 1
fi

if [ ! -f "${MAGENTO_HOST_KEY}" ]; then
    echo "File not found:"
    echo "${MAGENTO_HOST_KEY}"
    exit 1
fi

# Checking downloadbility...
if ! ssh -q -i "${MAGENTO_HOST_KEY}" "${MAGENTO_HOST_USER}@${MAGENTO_HOST}" exit &> /dev/null; then
    echo "Unable to ssh into magento host using:"
    echo ssh -q -i ${MAGENTO_HOST_KEY} "${MAGENTO_HOST_USER}@${MAGENTO_HOST}" exit
    exit 1
fi

if [ -z ${MAGENTO_DOWNLOAD+x} ]; then
    echo "Missing setting in ${1}:"
    echo "MAGENTO_DOWNLOAD=http://.../Magento-CE-2.1.5-2017-02-20-05-36-16.tar.gz"
    exit 1
fi

if ! curl --output /dev/null --silent --head --fail "${MAGENTO_DOWNLOAD}"; then
    echo "Cannot find:"
    echo "${MAGENTO_DOWNLOAD}"
    exit 1
fi

# Checking magento config...
if [ -z ${MAGENTO_ADMIN_USERNAME:x} ]; then
    echo "Missing setting in ${1}:"
    echo "MAGENTO_ADMIN_USERNAME=admin"
    exit 1
fi
if [ -z ${MAGENTO_ADMIN_PASSWORD:x} ]; then
    echo "Missing setting in ${1}:"
    echo "MAGENTO_ADMIN_PASSWORD=password"
    exit 1
fi
if [ -z ${MAGENTO_ADMIN_EMAIL:x} ]; then
    echo "Missing setting in ${1}:"
    echo "MAGENTO_ADMIN_EMAIL=admin@email.com"
    exit 1
fi

# Checking nginx config...
if [ -z ${MAGENTO_LOCATION:x} ]; then
    echo "Missing setting in ${1}:"
    echo "MAGENTO_LOCATION=/var/www/magento2"
    exit 1
fi
if [ -z ${NGINX_CONFIG:x} ]; then
    echo "Missing setting in ${1}:"
    echo "NGINX_CONFIG=/etc/nginx/nginx.conf"
    exit 1
fi

# Checking mysql config...
if [ -z ${DB_HOST:x} ]; then
    echo "Missing setting in ${1}:"
    echo "DB_HOST="
    exit 1
fi
if [ -z ${DB_PORT:x} ]; then
    echo "Missing setting in ${1}:"
    echo "DB_PORT=3306"
    exit 1
fi
if [ -z ${DB_USER:x} ]; then
    echo "Missing setting in ${1}:"
    echo "DB_USER=magento2"
    exit 1
fi
if [ -z ${DB_PASS:x} ]; then
    echo "Missing setting in ${1}:"
    echo "DB_PASS=magento2"
    exit 1
fi
if [ -z ${DB_NAME:x} ]; then
    echo "Missing setting in ${1}:"
    echo "DB_NAME=magento2"
    exit 1
fi

# Checking plugin config...
if [ -z ${MAGENTO_PLUGIN_REPO:x} ]; then
    echo "Missing setting in ${1}:"
    echo "MAGENTO_PLUGIN_REPO=git@github.com:user/repo.git"
    exit 1
fi
if [ -z ${MAGENTO_PLUGIN_USER:x} ]; then
    echo "Missing setting in ${1}:"
    echo "MAGENTO_PLUGIN_USER=ec2-user"
    exit 1
fi
if [ -z ${MAGENTO_PLUGIN_DIRECTORY:x} ]; then
    echo "Missing setting in ${1}:"
    echo "MAGENTO_PLUGIN_DIRECTORY=\${MAGENTO_DIRECTORY}/app/code/Plugin"
    exit 1
fi
if [ -z ${MAGENTO_PLUGIN_KEY:x} ]; then
    echo "Missing setting in ${1}:"
    echo "MAGENTO_PLUGIN_KEY=<key.rsa>"
    exit 1
fi
if [ ! -f "${MAGENTO_PLUGIN_KEY}" ]; then
    echo "File not found:"
    echo "${MAGENTO_PLUGIN_KEY}"
    exit 1
fi

# Checking webhook config...
if [ -z ${WEBHOOK_REPO:x} ]; then
    echo "Missing setting in ${1}:"
    echo "WEBHOOK_REPO=https://github.com/sdobz/watchandlisten.git"
    exit 1
fi
if [ -z ${WEBHOOK_LOCATION:x} ]; then
    echo "Missing setting in ${1}:"
    echo "WEBHOOK_LOCATION=/opt/watchandlisten"
    exit 1
fi
if [ -z ${WEBHOOK_BIN:x} ]; then
    echo "Missing setting in ${1}:"
    echo "WEBHOOK_BIN=/opt/watchandlisten/watchandlisten"
    exit 1
fi
if [ -z "${WEBHOOK_LOG:x}" ]; then
    echo "Missing setting in ${1}:"
    echo "WEBHOOK_LOG=/var/log/watchandlisten/out.log"
    exit 1
fi
if [ -z "${WEBHOOK_CONFIG:x}" ]; then
    echo "Missing setting in ${1}:"
    echo "WEBHOOK_CONFIG={...}"
    exit 1
fi

{ echo "MAGENTO_PLUGIN_KEY_CONTENTS=\"$(cat ${MAGENTO_PLUGIN_KEY})\"";
  cat "$1" remote/{base,config,provision}.sh; } | \
    ssh -i "${MAGENTO_HOST_KEY}" "${MAGENTO_HOST_USER}@${MAGENTO_HOST}" bash

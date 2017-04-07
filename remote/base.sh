check_deps() {
    if ! which yum &> /dev/null; then
        echo "yum not found on ${MAGENTO_HOST}"
        return 1
    fi
    if ! which curl &> /dev/null; then
        echo "curl not found on ${MAGENTO_HOST}"
        return 1
    fi
    return 0
}

install_packages() {
    echo Installing php...
    sudo yum install -y php56 php56-gd php56-mcrypt php56-intl php56-mbstring php56-fpm php56-pdo php56-mysqlnd
    echo Installing nginx...
    sudo yum install -y nginx
    echo Installing mysql...
    sudo yum install -y mysql
    echo Installing git...
    sudo yum install -y git
    echo Installing golang...
    sudo yum install -y golang
    echo Installing monit...
    sudo yum install -y monit
}

test_mysql() {
    echo Testing mysql connection...
    if ! mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" "-p${DB_PASS}" -e"quit" ${DB_NAME} &> /dev/null; then
        echo "Cannot connect to mysql"
        return 1
    fi
    return 0
}

install_magento() {
    echo Installing magento...
    MAGENTO_FILENAME="/tmp/magento.tar.gz"
    if ! sudo mkdir -p ${MAGENTO_LOCATION}; then
        echo "Could not make magento location"
        return 1
    fi

    echo "Downloading ${MAGENTO_DOWNLOAD}"

    if ! curl -o "${MAGENTO_FILENAME}" "${MAGENTO_DOWNLOAD}"; then
        echo "Failed to download magento"
        return 1
    fi
    echo
    echo
    echo "Extracting ${MAGENTO_FILENAME} to ${MAGENTO_LOCATION}"
    if ! sudo tar -xzf ${MAGENTO_FILENAME} -C ${MAGENTO_LOCATION}; then
        echo "Failed to extract"
        return 1
    fi

    rm "${MAGENTO_FILENAME}"

    return 0
}

install_plugin() {
    echo Installing magento plugin...

    if ! sudo mkdir -p ${MAGENTO_PLUGIN_DIRECTORY}; then
        echo "Making plugin directory ${MAGENTO_PLUGIN_DIRECTORY} failed"
        return 1
    fi

    if ! sudo chown ${MAGENTO_PLUGIN_USER} ${MAGENTO_PLUGIN_DIRECTORY}; then
        echo "Changing plugin directory permissions failed"
        return 1
    fi

    KEY_LOC=${MAGENTO_PLUGIN_KEY_REMOTE_LOCATION}

    KEY_DIR=$(dirname "${KEY_LOC}")
    if ! sudo mkdir -p ${KEY_DIR}; then
        echo "Failed making key directory ${KEY_DIR}"
        return 1
    fi

    if ! echo "${MAGENTO_PLUGIN_KEY_CONTENTS}" | sudo tee "${KEY_LOC}" &> /dev/null; then
        echo "Failed writing deploy key to ${KEY_LOC}"
        return 1
    fi

    if ! sudo chmod 600 "${KEY_LOC}"; then
        echo "Failed changing ${KEY_LOC} permissions"
        return 1
    fi

    if ! sudo chown ${MAGENTO_PLUGIN_USER} "${KEY_LOC}"; then
        echo "Failed chown ${KEY_LOC}"
        return 1
    fi

    if [ -f ${MAGENTO_PLUGIN_DIRECTORY}/.git/config ]; then
        echo "Repo exists, pulling"
        if ! sudo -u ${MAGENTO_PLUGIN_USER} GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i ${KEY_LOC}" git -C "${MAGENTO_PLUGIN_DIRECTORY}" pull; then
            echo "Pull failed"
            return 1
        fi
    else
        echo "Cloning ${MAGENTO_PLUGIN_REPO} into ${MAGENTO_PLUGIN_DIRECTORY}"
        if ! sudo -u ${MAGENTO_PLUGIN_USER} GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i ${KEY_LOC}" git clone "${MAGENTO_PLUGIN_REPO}" "${MAGENTO_PLUGIN_DIRECTORY}"; then
            echo "Clone failed"
            return 1
        fi
    fi

    return 0
}

configure_nginx() {
    if ! write_nginx_config; then
        echo "Nginx configuration failed"
        return 1
    fi

    if ! sudo /sbin/chkconfig nginx on; then
        echo "Nginx set startup failed"
        return 1
    fi

    echo Restarting nginx
    if ! sudo service nginx restart; then
        echo "Restarting nginx failed"
        return 1
    fi


    return 0
}

configure_php() {
    if ! sudo /sbin/chkconfig php-fpm on; then
        echo "php-fpm set startup failed"
        return 1
    fi

    echo Restarting php-fpm
    if ! sudo service php-fpm restart; then
        echo "Restarting php-fpm failed"
        return 1
    fi
    return 0
}

configure_magento() {
    echo "Configuring magento..."
    echo "Setting ownership of ${MAGENTO_LOCATION}/var/"
    if ! sudo chown -R ${PHP_USER} ${MAGENTO_LOCATION}/var/; then
        echo "Changing ownership failed"
        return 1
    fi
    echo "Setting ownership of ${MAGENTO_LOCATION}/app/etc"
    if ! sudo chown -R ${PHP_USER} ${MAGENTO_LOCATION}/app/etc; then
        echo "Changing ownership failed"
        return 1
    fi
    echo "Setting ownership of ${MAGENTO_LOCATION}/pub/media"
    if ! sudo chown -R ${PHP_USER} ${MAGENTO_LOCATION}/pub/media; then
        echo "Changing ownership failed"
        return 1
    fi
    echo "Setting ownership of ${MAGENTO_LOCATION}/pub/static"
    if ! sudo chown -R ${PHP_USER} ${MAGENTO_LOCATION}/pub/static; then
        echo "Changing ownership failed"
        return 1
    fi

    MAGENTO_BIN="${MAGENTO_LOCATION}/bin/magento"
    if [ ! -f ${MAGENTO_BIN} ]; then
        echo "Unable to locate magento bin"
        return 1
    fi

    echo "Setting permissions of ${MAGENTO_BIN}"
    if ! sudo chmod +x ${MAGENTO_BIN}; then
        echo "Changing permissions failed"
        return 1
    fi

    if ! sudo -u ${PHP_USER} ${MAGENTO_BIN} setup:install \
        --admin-user="${MAGENTO_ADMIN_USERNAME}" --admin-password="${MAGENTO_ADMIN_PASSWORD}" \
        --admin-email="${MAGENTO_ADMIN_EMAIL}" \
        --admin-firstname="FN" --admin-lastname="LN" \
        --db-host="${DB_HOST}" --db-user="${DB_USER}" --db-password="${DB_PASS}" --db-name="${DB_NAME}"; then
        echo "Setup failed"
        return 1
    fi

    echo "Clearing ownership of ${MAGENTO_LOCATION}/app/etc"
    if ! sudo chown -R root ${MAGENTO_LOCATION}/app/etc; then
        echo "Changing ownership failed"
        return 1
    fi

    return 0
}

install_webhook() {
    echo "Installing webhook"

    if [ -f "${WEBHOOK_LOCATION}/.git/config" ]; then
        echo "Repo exists, pulling"
        if ! sudo git -C "${WEBHOOK_LOCATION}" pull; then
            echo "Pull failed"
            return 1
        fi
    else
        echo "Cloning ${WEBHOOK_REPO} into ${WEBHOOK_LOCATION}"
        if ! sudo git clone "${WEBHOOK_REPO}" "${WEBHOOK_LOCATION}"; then
            echo "Clone failed"
            return 1
        fi
    fi

    sudo go build -o "${WEBHOOK_BIN}" "${WEBHOOK_LOCATION}/watchandlisten.go"
}

configure_webhook() {
    echo "Configuring webhook"

    if ! sudo mkdir -p /etc/watchandlisten; then
        echo "Failed making /etc/watchandlisten"
        return 1
    fi

    if ! echo "${WEBHOOK_CONFIG}" | sudo tee /etc/watchandlisten/conf.json &> /dev/null; then
        echo "Failed writing /etc/watchandlisten/conf.json"
        return 1
    fi

    LOG_DIR=$(dirname ${WEBHOOK_LOG})
    if ! sudo mkdir -p ${LOG_DIR}; then
        echo "Creating ${LOG_DIR} failed"
        return 1
    fi

    if ! sudo chown -R ${MAGENTO_PLUGIN_USER} "${LOG_DIR}"; then
        echo "Changing permissions on ${LOG_DIR} failed"
        return 1
    fi
    if ! sudo -u ${MAGENTO_PLUGIN_USER} touch ${WEBHOOK_LOG}; then
        echo "Creating ${WEBHOOK_LOG} failed"
        return 1
    fi

    if ! ${WEBHOOK_BIN} -test; then
        echo "Webhook conf test failed"
        return 1
    fi

    if [ ! -f "${WEBHOOK_LOCATION}/watchandlisten.init.d" ]; then
        echo "${WEBHOOK_LOCATION}/watchandlisten.init.d not found"
        return 1
    fi

    if ! sudo cp "${WEBHOOK_LOCATION}/watchandlisten.init.d" /etc/init.d/watchandlisten; then
        echo "Copying watchandlisten.init.d to /etc/init.d/watchandlisten failed"
        return 1
    fi

    if ! sudo /sbin/chkconfig watchandlisten on; then
        echo "Setting startup for watchandlisten failed"
        return 1
    fi

    if ! sudo service watchandlisten restart; then
        echo "Restarting watchandlisten failed"
        return 1
    fi

    return 0
}

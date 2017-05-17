set -e

MEDIA_LOC=/pub/media
ME=$(whoami)

sudo chown -R ${ME} "${MAGENTO_LOCATION}${MEDIA_LOC}"
rsync -azvp -e "ssh -o StrictHostKeyChecking=no" "${SRC_MAGENTO_HOST_USER}@${SRC_MAGENTO_HOST}:${SRC_MAGENTO_LOCATION}${MEDIA_LOC}/" "${MAGENTO_LOCATION}${MEDIA_LOC}"
sudo chown -R ${PHP_USER} "${MAGENTO_LOCATION}${MEDIA_LOC}"

echo Dumping db...
mysqldump -h "${SRC_DB_HOST}" -P "${SRC_DB_PORT}" -u "${SRC_DB_USER}" "-p${SRC_DB_PASS}" ${SRC_DB_NAME} | mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" "-p${DB_PASS}" ${DB_NAME}
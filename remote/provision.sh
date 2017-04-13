if ! check_deps; then
    echo "Deps incorrect"
    exit 1
fi

echo "All checks passed, provisioning..."

if ! install_packages; then
    echo "Package installation failed"
    exit 1
fi

if ! test_mysql; then
    echo "Mysql test failed"
    exit 1
fi

if ! install_magento; then
    echo "Magento installation failed"
    exit 1
fi

if ! install_plugin; then
    echo "Magento plugin installation failed"
    exit 1
fi

if ! configure_nginx; then
    echo "Nginx configuration failed"
    exit 1
fi

if ! configure_php; then
    echo "PHP configuration failed"
    exit 1
fi

if ! configure_magento; then
    echo "Magento configuration failed"
    exit 1
fi

if ! install_webhook; then
    echo "Webhook installation failed"
    exit 1
fi

if ! configure_webhook; then
    echo "Webhook configuration failed"
    exit 1
fi

if ! install_cron; then
    echo "Cron install failed"
    exit 1
fi
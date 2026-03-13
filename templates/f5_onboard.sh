#!/bin/bash

LOG_FILE=/var/log/user_data_onboard.log
exec > $LOG_FILE 2>&1

echo "Starting BIG-IP Onboarding..."

# Wait for MCPD to be ready before running tmsh commands
source /usr/lib/bigstart/bigip-ready-functions
wait_bigip_ready

# 1. Set the Admin Password
echo "Setting Admin Password..."
tmsh modify auth user admin password ${admin_pass}
tmsh save sys config

# 1. License the BIG-IP
echo "Applying License: ${license_key}"
tmsh install sys license registration-key ${license_key}

# 2. Download CFE from GitHub
echo "Downloading CFE from ${cfe_url}"
mkdir -p /var/config/rest/downloads
curl -L -o /var/config/rest/downloads/f5-cloud-failover.rpm "${cfe_url}"

# Wait for the REST framework (restjavad) to be fully up before attempting installation
echo "Waiting for restjavad to start..."
until curl -s -u admin:${admin_pass} http://localhost:8100/mgmt/shared/echo | grep "build"; do
    sleep 10
done

# 3. Install CFE via REST API
echo "Installing Cloud Failover Extension..."
curl -u admin:${admin_pass} -X POST http://localhost:8100/mgmt/shared/iapp/package-management-tasks \
  -d '{
    "operation": "INSTALL",
    "packageFilePath": "/var/config/rest/downloads/f5-cloud-failover.rpm"
  }'

echo "Onboarding script completed."
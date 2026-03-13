#!/bin/bash

LOG_FILE=/var/log/user_data_onboard.log
exec > $LOG_FILE 2>&1

echo "Starting BIG-IP Onboarding..."

# 1. Wait for MCPD to be ready before running any tmsh commands
source /usr/lib/bigstart/bigip-ready-functions
wait_bigip_ready

# 2. Set the Admin Password immediately
echo "Setting Admin Password..."
tmsh modify auth user admin password ${admin_pass}
tmsh save sys config

# 3. Apply License with Retry Loop (Waits for AWS Internet/EIP to attach)
echo "Applying License: ${license_key}"
for i in {1..10}; do
    tmsh install sys license registration-key ${license_key}
    
    # Check if the command was successful
    if [ $? -eq 0 ]; then
        echo "License installed successfully on attempt $i!"
        break
    else
        echo "License installation failed (Waiting for Internet/EIP). Retrying in 30 seconds... ($i/10)"
        sleep 30
    fi
done

# 4. Download DO and CFE from GitHub
echo "Downloading DO and CFE packages..."
mkdir -p /var/config/rest/downloads
curl -L -o /var/config/rest/downloads/f5-cloud-failover.rpm "${cfe_url}"
curl -L -o /var/config/rest/downloads/f5-declarative-onboarding.rpm "${do_url}"

# 5. Wait for the REST framework (restjavad) to be fully up
echo "Waiting for restjavad to start..."
until curl -s -u admin:${admin_pass} http://localhost:8100/mgmt/shared/echo | grep "build"; do
    sleep 10
done

# 6. Install DO and CFE via REST API
echo "Installing Extensions..."

# Install Declarative Onboarding (DO)
curl -u admin:${admin_pass} -X POST http://localhost:8100/mgmt/shared/iapp/package-management-tasks \
  -d '{
    "operation": "INSTALL",
    "packageFilePath": "/var/config/rest/downloads/f5-declarative-onboarding.rpm"
  }'

# Install Cloud Failover Extension (CFE)
curl -u admin:${admin_pass} -X POST http://localhost:8100/mgmt/shared/iapp/package-management-tasks \
  -d '{
    "operation": "INSTALL",
    "packageFilePath": "/var/config/rest/downloads/f5-cloud-failover.rpm"
  }'

echo "Onboarding script completed."
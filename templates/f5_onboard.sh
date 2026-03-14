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
    
    if [ $? -eq 0 ]; then
        echo "License installed successfully on attempt $i!"
        break
    else
        echo "License installation failed (Waiting for Internet/EIP). Retrying in 30 seconds... ($i/10)"
        sleep 30
    fi
done

# 4. Allocate Extra Memory for REST Daemons (CFE/DO Best Practice)
echo "Allocating extra memory for REST daemons..."
tmsh modify sys db provision.extramb value 1000 || true
tmsh modify sys db restjavad.useextramb value true || true
# For BIG-IP 17.1.x and later:
tmsh modify sys db provision.restjavad.extramb value 1000 || true
tmsh save sys config

echo "Restarting restjavad and restnoded..."
bigstart restart restjavad restnoded

# 5. Download DO and CFE from GitHub
echo "Downloading DO and CFE packages..."
mkdir -p /var/config/rest/downloads
curl -L -o /var/config/rest/downloads/f5-cloud-failover.rpm "${cfe_url}"
curl -L -o /var/config/rest/downloads/f5-declarative-onboarding.rpm "${do_url}"

# 6. Wait for the REST framework (restjavad) to fully reboot
echo "Waiting for restjavad to start..."
until curl -s -u admin:${bigip_admin_password} http://localhost:8100/mgmt/shared/echo | grep "build"; do
    sleep 10
done

# 7. Install DO and CFE via REST API 
echo "Installing Extensions..."

# Install Declarative Onboarding (DO)
DO_DATA="{\"operation\":\"INSTALL\",\"packageFilePath\":\"/var/config/rest/downloads/f5-declarative-onboarding.rpm\"}"
curl -u admin:${bigip_admin_password} -X POST http://localhost:8100/mgmt/shared/iapp/package-management-tasks \
  -H "Origin: http://localhost:8100" \
  -H 'Content-Type: application/json;charset=UTF-8' \
  --data "$DO_DATA"

# Install Cloud Failover Extension (CFE)
CFE_DATA="{\"operation\":\"INSTALL\",\"packageFilePath\":\"/var/config/rest/downloads/f5-cloud-failover.rpm\"}"
curl -u admin:${bigip_admin_password} -X POST http://localhost:8100/mgmt/shared/iapp/package-management-tasks \
  -H "Origin: http://localhost:8100" \
  -H 'Content-Type: application/json;charset=UTF-8' \
  --data "$CFE_DATA"

# 8. Verify Installations 
echo "Verifying DO Installation..."
until curl -s -u admin:${bigip_admin_password} http://localhost:8100/mgmt/shared/declarative-onboarding/info | grep "version"; do
    echo "Waiting for DO API to become available..."
    sleep 10
done

echo "Verifying CFE Installation..."
until curl -s -u admin:${bigip_admin_password} http://localhost:8100/mgmt/shared/cloud-failover/info | grep "version"; do
    echo "Waiting for CFE API to become available..."
    sleep 10
done

echo "Onboarding script completed."
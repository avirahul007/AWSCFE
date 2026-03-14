#!/bin/bash

LOG_FILE=/var/log/user_data_onboard.log
exec > $LOG_FILE 2>&1

echo "Starting BIG-IP Onboarding..."

# 1. Wait for MCPD to be ready
source /usr/lib/bigstart/bigip-ready-functions
wait_bigip_ready

# 2. Set the Admin Password immediately
echo "Setting Admin Password..."
tmsh modify auth user admin password ${admin_pass}
tmsh save sys config

# 3. Apply License with Retry Loop
echo "Applying License: ${license_key}"
for i in {1..10}; do
    tmsh install sys license registration-key ${license_key}
    
    if [ $? -eq 0 ]; then
        echo "License installed successfully on attempt $i!"
        break
    else
        echo "License installation failed. Retrying in 30 seconds... ($i/10)"
        sleep 30
    fi
done

echo "Restarting restjavad and restnoded..."
bigstart restart restjavad restnoded

echo "Base Onboarding script completed. Handing over to Terraform for package installation."
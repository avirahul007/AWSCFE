#!/bin/bash

LOG_FILE=/var/log/user_data_onboard.log
exec > $LOG_FILE 2>&1

echo "Starting BIG-IP Onboarding..."

# Wait for MCPD to be ready
source /usr/lib/bigstart/bigip-ready-functions
wait_bigip_ready

# Set the Admin Password immediately
echo "Setting Admin Password..."
tmsh modify auth user admin password '${bigip_admin_password}'
tmsh save sys config

# Apply License with Retry Loop
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

# Prepare Download Directory
echo "Preparing local download directory..."

cd /var/config/rest/downloads

# Robust Download Loop for DO Package
echo "Downloading DO package from GitHub..."
for i in {1..5}; do
    # -L follows redirects, -O saves the remote filename, --fail catches HTTP errors
    curl -L --fail -O "${do_url}"
    
    if [ $? -eq 0 ]; then
        echo "DO package downloaded successfully!"
        break
    else
        echo "Attempt $i failed to download DO package. Retrying in 15 seconds..."
        sleep 15
    fi
done

# Robust Download Loop for CFE Package
echo "Downloading CFE package from GitHub..."
for i in {1..5}; do
    curl -L --fail -O "${cfe_url}"
    
    if [ $? -eq 0 ]; then
        echo "CFE package downloaded successfully!"
        break
    else
        echo "Attempt $i failed to download CFE package. Retrying in 15 seconds..."
        sleep 15
    fi
done

echo "Base Onboarding script completed. Handing over to Terraform for package installation."
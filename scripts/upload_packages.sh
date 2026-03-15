#!/bin/bash
# Stop execution immediately if any command fails
set -e 

BIGIP_IP=$1
CREDS="$2:$3"
DO_URL=$4
CFE_URL=$5

FN_DO="f5-declarative-onboarding-1.47.0-14.noarch.rpm"
FN_CFE="f5-cloud-failover-2.4.0-0.noarch.rpm"

echo "======================================================"
echo "--- Downloading Packages Locally ---"
echo "======================================================"
curl -k -L -O "$DO_URL"
curl -k -L -O "$CFE_URL"

# ---------------------------------------------------------
# F5 Official File Size Calculation - FIXED
# Using awk automatically strips leading/trailing spaces on Mac & Linux
# ---------------------------------------------------------
LEN_DO=$(wc -c "$FN_DO" | awk '{print $1}')
LEN_CFE=$(wc -c "$FN_CFE" | awk '{print $1}')

echo "Calculated DO Size: $LEN_DO bytes"
echo "Calculated CFE Size: $LEN_CFE bytes"

echo "======================================================"
echo "--- Uploading & Installing DO to BIG-IP ($BIGIP_IP) ---"
echo "======================================================"

# Added --fail so curl throws an explicit error if F5 rejects the upload
curl -kvu "$CREDS" --fail "https://$BIGIP_IP/mgmt/shared/file-transfer/uploads/$FN_DO" \
      -H 'Content-Type: application/octet-stream' \
      -H "Content-Range: 0-$((LEN_DO - 1))/$LEN_DO" \
      -H "Content-Length: $LEN_DO" \
      -H 'Connection: keep-alive' \
      --data-binary @"$FN_DO"

DATA_DO="{\"operation\":\"INSTALL\",\"packageFilePath\":\"/var/config/rest/downloads/$FN_DO\"}"
curl -kvu "$CREDS" --fail "https://$BIGIP_IP/mgmt/shared/iapp/package-management-tasks" \
      -H "Origin: https://$BIGIP_IP" \
      -H 'Content-Type: application/json;charset=UTF-8' \
      --data "$DATA_DO"

echo "======================================================"
echo "--- Uploading & Installing CFE to BIG-IP ($BIGIP_IP) ---"
echo "======================================================"

curl -kvu "$CREDS" --fail "https://$BIGIP_IP/mgmt/shared/file-transfer/uploads/$FN_CFE" \
      -H 'Content-Type: application/octet-stream' \
      -H "Content-Range: 0-$((LEN_CFE - 1))/$LEN_CFE" \
      -H "Content-Length: $LEN_CFE" \
      -H 'Connection: keep-alive' \
      --data-binary @"$FN_CFE"

DATA_CFE="{\"operation\":\"INSTALL\",\"packageFilePath\":\"/var/config/rest/downloads/$FN_CFE\"}"
curl -kvu "$CREDS" --fail "https://$BIGIP_IP/mgmt/shared/iapp/package-management-tasks" \
      -H "Origin: https://$BIGIP_IP" \
      -H 'Content-Type: application/json;charset=UTF-8' \
      --data "$DATA_CFE"

echo "======================================================"
echo "Cleaning up local files..."
rm "$FN_DO" "$FN_CFE"

echo "Packages uploaded and installing. F5 REST services will restart."
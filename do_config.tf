locals {
  # =========================================================
  # BIG-IP 1: Networking, HA Trust (via Internal), and Device Group
  # =========================================================
  do_payload_bigip1 = {
    schemaVersion = "1.0.0"
    class         = "Device"
    async         = true
    Common = {
      class    = "Tenant"
      mySystem = { class = "System", hostname = "bigip1.local" }
      ntp = {
        class    = "NTP"
        servers  = ["169.254.169.123"]
        timezone = "UTC"
      }
      ext_vlan = { class = "VLAN", interfaces = [{ name = "1.1", tagged = false }] }
      int_vlan = { class = "VLAN", interfaces = [{ name = "1.2", tagged = false }] }
      
      ext_self = { class = "SelfIp", address = "${var.bigip_external_self_ips[0]}/24", vlan = "ext_vlan", allowService = "default" }
      int_self = { class = "SelfIp", address = "${var.bigip_internal_self_ips[0]}/24", vlan = "int_vlan", allowService = "default" }
      
      # Route for 10.0.0.0/8 pointing to the Internal Subnet Gateway
      internal_net_route = {
        class     = "Route"
        network   = "10.0.0.0/8"
        gw        = cidrhost("${var.bigip_internal_self_ips[0]}/24", 1)
        localOnly = true
      }

      # ConfigSync and Failover heartbeats on the high-speed Internal TMM Network
      configsync      = { class = "ConfigSync", configsyncIp = var.bigip_internal_self_ips[0] }
      failoverAddress = { class = "FailoverUnicast", address = var.bigip_internal_self_ips[0], port = 1026 }
      
      failoverGroup = {
        class           = "DeviceGroup"
        type            = "sync-failover"
        members         = ["bigip1.local", "bigip2.local"]
        owner           = "bigip1.local"
        autoSync        = true
        networkFailover = true
      }

      # Device Trust established over the high-speed Internal TMM Network
      trust = {
        class          = "DeviceTrust"
        localUsername  = "admin"
        localPassword  = var.bigip_admin_password
        remoteHost     = var.bigip_internal_self_ips[1] 
        remoteUsername = "admin"
        remotePassword = var.bigip_admin_password
        localSelfIp    = var.bigip_internal_self_ips[0]
      }
    }
  }

  # =========================================================
  # BIG-IP 2: Networking Only (Preps the standby unit)
  # =========================================================
  do_payload_bigip2 = {
    schemaVersion = "1.0.0"
    class         = "Device"
    async         = true
    Common = {
      class    = "Tenant"
      mySystem = { class = "System", hostname = "bigip2.local" }
      ntp = {
        class    = "NTP"
        servers  = ["169.254.169.123"]
        timezone = "UTC"
      }
      ext_vlan = { class = "VLAN", interfaces = [{ name = "1.1", tagged = false }] }
      int_vlan = { class = "VLAN", interfaces = [{ name = "1.2", tagged = false }] }
      
      ext_self = { class = "SelfIp", address = "${var.bigip_external_self_ips[1]}/24", vlan = "ext_vlan", allowService = "default" }
      int_self = { class = "SelfIp", address = "${var.bigip_internal_self_ips[1]}/24", vlan = "int_vlan", allowService = "default" }

      # Route for 10.0.0.0/8 pointing to the Internal Subnet Gateway
      internal_net_route = {
        class     = "Route"
        network   = "10.0.0.0/8"
        gw        = cidrhost("${var.bigip_internal_self_ips[1]}/24", 1)
        localOnly = true
      }
      
      # ConfigSync and Failover prep on Internal network
      configsync      = { class = "ConfigSync", configsyncIp = var.bigip_internal_self_ips[1] }
      failoverAddress = { class = "FailoverUnicast", address = var.bigip_internal_self_ips[1], port = 1026 }
    }
  }
}

# =========================================================
# DEPLOYMENT LOGIC (Strict Execution Order)
# =========================================================

# Push Configuration to BIG-IP 2 FIRST
resource "null_resource" "deploy_do_bigip2" {
  depends_on = [aws_instance.bigip2, null_resource.install_packages_bigip2]
  
  provisioner "local-exec" {
    command = <<EOT
      set -e
      # Write payload safely using echo to prevent indentation formatting bugs
      echo '${jsonencode(local.do_payload_bigip2)}' > do_payload2.json

      echo "Pushing DO Declaration to BIG-IP 2 via Public IP..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X POST https://${aws_eip.mgmt_eip[1].public_ip}/mgmt/shared/declarative-onboarding \
        -H "Content-Type: application/json" \
        -d @do_payload2.json

      echo "Polling Async Task Status for BIG-IP 2..."
      until curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X GET https://${aws_eip.mgmt_eip[1].public_ip}/mgmt/shared/declarative-onboarding/task | grep -q '"message":"success"\|"status":"FINISHED"'; do
          sleep 10
      done
      echo "BIG-IP 2 Networking Configured!"
    EOT
  }
}

# Push Configuration to BIG-IP 1 SECOND
resource "null_resource" "deploy_do_bigip1" {
  # Critical dependency: Do not start until BIG-IP 2 is fully online
  depends_on = [null_resource.deploy_do_bigip2, null_resource.install_packages_bigip1]
  
  provisioner "local-exec" {
    command = <<EOT
      set -e
      # Write payload safely using echo to prevent indentation formatting bugs
      echo '${jsonencode(local.do_payload_bigip1)}' > do_payload1.json

      echo "Pushing DO Declaration to BIG-IP 1 via Public IP..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X POST https://${aws_eip.mgmt_eip[0].public_ip}/mgmt/shared/declarative-onboarding \
        -H "Content-Type: application/json" \
        -d @do_payload1.json

      echo "Polling Async Task Status for BIG-IP 1 HA Cluster..."
      until curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X GET https://${aws_eip.mgmt_eip[0].public_ip}/mgmt/shared/declarative-onboarding/task | grep -q '"message":"success"\|"status":"FINISHED"'; do
          sleep 10
      done
      echo "BIG-IP 1 HA Cluster Configured successfully!"

      # ========================================================
      # Force initial ConfigSync from BIG-IP 1 to the Group
      # ========================================================
      echo "Allowing cluster trust to settle for 15 seconds..."
      sleep 15
      
      echo "Triggering manual ConfigSync to group 'failoverGroup'..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X POST https://${aws_eip.mgmt_eip[0].public_ip}/mgmt/tm/cm \
        -H "Content-Type: application/json" \
        -d '{"command":"run", "utilCmdArgs":"config-sync to-group failoverGroup"}'
        
      echo -e "\nConfigSync command issued!"
    EOT
  }
}
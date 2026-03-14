locals {
  # BIG-IP 1: Networking, HA Trust, and Device Group
  do_payload_bigip1 = {
    schemaVersion = "1.0.0"
    class         = "Device"
    async         = true
    Common = {
      class    = "Tenant"
      mySystem = { class = "System", hostname = "bigip1.local" }
      ext_vlan = { class = "VLAN", interfaces = [{ name = "1.1", tagged = false }] }
      int_vlan = { class = "VLAN", interfaces = [{ name = "1.2", tagged = false }] }
      
      ext_self = { class = "SelfIp", address = "${var.bigip_external_self_ips[0]}/24", vlan = "ext_vlan", allowService = "default" }
      int_self = { class = "SelfIp", address = "${var.bigip_internal_self_ips[0]}/24", vlan = "int_vlan", allowService = "default" }
      
      # Internal ConfigSync MUST use the private IPs
      configsync = { class = "ConfigSync", configsyncIp = var.bigip1_mgmt_ip }
      
      failoverGroup = {
        class           = "DeviceGroup"
        type            = "sync-failover"
        members         = ["bigip1.local", "bigip2.local"]
        owner           = "bigip1.local"
        autoSync        = true
        networkFailover = true
      }
      trust = {
        class          = "DeviceTrust"
        localUsername  = "admin"
        localPassword  = var.bigip_admin_password
        remoteHost     = var.bigip2_mgmt_ip
        remoteUsername = "admin"
        remotePassword = var.bigip_admin_password
      }
    }
  }

  # BIG-IP 2: Networking Only
  do_payload_bigip2 = {
    schemaVersion = "1.0.0"
    class         = "Device"
    async         = true
    Common = {
      class    = "Tenant"
      mySystem = { class = "System", hostname = "bigip2.local" }
      ext_vlan = { class = "VLAN", interfaces = [{ name = "1.1", tagged = false }] }
      int_vlan = { class = "VLAN", interfaces = [{ name = "1.2", tagged = false }] }
      
      ext_self = { class = "SelfIp", address = "${var.bigip_external_self_ips[1]}/24", vlan = "ext_vlan", allowService = "default" }
      int_self = { class = "SelfIp", address = "${var.bigip_internal_self_ips[1]}/24", vlan = "int_vlan", allowService = "default" }
      
      configsync = { class = "ConfigSync", configsyncIp = var.bigip2_mgmt_ip }
    }
  }
}

# Push Configuration to BIG-IP 2 FIRST
resource "null_resource" "deploy_do_bigip2" {
  depends_on = [aws_instance.bigip]

  provisioner "local-exec" {
    command = <<EOT
      until curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' https://${aws_eip.mgmt_eip[1].public_ip}/mgmt/shared/declarative-onboarding/info | grep "version"; do sleep 15; done

      cat > do_payload2.json <<EOF
      ${jsonencode(local.do_payload_bigip2)}
      EOF

      echo "Pushing DO Declaration to BIG-IP 2 via Public IP..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X POST https://${aws_eip.mgmt_eip[1].public_ip}/mgmt/shared/declarative-onboarding \
        -H "Content-Type: application/json" \
        -d @do_payload2.json

      echo "Polling Async Task Status for BIG-IP 2 (Per F5 Docs)..."
      until curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X GET https://${aws_eip.mgmt_eip[1].public_ip}/mgmt/shared/declarative-onboarding/task | grep -q '"message":"success"\|"status":"FINISHED"'; do
          echo "Waiting for DO to apply..."
          sleep 10
      done
      echo "BIG-IP 2 Networking Configured!"
    EOT
  }
}

# Push Configuration to BIG-IP 1 SECOND
resource "null_resource" "deploy_do_bigip1" {
  depends_on = [null_resource.deploy_do_bigip2]

  provisioner "local-exec" {
    command = <<EOT
      until curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' https://${aws_eip.mgmt_eip[0].public_ip}/mgmt/shared/declarative-onboarding/info | grep "version"; do sleep 15; done

      cat > do_payload1.json <<EOF
      ${jsonencode(local.do_payload_bigip1)}
      EOF

      echo "Pushing DO Declaration to BIG-IP 1 via Public IP..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X POST https://${aws_eip.mgmt_eip[0].public_ip}/mgmt/shared/declarative-onboarding \
        -H "Content-Type: application/json" \
        -d @do_payload1.json

      echo "Polling Async Task Status for BIG-IP 1 HA Cluster (Per F5 Docs)..."
      until curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X GET https://${aws_eip.mgmt_eip[0].public_ip}/mgmt/shared/declarative-onboarding/task | grep -q '"message":"success"\|"status":"FINISHED"'; do
          echo "Waiting for DO to apply and Cluster to build..."
          sleep 10
      done
      echo "BIG-IP 1 HA Cluster Configured!"
    EOT
  }
}
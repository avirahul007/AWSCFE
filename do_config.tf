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
      
      configsync = { class = "ConfigSync", configsyncIp = var.bigip_internal_self_ips[0] }
      
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

  # BIG-IP 2: Networking Only (It will be joined to the cluster by BIG-IP 1)
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
      
      configsync = { class = "ConfigSync", configsyncIp = var.bigip_internal_self_ips[1] }
    }
  }
}

# Push Configuration to BIG-IP 2 FIRST (So its IPs are ready to be trusted)
resource "null_resource" "deploy_do_bigip2" {
  depends_on = [aws_instance.bigip]

  provisioner "local-exec" {
    command = <<EOT
      # Wait for DO API to be available
      until curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' https://${var.bigip2_mgmt_ip}/mgmt/shared/declarative-onboarding/info | grep "version"; do sleep 15; done
      
      cat <<'EOF' > do_payload2.json
      ${jsonencode(local.do_payload_bigip2)}
      EOF
      
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
           -X POST https://${var.bigip2_mgmt_ip}/mgmt/shared/declarative-onboarding \
           -H "Content-type: application/json" \
           -d @do_payload2.json
    EOT
  }
}

# Push Configuration to BIG-IP 1 SECOND (To initiate trust and build the cluster)
resource "null_resource" "deploy_do_bigip1" {
  depends_on = [null_resource.deploy_do_bigip2]

  provisioner "local-exec" {
    command = <<EOT
      until curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' https://${var.bigip1_mgmt_ip}/mgmt/shared/declarative-onboarding/info | grep "version"; do sleep 15; done
      
      cat <<'EOF' > do_payload1.json
      ${jsonencode(local.do_payload_bigip1)}
      EOF
      
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
           -X POST https://${var.bigip1_mgmt_ip}/mgmt/shared/declarative-onboarding \
           -H "Content-type: application/json" \
           -d @do_payload1.json
    EOT
  }
}
locals {
  cfe_declaration = {
    class       = "Cloud_Failover"
    environment = "aws"
    
    externalStorage = {
      scopingName = aws_s3_bucket.cfe_state_bucket.id
    }

    failoverAddresses = {
      scopingTags = {
        f5_cloud_failover_label = "my-ha-cluster"
      }
    }

    failoverRoutes = {
      scopingTags = {
        f5_cloud_failover_label = "my-ha-cluster"
      }
      defaultNextHopAddresses = {
        discoveryType = "static"
        items = [
          var.bigip_external_self_ips[0],
          var.bigip_external_self_ips[1]
        ]
      }
    }
  }
}

# Push Configuration to BIG-IP 1
resource "null_resource" "deploy_cfe_bigip1" {
  depends_on = [
    aws_instance.bigip,
    null_resource.deploy_do_bigip1,
    null_resource.deploy_do_bigip2
  ]
  triggers = { declaration = jsonencode(local.cfe_declaration) }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      set -e
      
      # Write payload safely using echo to prevent indentation formatting bugs
      echo '${jsonencode(local.cfe_declaration)}' > cfe_payload1.json

      echo "Pushing CFE Declaration to BIG-IP 1..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X POST https://${aws_eip.mgmt_eip[0].public_ip}/mgmt/shared/cloud-failover/declare \
        -H "Content-Type: application/json" -d @cfe_payload1.json

      echo "Verifying CFE Installation on BIG-IP 1..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X GET https://${aws_eip.mgmt_eip[0].public_ip}/mgmt/shared/cloud-failover/declare | grep -q '"class":"Cloud_Failover"'
      
      echo "CFE successfully configured on BIG-IP 1!"
    EOT
  }
}

# Push Configuration to BIG-IP 2
resource "null_resource" "deploy_cfe_bigip2" {
  depends_on = [
    aws_instance.bigip,
    null_resource.deploy_do_bigip1,
    null_resource.deploy_do_bigip2
  ]
  triggers = { declaration = jsonencode(local.cfe_declaration) }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      set -e
      
      # Write payload safely using echo to prevent indentation formatting bugs
      echo '${jsonencode(local.cfe_declaration)}' > cfe_payload2.json

      echo "Pushing CFE Declaration to BIG-IP 2..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X POST https://${aws_eip.mgmt_eip[1].public_ip}/mgmt/shared/cloud-failover/declare \
        -H "Content-Type: application/json" -d @cfe_payload2.json

      echo "Verifying CFE Installation on BIG-IP 2..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X GET https://${aws_eip.mgmt_eip[1].public_ip}/mgmt/shared/cloud-failover/declare | grep -q '"class":"Cloud_Failover"'

      echo "CFE successfully configured on BIG-IP 2!"
    EOT
  }
}
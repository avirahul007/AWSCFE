resource "null_resource" "deploy_cfe_bigip1" {
  depends_on = [
    aws_instance.bigip,
    aws_network_interface_attachment.ext_attach,
    aws_network_interface_attachment.int_attach,
    aws_ec2_tag.route_table_tag,
    aws_vpc_endpoint.ec2,
    aws_vpc_endpoint.s3,
    aws_s3_bucket.cfe_state_bucket,
    null_resource.deploy_do_bigip1,
    null_resource.deploy_do_bigip2
  ]
  triggers = {
    declaration = jsonencode(local.cfe_declaration)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<EOT
      set -e

      cat > cfe_payload1.json <<EOF
      ${jsonencode(local.cfe_declaration)}
      EOF

      echo "Pushing CFE Declaration to BIG-IP 1 via Public IP..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X POST https://${aws_eip.mgmt_eip[0].public_ip}/mgmt/shared/cloud-failover/declare \
        -H "Content-Type: application/json" \
        -d @cfe_payload1.json

      echo "Verifying CFE Declaration on BIG-IP 1 (Per F5 Docs)..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X GET https://${aws_eip.mgmt_eip[0].public_ip}/mgmt/shared/cloud-failover/declare | grep -q '"class":"Cloud_Failover"'
      
      echo "BIG-IP 1 CFE Deployed and Verified!"
    EOT
  }
}

resource "null_resource" "deploy_cfe_bigip2" {
  depends_on = [
    aws_instance.bigip,
    aws_network_interface_attachment.ext_attach,
    aws_network_interface_attachment.int_attach,
    aws_ec2_tag.route_table_tag,
    aws_vpc_endpoint.ec2,
    aws_vpc_endpoint.s3,
    aws_s3_bucket.cfe_state_bucket,
    null_resource.deploy_do_bigip1,
    null_resource.deploy_do_bigip2
  ]
  triggers = {
    declaration = jsonencode(local.cfe_declaration)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<EOT
      set -e

      cat > cfe_payload2.json <<EOF
      ${jsonencode(local.cfe_declaration)}
      EOF

      echo "Pushing CFE Declaration to BIG-IP 2 via Public IP..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X POST https://${aws_eip.mgmt_eip[1].public_ip}/mgmt/shared/cloud-failover/declare \
        -H "Content-Type: application/json" \
        -d @cfe_payload2.json

      echo "Verifying CFE Declaration on BIG-IP 2 (Per F5 Docs)..."
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
        -X GET https://${aws_eip.mgmt_eip[1].public_ip}/mgmt/shared/cloud-failover/declare | grep -q '"class":"Cloud_Failover"'
      
      echo "BIG-IP 2 CFE Deployed and Verified!"
    EOT
  }
}
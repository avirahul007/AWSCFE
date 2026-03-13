# Ensures the AWS endpoints exist before configuring the BIG-IP , thats is the reason I have applied depends upon function before executing this local cfe for both BIGIPs

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
    null_resource.deploy_do_bigip2,
    aws_instance.bigip
  ]
  triggers = {
    declaration = jsonencode(local.cfe_declaration)
  }

  provisioner "local-exec" {
    command = <<EOT
      cat <<'EOF' > cfe_payload1.json
      ${jsonencode(local.cfe_declaration)}
      EOF
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
           -X POST https://${var.bigip1_mgmt_ip}/mgmt/shared/cloud-failover/declare \
           -H "Content-type: application/json" \
           -d @cfe_payload1.json
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
    null_resource.deploy_do_bigip2,
    aws_instance.bigip
  ]
  triggers = {
    declaration = jsonencode(local.cfe_declaration)
  }

  provisioner "local-exec" {
    command = <<EOT
      cat <<'EOF' > cfe_payload2.json
      ${jsonencode(local.cfe_declaration)}
      EOF
      curl -sk -u '${var.bigip_admin_user}:${var.bigip_admin_password}' \
           -X POST https://${var.bigip2_mgmt_ip}/mgmt/shared/cloud-failover/declare \
           -H "Content-type: application/json" \
           -d @cfe_payload2.json
    EOT
  }
}
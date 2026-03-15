# ==========================================
# Install Packages on BIG-IP 1 (Active)
# ==========================================
resource "null_resource" "install_packages_bigip1" {
  depends_on = [aws_instance.bigip1]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for BIG-IP 1 API to become ready..."
      until $(curl -sk -u ${var.bigip_admin_user}:${var.bigip_admin_password} https://${aws_eip.mgmt_eip[0].public_ip}/mgmt/shared/identifiers/config > /dev/null); do
        sleep 20
      done

      echo "Running upload script for BIG-IP 1..."
      # Here is where the variables are passed to $1, $2, $3, $4, $5 in exact order
      bash ./scripts/upload_packages.sh \
        ${aws_eip.mgmt_eip[0].public_ip} \
        ${var.bigip_admin_user} \
        ${var.bigip_admin_password} \
        ${var.do_url} \
        ${var.cfe_url}
    EOT
  }
}

# ==========================================
# Install Packages on BIG-IP 2 (Standby)
# ==========================================
resource "null_resource" "install_packages_bigip2" {
  depends_on = [aws_instance.bigip2]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for BIG-IP 2 API to become ready..."
      until $(curl -sk -u ${var.bigip_admin_user}:${var.bigip_admin_password} https://${aws_eip.mgmt_eip[1].public_ip}/mgmt/shared/identifiers/config > /dev/null); do
        sleep 20
      done

      echo "Running upload script for BIG-IP 2..."
      # Here we pass [1] to ensure the script targets the second BIG-IP's Mgmt EIP
      bash ./scripts/upload_packages.sh \
        ${aws_eip.mgmt_eip[1].public_ip} \
        ${var.bigip_admin_user} \
        ${var.bigip_admin_password} \
        ${var.do_url} \
        ${var.cfe_url}
    EOT
  }
}
# Management Interfaces
resource "aws_network_interface" "mgmt" {
  count             = 2
  subnet_id         = var.mgmt_subnet_ids[count.index]
  source_dest_check = true # Mgmt usually doesn't route user traffic
  
  tags = {
    Name = "bigip-${count.index + 1}-mgmt"
  }
}

# External Interfaces
resource "aws_network_interface" "external" {
  count             = 2
  subnet_id         = var.ext_subnet_ids[count.index]
  source_dest_check = false # Required for Lb/Routing

  tags = {
    Name = "bigip-${count.index + 1}-ext"
  }
}

# Internal Interfaces
resource "aws_network_interface" "internal" {
  count             = 2
  subnet_id         = var.int_subnet_ids[count.index]
  source_dest_check = false # Required for Lb/Routing

  tags = {
    Name = "bigip-${count.index + 1}-int"
  }
}
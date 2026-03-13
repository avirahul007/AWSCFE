variable "aws_region" {
  type    = string
  default = "eu-west-1"         # Assuming , you can mention your own default region where your BIGIP boxes are already installed and running.
}

variable "vpc_id" { 
    type = string 
}

variable "internal_subnet_ids" { 
    type = list(string) 
}

variable "route_table_ids" { 
    type = list(string) 
}

variable "bigip_sg_id" { 
    type = string 
}

variable "cfe_label" {
  type    = string
  default = "cfe-failover-active-standby"
}

variable "bigip1_mgmt_ip" { 
    type = string 
}

variable "bigip2_mgmt_ip" { 
    type = string 
}

variable "bigip_admin_user" { 
    type = string 
}

variable "bigip_admin_password" {
  type      = string
  sensitive = true
}

variable "vip_subnet_ranges" { 
    type = list(string) 
}

variable "bigip_external_self_ips" { 
    type = list(string) 
}
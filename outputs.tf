output "cfe_s3_bucket_name" {
  value = aws_s3_bucket.cfe_state_bucket.bucket
}

output "bigip_iam_instance_profile" {
  value = aws_iam_instance_profile.bigip_profile.name
}

output "ec2_endpoint_dns" {
  value = aws_vpc_endpoint.ec2.dns_entry[0].dns_name
}

output "bigip_mgmt_ips" {
  value       = aws_instance.bigip[*].public_ip # Assuming mgmt has public IPs for access
  description = "Management IPs for the BIG-IPs"
}

output "bigip_instance_ids" {
  value = aws_instance.bigip[*].id
}
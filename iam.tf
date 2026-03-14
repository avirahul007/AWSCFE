# Fetch current AWS Account ID and Region automatically
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM Role
resource "aws_iam_role" "bigip_cfe_role" {
  name = "bigip-cfe-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Strict Least-Privilege IAM Policy (Translated from F5 JSON)
resource "aws_iam_policy" "bigip_cfe_policy" {
  name = "bigip-cfe-strict-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1. S3 List All Buckets (Account Scoped)
      {
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = "*"
        Condition = { StringEquals = { "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id } }
      },
      # 2. S3 Bucket Level Access
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:GetBucketTagging"]
        Resource = aws_s3_bucket.cfe_state_bucket.arn
      },
      # 3. S3 Object Level Access
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.cfe_state_bucket.arn}/*"
      },
      # 4. Deny Unencrypted S3 Uploads
      {
        Sid      = "DenyPublishingUnencryptedResources"
        Effect   = "Deny"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.cfe_state_bucket.arn}/*"
        Condition = { Null = { "s3:x-amz-server-side-encryption" = true } }
      },
      # 5. EC2 Describe Actions (Region and Account Scoped)
      {
        Effect   = "Allow"
        Action   = [
          "ec2:DescribeAddresses", "ec2:DescribeInstances", "ec2:DescribeInstanceStatus",
          "ec2:DescribeNetworkInterfaces", "ec2:DescribeNetworkInterfaceAttribute",
          "ec2:DescribeSubnets", "ec2:DescribeRouteTables"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion"  = data.aws_region.current.name,
            "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      # 6. EC2 IP Association (Strictly targeted to YOUR Instances, ENIs, and EIPs)
      {
        Effect   = "Allow"
        Action   = [
          "ec2:AssociateAddress", "ec2:DisassociateAddress",
          "ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = concat(
          formatlist("arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:elastic-ip/%s", aws_eip.mgmt_eip[*].id),
          formatlist("arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:network-interface/%s", aws_network_interface.external[*].id),
          formatlist("arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/%s", aws_instance.bigip[*].id)
        )
      },
      # 7. EC2 Routing (Strictly targeted to YOUR Route Tables)
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateRoute", "ec2:ReplaceRoute"]
        Resource = formatlist("arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:route-table/%s", var.route_table_ids)
      }
    ]
  })
}

# Attach IAM policy to Role 
resource "aws_iam_role_policy_attachment" "cfe_attach" {
  role       = aws_iam_role.bigip_cfe_role.name
  policy_arn = aws_iam_policy.bigip_cfe_policy.arn
}

# Create Instance Profile
resource "aws_iam_instance_profile" "bigip_profile" {
  name = "bigip-cfe-profile"
  role = aws_iam_role.bigip_cfe_role.name
}
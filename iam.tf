data "aws_region" "current" {}
# IAM Role & Policy for BIG-IPs

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

### Create IAM Policy with controlled permission

resource "aws_iam_policy" "bigip_cfe_policy" {
  name = "bigip-cfe-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ec2:DescribeInstances", "ec2:DescribeInstanceStatus", "ec2:DescribeAddresses",
          "ec2:AssociateAddress", "ec2:DisassociateAddress", "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeNetworkInterfaceAttribute", "ec2:DescribeRouteTables", "ec2:ReplaceRoute",
          "ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketTagging"]
        Resource = aws_s3_bucket.cfe_state_bucket.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.cfe_state_bucket.arn}/*"
      }
    ]
  })
}

## Attach IAM policy to Role 

resource "aws_iam_role_policy_attachment" "cfe_attach" {
  role       = aws_iam_role.bigip_cfe_role.name
  policy_arn = aws_iam_policy.bigip_cfe_policy.arn
}


resource "aws_iam_instance_profile" "bigip_profile" {
  name = "bigip-cfe-profile"
  role = aws_iam_role.bigip_cfe_role.name
}
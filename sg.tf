data "aws_region" "current" {}
# Update existing Security Group for EC2 Endpoint

### Very Important: Sir, if you have created SG using your TF code so ensure this below rule is added to your existing code from where SG was created and applied to BIGIPs, 
##otherwise it will delete this existing rule and configure only this rule

resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "vpc-endpoint-sg"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.bigip_sg_id]
  }
}
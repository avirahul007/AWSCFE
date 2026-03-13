# F5 BIG-IP Cloud Failover Extension (CFE) with AWS Private Endpoints

This repository contains the Terraform code needed to deploy a highly available (Active/Standby) F5 BIG-IP pair in AWS. It configures the **F5 Cloud Failover Extension (CFE)** to operate entirely over AWS private network infrastructure without requiring Elastic IPs (EIPs), NAT Gateways, or internet access.

**Reference & Credit:** The architecture and logic for this deployment are heavily inspired by the F5 DevCentral article:  
[Using VPC Endpoints with Cloud Failover Extension](https://community.f5.com/kb/technicalarticles/using-vpc-endpoints-with-cloud-failover-extension/278619).

---

## 🎯 What This Does

When an F5 BIG-IP fails over in the cloud, it can't rely on traditional networking protocols like Gratuitous ARP. Instead, it must make API calls to AWS to move secondary IP addresses and update routing tables. 

Typically, this requires internet access to reach the AWS APIs. This Terraform project builds a secure, private path for those API calls by creating:
* An **S3 Gateway Endpoint** (to privately store F5 state files).
* An **EC2 Interface Endpoint with Private DNS** (to privately manipulate AWS IPs and routes).
* The necessary **IAM Roles and Policies** to give the F5 permission to make these changes.
* A `local-exec` script that securely pushes the JSON configuration payload directly to the REST APIs of your BIG-IPs.

---

## ✅ Prerequisites

Before running this code, make sure you have the following ready:
1. **Terraform Installed:** Ensure you have Terraform v1.3.0 or higher.
2. **AWS Credentials:** Your terminal must be authenticated with AWS (e.g., via `aws configure` or exported environment variables).
3. **BIG-IPs Deployed:** You should already have two BIG-IPs deployed in your target VPC.
4. **CFE Installed:** The F5 Cloud Failover Extension (CFE) RPM package must be installed on both BIG-IP instances.
5. **Network Access:** The machine where you run this Terraform code must have HTTPS network access to the Management IPs of both BIG-IP instances.

---

## 🚀 Step-by-Step Action Plan

### Step 1: Prepare Your Variables
Open the `terraform.tfvars` file and update the dummy values with your actual AWS environment details (VPC ID, Subnets, Route Tables) and F5 details (Management IPs, Admin credentials, VIP subnets).

### Step 2: Initialize Terraform
Download the required AWS and Null providers by running:
```bash
terraform init

Step 3: Review the Deployment Plan
Check what Terraform is about to build. It should show the creation of VPC Endpoints, an S3 bucket, IAM roles, route table tags, and the API push tasks.

'''Bash
terraform plan

Step 4: Apply the Configuration
Deploy the infrastructure and push the configuration to the BIG-IPs.

'''Bash
terraform apply
(Type yes when prompted).

Step 5: Attach the IAM Profile
Note: If your BIG-IPs were already running before executing this code, you must manually attach the newly created IAM instance profile (bigip-cfe-profile) to your BIG-IP EC2 instances.

Go to the AWS Console > EC2.

Select your BIG-IP instance.

Click Actions > Security > Modify IAM Role.

Select bigip-cfe-profile and apply.

🔍 How to Verify It Works
Once the deployment is complete, you should test the failover manually:

SSH into your Active BIG-IP instance.

Watch the CFE logs in real-time by running:

Bash
tail -f /var/log/restnoded/restnoded.log
Log into the BIG-IP Configuration Utility (GUI) in your browser.

Navigate to Device Management > Devices, click on your active device, and click Force to Standby.

Watch the SSH terminal logs. You should see CFE recognize the state change and successfully update the AWS Route Tables and secondary IP addresses using the private endpoints.
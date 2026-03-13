Here is the comprehensive, updated `README.md` file. It breaks down the architecture, the specific benefits of the private endpoint design, the required prerequisites, and a detailed step-by-step deployment guide.

You can copy and paste this directly into your repository's `README.md` file.

---

```markdown
# F5 BIG-IP Cloud Failover Extension (CFE) with AWS Private Endpoints

This repository contains the Terraform infrastructure-as-code (IaC) required to deploy a highly available (Active/Standby) F5 BIG-IP pair in AWS. 

This deployment is specifically designed to configure the **F5 Cloud Failover Extension (CFE)** to operate entirely over **AWS private network infrastructure**, eliminating the need for NAT Gateways or public internet routing for failover API calls.

---

## 🏗 Architecture & Flow

In a traditional on-premises environment, an F5 BIG-IP failover relies on Layer 2 networking protocols like Gratuitous ARP (GARP) to move traffic to the standby device. In the public cloud, GARP is not supported. 

Instead, F5 utilizes the **Cloud Failover Extension (CFE)**. When a failover occurs, the newly Active BIG-IP makes programmatic API calls to the cloud provider (AWS) to remap IP addresses and update routing tables.

### The Failover Flow:
1. **Detection:** The Standby BIG-IP detects that the Active BIG-IP is down (via standard F5 HA heartbeat mechanisms).
2. **Promotion:** The Standby BIG-IP promotes itself to the Active state.
3. **API Execution:** The CFE service on the new Active BIG-IP triggers a payload of API calls to AWS.
4. **State Retrieval:** CFE reads the current infrastructure state from the **S3 Gateway Endpoint**.
5. **Network Re-mapping:** CFE sends commands to the **EC2 Interface Endpoint** to:
   * Move the secondary Virtual IPs (VIPs) from the dead instance's External ENI to the new Active instance's External ENI.
   * Update the target of the AWS Route Tables to point the Next-Hop routing to the new Active instance.
6. **Traffic Restoration:** AWS routes external and internal traffic to the new Active BIG-IP.

---

## 🌟 The Benefit of AWS Private Endpoints

By default, the CFE requires internet access to reach the public `ec2.amazonaws.com` and `s3.amazonaws.com` API endpoints to execute a failover. 

This architecture deploys an **S3 Gateway Endpoint** and an **EC2 Interface Endpoint** with Private DNS enabled. 

**Key Benefits of this approach:**
* **Enhanced Security:** Failover API calls never traverse the public internet. They stay strictly within the AWS backbone.
* **Cost Efficiency:** Eliminates the need to run costly NAT Gateways just to allow the BIG-IPs to talk to AWS APIs.
* **Increased Reliability:** Removes the Internet Gateway (IGW) and NAT Gateway as potential points of failure during a critical failover event.
* **Compliance:** Meets strict enterprise regulatory requirements that mandate isolated, air-gapped network architectures.

---

## ✅ Prerequisites

Before running this Terraform configuration, you must have the following information and infrastructure ready in your AWS environment:

### 1. Network Requirements
* **VPC ID:** The ID of the Virtual Private Cloud where the BIG-IPs will reside (`vpc-0xxxxxx`).
* **Subnet IDs:** You need two subnets (one for each Availability Zone) for each of the following tiers:
  * **Management Subnets:** (`subnet-mgmt1`, `subnet-mgmt2`). *Note: These must be public subnets with an IGW route if you intend to access the BIG-IP GUI over the internet via Elastic IPs.*
  * **External Subnets:** (`subnet-ext1`, `subnet-ext2`).
  * **Internal Subnets:** (`subnet-int1`, `subnet-int2`).
* **Route Tables:** The IDs of the private AWS Route Tables that handle your backend application traffic. CFE will tag these and manipulate them during a failover (`rtb-0xxxxxx`).

### 2. Compute & Licensing
* **F5 AMI ID:** The specific AWS Machine Image ID for the BIG-IP version you wish to deploy (e.g., `ami-0abcdef1234567890`).
* **SSH Key Pair:** An existing AWS EC2 Key Pair to access the BIG-IP via SSH (`my-aws-key`).
* **License Keys:** Two valid F5 Base Registration Keys (one for each BIG-IP).

### 3. Tooling
* **Terraform:** Version `>= 1.3.0` installed locally or on your CI/CD runner.
* **AWS CLI:** Authenticated with an IAM user/role that has permissions to create VPC Endpoints, EC2 instances, IAM Roles, ENIs, and S3 buckets.

---

## 🚀 Step-by-Step Usage Guide

### Step 1: Clone the Repository
```bash
git clone <your-repository-url>
cd awscfe

```

### Step 2: Configure Remote State (Recommended)

To prevent local state file loss and enable team collaboration, update `providers.tf` to include your S3 remote backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "f5-cfe/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}

```

### Step 3: Populate Variables

Create a `terraform.tfvars` file in the root directory and populate it with your environment's prerequisites. *(Refer to the `variables.tf` file for the required schema).*

Ensure you set a strong password for the BIG-IP GUI. You can do this securely via your terminal environment variables to avoid hardcoding it in the repo:

```bash
export TF_VAR_bigip_admin_password="YourSecurePassword123!"

```

### Step 4: Initialize Terraform

Download the required providers and initialize the backend:

```bash
terraform init

```

### Step 5: Plan the Deployment

Review the resources Terraform is about to create. Ensure the Security Groups, ENIs, and Route Table tags map correctly to your VPC:

```bash
terraform plan

```

### Step 6: Apply the Configuration

Deploy the infrastructure. This step takes several minutes as it provisions the EC2 instances, waits for the F5 MCPD service to start, sets the admin password, licenses the boxes, installs the CFE RPM package, and securely pushes the CFE JSON payload via the REST API.

```bash
terraform apply

```

*(Type `yes` when prompted).*

---

## 🔍 Accessing the BIG-IP & Verifying Failover

### Accessing the Instances

Once the deployment finishes, Terraform will output the Elastic IPs (if configured) or the public/private IPs of your Management interfaces.

* **GUI Access:** Open `https://<Management-IP>` in your browser. Log in using the username `admin` and the password you passed via `TF_VAR_bigip_admin_password`.
* **SSH Access:** `ssh -i /path/to/your/key.pem admin@<Management-IP>`

### Testing the Cloud Failover Extension

1. Log into the Configuration Utility (GUI) of your **Active** BIG-IP.
2. Open an SSH session to the same Active BIG-IP and tail the CFE log file to watch the API calls in real-time:
```bash
tail -f /var/log/restnoded/restnoded.log

```


3. In the GUI, navigate to **Device Management > Devices**.
4. Click on the local device (labeled with `(Self)`) at the bottom of the screen.
5. Click the **Force to Standby** button.
6. **Watch the logs and the AWS Console.** You will see the CFE service detect the state change and push the routing and IP updates to the AWS EC2 Interface Endpoint. Within seconds, your AWS Route Tables will update to point to the new Active BIG-IP.

---

## 📜 License

This project is licensed under the GNU General Public License v3.0. See the `LICENSE` file for details.

```

```
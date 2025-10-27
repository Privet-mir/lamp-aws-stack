# LAMP Stack on AWS using Terraform

This project implements a LAMP (Linux, Apache, MySQL, PHP) stack on AWS using Terraform as a proof-of-concept (PoC) for a technical assessment. The solution prioritizes automation, security, and reliability.

## ✅ Requirements Fulfilled
- [✅] Infrastructure as Code with Terraform
- [✅] Amazon Linux 2 EC2 with SSM
- [✅] Apache with ALB and health checks
- [✅] RDS MySQL in private subnet
- [✅] PHP 8.3 with RDS MySQL integration
- [✅] Security (security groups, IAM, encryption)
- [✅] Testing and monitoring
- [✅] Documentation
- [✅] CI/CD via GitHub Actions

## Architecture Overview

The infrastructure includes a VPC with public and private subnet, an EC2 instance, an Application Load Balancer, an RDS MySQL instance, and security controls. See [Detailed Architecture Decision Record](docs/ADR.md) for specifics.

### App Workflow
1. When a change is pushed to the GitHub repository, the GitHub Actions pipeline automatically runs the Terraform workflow to plan and deploy infrastructure resources on AWS.
2. After the EC2 instance is created, the user_data.sh script runs on first boot to install Apache and PHP, configure the LAMP stack, and create the required HTML and PHP files under /var/www/html.
3. The RDS database password is securely stored in AWS Secrets Manager and fetched at runtime by the user_data.sh script, which injects it into the sample_app.php file for database connectivity.
4. The Application Load Balancer (ALB) in the public subnet routes external traffic to the EC2 instance over its private IP.
5. Accessing the ALB DNS name (e.g., http://lamp-stack-alb-xxxx.elb.amazonaws.com) displays the default homepage.
6. Clicking the “Fugro Application” link on the homepage opens sample_app.php, which queries the RDS MySQL database and displays a message retrieved from it.
7. The /health.php endpoint provides a JSON response and is used for ALB health checks.

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** (version >= 1.0)
3. **AWS Account** with necessary permissions
4. **JQ** for parsing json

## 📁 Project Structure

```
fugro-assesment/
├── .github/
│   └── workflows/
│       └── terraform.yml           # GitHub Actions workflow
├── policy/
│   └── opa/
│       └── terraform.rego          # OPA policy to block deletes
├── docs/
│   ├── ADR.md                      # Architecture Decision Record
│   ├── PROJECT_SUMMARY.md          # Project summary
│   └── lamp-arch1.png              # Architecture diagram
├── main.tf                         # Main Terraform configuration
├── variables.tf                    # Variable definitions
├── data.tf                         # Data sources (AMI, AZs, caller)
├── outputs.tf                      # Output definitions
├── backend.tf                      # S3 backend configuration
├── provider.tf                     # Providers and versions
├── vpc.tf                          # VPC, subnets, endpoints
├── rds.tf                          # RDS MySQL, subnet/parameter groups
├── monitoring.tf                   # CloudWatch logs/alarms and IAM
├── user_data.sh                    # EC2 user data script
├── deploy.sh                       # Automated deployment script
├── terraform.tfvars.example        # Example variables file
├── terraform.tfvars                # Environment variables (local use)
├── iam-terraform.json              # Least-privilege IAM policy for CI/user
├── .gitignore                      # Git ignore file
└── README.md                       # This documentation
```

## AWS Setup and Configuration

### Step 1: Create IAM User for Terraform

1. **Log into AWS Console** and navigate to IAM service
2. **Create a new IAM user**:
   - Go to IAM → Users → Create user
   - Username: `terraform-user` (or your preferred name)
   - Access type: **Programmatic access** (check this box)
   - Click "Next: Permissions"

### Step 2: Attach IAM Policies

### Required AWS Permissions Summary
Your AWS credentials need permissions for:
- **EC2**: instances, security groups, VPC, subnet, key pairs, AMIs
- **RDS**: database instances, subnet groups, parameter groups
- **ELB**: load balancers, target groups, listeners
- **IAM**: roles, policies, instance profiles
- **VPC**: VPC, subnet, route tables, internet gateways, NAT gateways
- **Systems Manager**: SSM agent, parameter store
- **Secrets Manager**: secrets, secret versions
- **CloudWatch**: metrics, alarms, dashboards, log groups

 Create and attach the IAM policy:
 - Open `iam-terraform.json` in this repository.
 - In AWS Console → IAM → Policies → Create policy → JSON, paste the contents of `iam-terraform.json`, then create the policy (e.g., name it `TerraformAccessPolicy`).
 - Attach this policy to your `terraform-user`.

### Step 3: Create Access Keys

1. **After creating the user**, go to the user's page
2. **Click on "Security credentials" tab**
3. **Click "Create access key"**
4. **Select "Application running outside AWS"**
5. **Download the CSV file** containing:
   - Access Key ID
   - Secret Access Key

⚠️ **Important**: Store these credentials securely and never commit them to version control.

### Step 4: Configure AWS CLI

```bash
aws configure
```
Enter the following when prompted:
- AWS Access Key ID: `[Your Access Key ID]`
- AWS Secret Access Key: `[Your Secret Access Key]`
- Default region name: `eu-central-1` (or your preferred region)
- Default output format: `json`

### Step 5: Terraform AWS Provider Configuration

Terraform will automatically use your AWS CLI configuration. No additional provider configuration is needed in your Terraform files.

## Quick Start

Quick deployment (recommended):

```bash
cd fugro-assesment
./deploy.sh
```

Manual steps:

1. **Clone and navigate to the project directory:**
   ```bash
   cd fugro-assesment
   ```

2. **Copy and customize variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your preferred values
   ```

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Plan the deployment:**
   ```bash
   terraform plan
   ```

5. **Deploy the infrastructure:**
   ```bash
   terraform apply
   ```

6. **Access your application:**
   - The output will show the Load Balancer DNS name
   - Open `http://<load-balancer-dns>` in your browser

## Configuration

### Variables

Key variables you can customize in `terraform.tfvars`:

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region for deployment | `eu-central-1` |
| `project_name` | Project name for resource naming | `lamp-stack` |
| `instance_type` | EC2 instance type | `t3.micro` |
| `db_instance_class` | RDS instance class | `db.t3.micro` |

### Security Considerations

Security is enforced via network isolation, least-privilege IAM roles, encryption, SSM, and automated backups. Full details in Detailed Architecture Decision Record.

## Application Features

The deployed application includes:

1. **Homepage** (`/`): Welcome page with system status
2. **Application** (`/sample_app.php`): Prints message from rds.
3. **Health Check** (`/health.php`): JSON health status endpoint
4. **Testing** Verified via web access and /health.php health checks.

## Resources Created
The Terraform configuration creates the following AWS resources:
- 1 VPC (via terraform-aws-modules/vpc/aws)
- 1 Internet Gateway (via VPC module)
- 1 NAT Gateway (via VPC module)
- 1 Public Subnet (eu-central-1a, via VPC module)
- 1 Private Subnet (eu-central-1a, via VPC module)
- 1 Route Tables (public and private, via VPC module)
- 4 Security Groups (VPC endpoints, ALB, web server, and database)
- 1 DB Subnet Group
- 1 RDS MySQL Instance
- 1 Application Load Balancer
- 1 Target Group
- 1 EC2 Instance
- 4 VPC Endpoints (SSM, SSM Messages, EC2 Messages, CloudWatch Logs)
- 1 IAM Role (with SSM, SSM EC2, Cloudwatch, Secret manager and RDS policies)
- 1 IAM Instance Profile

## Cleanup

To remove all resources and avoid charges:

```bash
terraform destroy
```

## CI/CD: GitHub Actions Access Keys Setup

To allow the GitHub Actions workflow (`.github/workflows/terraform.yml`) to deploy with Terraform using AWS access keys:

1. **Create an AWS IAM user (if not already created):**
   - Follow the steps in "AWS Setup and Configuration" above to create a programmatic-access IAM user.
   - Attach the required permissions (see the provided policy in this README or tailor least-privilege).

2. **Generate access keys:**
   - In IAM → Users → Your user → Security credentials → Create access key.
   - Copy the Access Key ID and Secret Access Key.

3. **Add GitHub Actions secrets in your repository:**
   - Go to GitHub → Your repository → Settings → Secrets and variables → Actions → New repository secret.
   - Add the following secrets:
     - `AWS_ACCESS_KEY_ID` → your Access Key ID
     - `AWS_SECRET_ACCESS_KEY` → your Secret Access Key
     - `AWS_REGION` → region matching your Terraform `var.aws_region` (e.g., `eu-central-1`)

The workflow uses these secrets to authenticate with AWS and sets `TF_VAR_aws_region` from `AWS_REGION` so Terraform uses the same region.

# AWS Infrastructure with Terraform

> A production-ready, beginner-friendly Terraform project for deploying and destroying secure AWS infrastructure — with full GitHub Actions automation.

---

## What This Project Does

This project lets your team deploy professional AWS infrastructure by changing a few configuration values and clicking a button in GitHub. No deep Terraform knowledge required to **use** it, though this guide will teach you how it works so you can customize it.

**What gets deployed:**
- A secure Virtual Private Cloud (VPC) — your private network inside AWS
- Public and private subnets across multiple Availability Zones
- A Windows Server EC2 instance with .NET, Power BI Desktop, and SQL Server pre-installed
- AWS GuardDuty (threat detection), CloudTrail (audit logs), Security Hub (compliance dashboard)
- SSM Session Manager — connect to your server **without** opening RDP ports or managing SSH keys
- CloudWatch monitoring with CPU, memory, and disk alarms
- KMS encryption for all data at rest

---

## Prerequisites — What You Need Before Starting

### 1. AWS Account & Local Credentials

- An AWS account with administrator access
- AWS CLI installed on your computer → [Install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

You need local AWS credentials for the one-time [backend setup](#step-1-backend-setup) below (GitHub Actions uses its own OIDC login later, so this is separate — see [GitHub Actions Setup](#github-actions-setup)).

**Get an access key:**
1. AWS Console → **IAM** → **Users** → your user (create one if needed)
2. **Security credentials** tab → **Create access key** → choose "Command Line Interface (CLI)"
3. Copy the **Access Key ID** and **Secret Access Key** — you won't be able to see the secret again

> Don't use your AWS **root account** credentials. Use an IAM user instead (an admin-group user is fine for learning/personal accounts).

**Connect the CLI to your account:**
```bash
aws configure
```
It will ask for your Access Key ID, Secret Access Key, default region (e.g. `eu-west-1`), and output format (`json` is fine).

**Verify it worked:**
```bash
aws sts get-caller-identity
```
This should print your Account ID, User ID, and ARN with no errors.

**If you see `Error: No valid credential sources found` (or an EC2 IMDS timeout)** when running `terraform apply` — it means `aws configure` hasn't been run yet, or was run with empty/invalid values. Run `aws configure list` to check what's currently set, then re-run `aws configure`.

### 2. Terraform
- Install Terraform → [terraform.io/downloads](https://developer.hashicorp.com/terraform/downloads)
- Verify: open a terminal and run `terraform --version`

### 3. GitHub Repository
- This project needs to live in a GitHub repository
- You need admin access to configure GitHub Secrets and GitHub Actions

### 4. An S3 Bucket for Terraform State
- Terraform saves its "memory" (what it has deployed) in an S3 bucket
- **CRITICAL:** This must be set up before anything else — see [Step 1: Backend Setup](#step-1-backend-setup)

---

## Project Structure Explained

```
Terraform For AWS/
│
├── README.md                     ← You are here
├── DEVOPS_LEARNING_PATH.md       ← Your personal DevOps learning roadmap
│
├── backend-setup/                ← STEP 1: Run this ONCE to create state storage
│   └── main.tf
│
├── modules/                      ← Reusable building blocks (like LEGO pieces)
│   ├── vpc/                      ← Networking: VPC, subnets, routing, flow logs
│   ├── security/                 ← GuardDuty, CloudTrail, Security Hub, KMS, Config
│   ├── ec2-windows/              ← Windows Server EC2 with software pre-installed
│   └── monitoring/               ← CloudWatch dashboards, alarms, SNS alerts
│
├── environments/
│   └── windows-workstation/      ← STEP 2: Your actual deployment
│       ├── main.tf               ← Wires all modules together
│       ├── variables.tf          ← What you can change
│       ├── terraform.tfvars      ← Your actual values (create from .example)
│       ├── outputs.tf            ← Values printed after deployment
│       └── backend.tf            ← Where to store Terraform state
│
└── .github/
    └── workflows/
        ├── terraform-plan.yml    ← Auto-runs on Pull Requests (shows what WILL change)
        ├── terraform-apply.yml   ← Auto-runs on merge to main (DEPLOYS)
        └── terraform-destroy.yml ← Manual trigger (TEARS DOWN everything)
```

---

## Step 1: Backend Setup (Do This Once)

Terraform needs a place to store its "state" — a record of everything it has deployed. We use AWS S3 for this.

```bash
# Navigate to the backend setup folder
cd backend-setup

# Initialize Terraform
terraform init

# Preview what will be created
terraform plan

# Create the S3 bucket and DynamoDB table
terraform apply
```

After this runs, note the output values — you will need them in the next step.

---

## Step 2: Configure Your Deployment

```bash
# Navigate to your environment
cd environments/windows-workstation

# Copy the example config file
copy terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values (project name, region, email for alerts, etc.)
notepad terraform.tfvars
```

Edit `backend.tf` to point to the S3 bucket created in Step 1.

---

## Step 3: Deploy via GitHub Actions (Recommended)

See [GitHub Actions Setup](#github-actions-setup) below.

## Step 3 (Alternative): Deploy Locally

```bash
cd environments/windows-workstation

# Download required providers
terraform init

# Preview the deployment (safe — makes no changes)
terraform plan

# Deploy everything
terraform apply

# When done — DESTROY everything to stop AWS charges
terraform destroy
```

---

## GitHub Actions Setup

GitHub Actions automates your deployments so your team never needs to run Terraform locally.

### How It Works

| Trigger | Action |
|---------|--------|
| Open a Pull Request | Terraform shows a **plan** — what WILL change |
| Merge PR to `main` | Terraform **applies** — deploys the changes |
| Click "Run workflow" → destroy | Terraform **destroys** everything |

### Security: OIDC Authentication (No Long-Lived Keys)

We use OpenID Connect (OIDC) so GitHub can talk to AWS **without** storing AWS access keys. This is the modern, secure approach.

#### Set Up OIDC in AWS

Run this once in your AWS account (replace values with yours):

```bash
# Create the OIDC provider for GitHub
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Then create an IAM role that GitHub Actions can assume — see `.github/workflows/README.md` for the full IAM policy.

#### GitHub Repository Secrets

Go to your GitHub repo → Settings → Secrets and variables → Actions, and add:

| Secret Name | Value |
|-------------|-------|
| `AWS_ROLE_ARN` | The ARN of the IAM role you created for GitHub Actions |
| `AWS_REGION` | Your AWS region, e.g. `eu-west-1` |
| `TF_STATE_BUCKET` | The S3 bucket name from Step 1 |
| `TF_STATE_LOCK_TABLE` | The DynamoDB table name from Step 1 |
| `ALERT_EMAIL` | Email address to receive CloudWatch alerts |

---

## Connecting to Your Windows Server

We use **AWS Systems Manager (SSM) Session Manager** — no RDP port open, no key pairs to manage.

1. Open AWS Console → Systems Manager → Session Manager
2. Click **Start Session**
3. Select your EC2 instance
4. Click **Start Session** — you get a browser-based terminal

For a full Windows RDP session through SSM:
```bash
# Using AWS CLI
aws ssm start-session \
  --target <instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters "portNumber=3389,localPortNumber=13389"
```
Then connect RDP to `localhost:13389`.

---

## Cost Estimates

> **Important:** Always destroy resources when not in use. AWS charges by the hour.

| Resource | Estimated Cost |
|----------|---------------|
| EC2 t3.xlarge (Windows) | ~$0.20/hour |
| NAT Gateway | ~$0.05/hour + data transfer |
| GuardDuty | ~$1-4/month (first 30 days free) |
| CloudWatch | ~$1-5/month |
| S3 (state) | < $1/month |
| **Total (running)** | **~$6-8/day** |
| **Total (destroyed)** | **~$1-2/month** (state storage only) |

---

## Security Architecture

```
Internet
    │
    ▼
[Internet Gateway]
    │
[Public Subnet]          ← NAT Gateway lives here
    │
[NAT Gateway]            ← Private resources use this to reach internet
    │
[Private Subnet]         ← EC2 Instance lives here (not directly internet-accessible)
    │
[EC2 Windows Server]     ← Managed via SSM (no open ports needed)
```

**Security controls in place:**
- EC2 in private subnet — no direct internet access
- No RDP (3389) port open to internet — use SSM instead  
- All EBS volumes encrypted with KMS
- GuardDuty monitors for threats 24/7
- CloudTrail logs every API call made in your account
- Security Hub gives you a compliance score
- VPC Flow Logs capture all network traffic metadata
- Default security group set to deny all

---

## Quick Reference Commands

```bash
# See what Terraform will do (never makes changes)
terraform plan

# Deploy / update infrastructure
terraform apply

# Destroy EVERYTHING (stops all AWS charges for these resources)
terraform destroy

# See current state of deployed resources
terraform show

# List all resources Terraform manages
terraform state list

# Format your Terraform files (good practice)
terraform fmt -recursive

# Validate your configuration syntax
terraform validate
```

---

## Troubleshooting

**"Error: No valid credential sources found"**
→ Run `aws configure` and enter your AWS access key, secret key, and region.

**"Error: Backend configuration changed"**
→ Run `terraform init -reconfigure`

**"Instance not showing in SSM"**
→ Wait 5 minutes after deploy. The SSM agent needs time to register.

**GitHub Actions failing with "not authorized"**
→ Check that `AWS_ROLE_ARN` secret is correct and the IAM role trust policy includes your GitHub repo name.

---

## Learning Resources

- [DEVOPS_LEARNING_PATH.md](DEVOPS_LEARNING_PATH.md) — Your personal roadmap
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [AWS Free Tier](https://aws.amazon.com/free/) — Practice without cost
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/) — Best practices

---

*Built with Terraform `~> 1.6` | AWS Provider `~> 5.0`*

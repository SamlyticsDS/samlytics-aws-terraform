# DevOps Learning Path — From This Project to Senior Engineer

> You've started in the right place. This project touches almost every skill a DevOps engineer needs. This guide explains what each part teaches you and what to learn next.

---

## What is DevOps?

DevOps is the practice of **automating the delivery of software** — from writing code to running it in production — reliably, securely, and repeatedly.

A DevOps engineer's job is to:
1. Build infrastructure that developers can use (like this Terraform template)
2. Create pipelines that deploy code automatically (like the GitHub Actions workflows)
3. Monitor systems so problems are caught early (like the CloudWatch alarms)
4. Keep everything secure (like GuardDuty, SSM, KMS)

You're doing all four of these things with this project.

---

## Phase 1: Foundations (You Are Here)

### Skill 1: Terraform & Infrastructure as Code ✅

**What you've learned from this project:**
- What a VPC, subnet, security group, and route table are
- How Terraform modules work (reusable building blocks)
- How `variables.tf`, `main.tf`, and `outputs.tf` relate to each other
- Remote state with S3 and DynamoDB
- The plan → apply → destroy lifecycle

**What to learn next:**

| Topic | Why It Matters |
|-------|----------------|
| `terraform import` | Bring existing AWS resources under Terraform management |
| `terraform workspace` | Manage dev/staging/prod with one codebase |
| Terraform Cloud | Managed remote state + team features |
| `for_each` and `count` | Create variable numbers of resources |
| `locals` and `data` blocks | More advanced HCL patterns |

**Practice exercise:** Add a second private subnet and deploy an RDS SQL Server (managed database) in it. Connect your EC2 to it.

---

### Skill 2: AWS Core Services ✅

**What you've learned:**
- EC2 (virtual machines), EBS (storage), AMIs (OS images)
- VPC, subnets, Internet Gateway, NAT Gateway
- IAM roles and policies (permissions)
- S3 (object storage), KMS (encryption)
- SSM (remote access without keys), CloudWatch (monitoring)

**AWS services to add to your knowledge:**

| Service | What It Does | When You Need It |
|---------|-------------|-----------------|
| RDS | Managed databases (MySQL, PostgreSQL, SQL Server) | Instead of self-managing SQL |
| ECS/EKS | Run containers (Docker/Kubernetes) | Modern app deployment |
| ALB | Load balancer — splits traffic across servers | High availability |
| Route 53 | DNS — maps domain names to IPs | Custom domain names |
| ACM | SSL/TLS certificates | HTTPS for your apps |
| Secrets Manager | Secure secret storage | Better than SSM Parameter Store for app secrets |
| SQS/SNS | Message queues and pub/sub | Decoupled architecture |

**Free learning:** AWS has a full free tier. Create an AWS account, work through [AWS Skill Builder](https://skillbuilder.aws/) courses.

**Certification path:** AWS Certified Solutions Architect – Associate → AWS Certified DevOps Engineer – Professional

---

### Skill 3: GitHub Actions & CI/CD ✅

**What you've learned:**
- What a workflow, job, and step are
- OIDC authentication (more secure than stored keys)
- Plan → Review → Apply → Destroy workflow
- GitHub Secrets for sensitive values
- Conditional steps (`if:`, `needs:`)

**CI/CD concepts to deepen:**

```
Developer writes code
        ↓
Push to feature branch
        ↓
GitHub Actions: Run tests (unit + integration)
        ↓
Open Pull Request
        ↓
GitHub Actions: Terraform plan (shows what changes)
        ↓
Team reviews code AND plan
        ↓
Merge to main
        ↓
GitHub Actions: Terraform apply (deploys to dev)
        ↓
Manual promotion: Deploy to staging → testing → prod
```

**What to add to these workflows:**
- `terraform-lint` or `checkov` (security scanning of Terraform code)
- `tfsec` (Terraform security scanner)
- Notification to Slack or Teams on deploy
- Cost estimation with `infracost`

---

## Phase 2: Intermediate Skills (Next 3-6 Months)

### Skill 4: Docker & Containers

**Why it matters:** Most modern applications run in containers. As a DevOps engineer, you'll build, deploy, and manage container images.

**Start with:**
```bash
# Install Docker Desktop
# Build an image
docker build -t myapp:v1 .

# Run it locally
docker run -p 8080:8080 myapp:v1

# Push to AWS Elastic Container Registry
aws ecr create-repository --repository-name myapp
docker push 123456789.dkr.ecr.eu-west-1.amazonaws.com/myapp:v1
```

**Practice:** Package your .NET application from the EC2 as a Docker image. Deploy it to ECS (AWS managed containers) instead of EC2.

---

### Skill 5: Linux (Even as a Windows DevOps Engineer)

**Why:** Most CI/CD runners, Docker containers, and cloud services run Linux. GitHub Actions runners are Ubuntu by default. The `aws` CLI, `terraform`, `git`, and `docker` commands work the same on Linux and Windows, but most examples online use Linux.

**Core commands to learn:**
```bash
# Navigation
ls -la           # list files with details
cd /path/to/dir  # change directory
pwd              # where am I?

# Files
cat file.txt     # print file contents
grep "error" *.log  # search for text
tail -f app.log  # follow a log file live

# Processes
ps aux           # list running processes
kill 1234        # stop process 1234
top              # live resource monitor

# Networking
curl https://example.com   # make HTTP request
netstat -tulpn   # show listening ports
```

---

### Skill 6: Monitoring & Observability

The three pillars of observability are **Metrics, Logs, and Traces**. This project has the first two.

**What you've built:**
- Metrics: CPU, memory, disk via CloudWatch
- Logs: Windows Event Logs → CloudWatch Logs

**What to add:**
- **Distributed Tracing**: AWS X-Ray (traces requests through your application)
- **Log insights**: CloudWatch Logs Insights for querying logs with SQL-like syntax
- **Alerts → on-call**: PagerDuty or OpsGenie integration with SNS
- **Dashboards**: Grafana (more powerful than CloudWatch dashboards)

**Metric to know for EC2:**
```
# The most important health check pattern:
If CPU > 80% for 10 min → Application may be overloaded
If Memory > 90% → Risk of out-of-memory crash
If Disk > 90% → Application will fail when disk fills
If StatusCheckFailed = 1 → Hardware or OS issue
```

---

### Skill 7: Secrets Management

**Current approach** (in this project): SSM Parameter Store with KMS encryption.

**Better for applications:** AWS Secrets Manager
- Auto-rotates credentials (changes database passwords automatically)
- Applications fetch secrets at runtime (not baked into code or environment variables)
- Audit trail of who accessed which secret

**Never do:**
- Store secrets in code (`.env` files committed to git)
- Store secrets in EC2 user data (visible in AWS console)
- Store secrets in Terraform `.tfvars` files committed to git
- Log secrets to CloudWatch

---

## Phase 3: Advanced Skills (6-12 Months)

### Skill 8: Kubernetes (K8s)

The industry-standard container orchestration platform. Most DevOps job descriptions require it.

**AWS managed Kubernetes:** EKS (Elastic Kubernetes Service)
**Learning path:** Docker → Kubernetes concepts → kubectl CLI → Helm charts → EKS → Terraform for EKS

**Key concepts:**
```yaml
# A Pod runs one or more containers
# A Deployment manages multiple Pods and handles rolling updates
# A Service exposes Pods to network traffic
# A Namespace isolates groups of resources
# An Ingress routes external HTTP traffic to services
```

---

### Skill 9: GitOps

GitOps is the practice of treating your Git repository as the **single source of truth** for infrastructure AND application state.

**Tools:**
- **ArgoCD** — watches a Git repo and syncs Kubernetes cluster to match
- **Flux** — similar to ArgoCD, lightweight
- **Atlantis** — GitOps for Terraform (auto plan/apply on PRs)

**The principle:**
```
You never run kubectl or terraform manually in production.
The only way to change production is to merge a PR.
The Git log IS the audit trail.
```

---

### Skill 10: Security Engineering (Your project's strongest area!)

This project gives you a great security foundation. To go deeper:

**Security concepts to learn:**
- **Zero Trust**: Never trust, always verify — every request is authenticated even inside the network
- **SIEM**: Security Information and Event Management — centralising and correlating security logs (AWS Security Lake, Splunk)
- **WAF**: Web Application Firewall — protect web apps from SQL injection, XSS
- **Penetration Testing**: Understanding attacks makes you better at defence
- **CIS Benchmarks**: Industry-standard security configuration guides

**AWS security certifications:**
- AWS Certified Security – Specialty

---

## Recommended Learning Resources

### Free
| Resource | What You Learn |
|----------|---------------|
| [AWS Skill Builder](https://skillbuilder.aws/) | AWS services with hands-on labs |
| [Terraform Learn](https://developer.hashicorp.com/terraform/tutorials) | Official Terraform tutorials |
| [GitHub Learning Lab](https://github.com/apps/github-learning-lab) | GitHub Actions hands-on |
| [KodeKloud](https://kodekloud.com/) | DevOps tools (some free) |
| [Linux Journey](https://linuxjourney.com/) | Linux fundamentals |

### Paid (Worth It)
| Resource | Best For |
|----------|---------|
| [A Cloud Guru](https://acloudguru.com/) | AWS certification prep |
| [Udemy — Terraform on AWS](https://www.udemy.com/) | Deep Terraform |
| [KodeKloud Pro](https://kodekloud.com/) | Kubernetes, Docker, DevOps tools |

### Books
- *The Phoenix Project* — What DevOps is and why it exists (novel format)
- *The DevOps Handbook* — How to implement DevOps practices
- *Terraform: Up & Running* by Yevgeniy Brikman — The best Terraform book

---

## Your Learning Milestones

Use this project to track your growth:

- [ ] I understand every file in this project and can explain it to someone else
- [ ] I deployed the Windows workstation successfully via Terraform locally
- [ ] I set up GitHub Actions and successfully triggered plan/apply from GitHub
- [ ] I can add a new module (e.g., an S3 bucket module) following the same pattern
- [ ] I passed AWS Certified Cloud Practitioner (foundation)
- [ ] I passed AWS Certified Solutions Architect – Associate
- [ ] I deployed a containerised application to ECS using Terraform
- [ ] I set up a Kubernetes cluster with EKS
- [ ] I passed AWS Certified DevOps Engineer – Professional

---

## The DevOps Engineer Mindset

Technical skills are only part of the job. The best DevOps engineers also:

**Automate ruthlessly** — If you do something manually twice, automate it the third time.

**Fail fast** — Catch errors in CI/CD before they reach production, not after.

**Measure everything** — "It feels slow" is not useful. "p99 latency is 3.2 seconds" is.

**Share knowledge** — Write runbooks, document decisions, write READMEs. Your future self will thank you.

**Think about blast radius** — Before changing anything, ask: "If this goes wrong, what breaks? How do I roll back?"

**Security is everyone's job** — Not just the security team's. Every engineer should think about what could go wrong.

---

*You're building the right things. Keep going.*

# =============================================================================
# TERRAFORM BACKEND — Remote State Configuration
# =============================================================================
# This tells Terraform where to store its state file (its "memory").
#
# IMPORTANT: Fill in the values below with the outputs from backend-setup/
# After running: cd backend-setup && terraform apply
# the outputs will tell you exactly what to put here.
#
# WHY REMOTE STATE?
# If state were stored locally on your computer:
#   - Your teammate couldn't run Terraform (they don't have the state)
#   - If your computer dies, you lose track of what's deployed
#   - Two people running terraform apply at once would corrupt everything
# Remote state in S3 solves all of these problems.
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state-04a6642d"
    key            = "windows-workstation/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "myorg-terraform-locks"
    encrypt        = true  # Encrypt state at rest in S3
  }
}

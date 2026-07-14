# Containerized Application Deployment on ECS

An automated, secure, and production-grade continuous integration and continuous deployment (CI/CD) infrastructure project that deploys a containerized Python Flask application to **AWS ECS Fargate** using **Terraform** and **GitHub Actions**.

---

##  Project Overview & Goals

The core objective of this project is to implement a modern, serverless container lifecycle that completely avoids the overhead of manually managing infrastructure or handling static cloud credentials. 

### Key Design Goals
* **Zero-Server Compute Management:** Utilizes AWS Fargate to run containers serverlessly across isolated Public Subnets without maintaining, patching, or scaling underlying EC2 instances.
* **Secured Passwordless CI/CD:** Utilizes an **IAM OIDC (OpenID Connect) Identity Provider** relationship between GitHub Actions and AWS. This entirely removes the risk of compromised secrets by avoiding the storage of long-lived static IAM Access Keys.
* **Optimized Multi-Stage Assembly:** Builds a minimal, isolated container execution layer that strips out intermediate dependencies, preserving execution speed and ensuring a secure container runtime.
* **Automated Rolling Updates:** Coordinates a hands-off, two-job pipeline sequence (`build-and-push` and `deploy-infrastructure`) that signals AWS ECS to execute a zero-downtime rolling update upon every main-branch push.

---

##  System Architecture

Traffic routes directly through an Internet Gateway into public subnets distributed across Availability Zones (`eu-west-1a` and `eu-west-1b`), hitting container workloads guarded tightly by an application-specific stateful Security Group.

![System Architecture Diagram] (architecture.drawio.png)

---
## AWS Services Used

The architecture layers multiple AWS services together to form a highly resilient, isolated computing partition:Amazon VPC:
    - Establishes a dedicated, secure 10.0.0.0/16 network perimeter spanning separate public availability subnets (eu-west-1a and eu-west-1b) for seamless              structural fallback.
      
    - IAM OIDC Identity Provider & Roles: Manages cryptographic web identity assertions to grant short-lived, permission-bounded deployment privileges to active         GitHub workflows.
      
    - Amazon ECR (Elastic Container Registry): Serves as an immutable repository holding application Docker image layers tagged dynamically by active Git commit         SHAs.
      
    - Amazon ECS (Fargate Launch Type): Automatically schedules, spins up, and scales serverless tasks across the VPC, using container native parameters.
      
    - AWS Security Groups: Acts as a stateful, protective firewall that limits open ingress vectors strictly to the primary application listening port (Port 80)         while permitting unhindered outbound routing.
    
    - Amazon CloudWatch Logs: Captures stdout and stderr diagnostic application records directly from active container tasks into an encapsulated logging group          for centralized auditing.

---

## Step-by-Step Deployment Guide
    
### Prerequisites
  - AWS CLI configured with deployment permissions.
  - Terraform installed locally.
  - An application repository configured on GitHub.

### Step 1: Initialize and Provision Cloud Infrastructure

Navigate to the folder containing the main.tf configuration file to initialize providers and provision the baseline AWS workspace:

---

# Initialize Terraform and download required AWS providers
terraform init

# Validate configuration syntax integrity
terraform validate

# Review the upcoming cloud infrastructure changes
terraform plan

# Apply and construct live AWS cloud infrastructure
terraform apply -auto-approve

---

### Step 2: Connect the GitHub Pipeline via OIDC Roles

1- Review the successful terraform apply output metrics to find the generated GitHub Actions IAM Role Amazon Resource Name (ARN)[cite: 3].
2- Navigate to the GitHub repository dashboard and select Settings > Secrets and variables > Actions.
3- Ensure the pipeline targets the exact configured OIDC execution role ARN securely:
  - AWS_ROLE_TO_ASSUME: arn:aws:iam::146445314795:role/flask-app-github-actions-role-dev
  - AWS_REGION: eu-west-1

### Step 3: Trigger the Automated CI/CD Lifecycle

Commit the multi-stage Dockerfile, the infrastructural main.tf, and the .github/workflows/deploy.yaml pipeline structure to the repository:  

---

git add .
git commit -m "feat: setup automated infrastructure and container scaling"
git push origin main

---

Upon receiving the push event, the GitHub Actions engine triggers a dual-staged job lifecycle:

 1. build-and-push: Authenticates securely via OIDC, constructs a space-optimized multi-stage Docker build, and pushes image layers to Amazon ECR under sequential    :latest and SHA tags.

2. deploy-infrastructure: Signals Amazon ECS to issue a --force-new-deployment rolling command, downloading the absolute freshest code configurations to the          serverless Fargate layer without incurring application downtime.

### Step 4: Verify the Active Live Endpoint

Because this serverless topology deploys application containers straight onto public subnets using automated public IP assignments, utilize this unified AWS CLI command pipeline to extract the live container's public networking endpoint:

---

Because this serverless topology deploys application containers straight onto public subnets using automated public IP assignments, utilize this unified AWS CLI command pipeline to extract the live container's public networking endpoint:

---

Copy the returned public IP configuration directly into an internet web browser:

---

http://<EXTRACTED_PUBLIC_IP>

---

The live, serving Flask application will instantly return the environment validation metadata payload string.

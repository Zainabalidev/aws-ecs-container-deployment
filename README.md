# Containerized Application Deployment on ECS

An automated, secure, and production-grade continuous integration and continuous deployment (CI/CD) infrastructure project that deploys a containerized Python Flask application to **AWS ECS Fargate** using **Terraform** and **GitHub Actions**.

---

## 🚀 Project Overview & Goals

The core objective of this project is to implement a modern, serverless container lifecycle that completely avoids the overhead of manually managing infrastructure or handling static cloud credentials. 

### Key Design Goals
* **Zero-Server Compute Management:** Utilizes AWS Fargate to run containers serverlessly across isolated Public Subnets without maintaining, patching, or scaling underlying EC2 instances.
* **Secured Passwordless CI/CD:** Utilizes an **IAM OIDC (OpenID Connect) Identity Provider** relationship between GitHub Actions and AWS. This entirely removes the risk of compromised secrets by avoiding the storage of long-lived static IAM Access Keys.
* **Optimized Multi-Stage Assembly:** Builds a minimal, isolated container execution layer that strips out intermediate dependencies, preserving execution speed and ensuring a secure container runtime.
* **Automated Rolling Updates:** Coordinates a hands-off, two-job pipeline sequence (`build-and-push` and `deploy-infrastructure`) that signals AWS ECS to execute a zero-downtime rolling update upon every main-branch push.

---

## 🗺️ System Architecture

Traffic routes directly through an Internet Gateway into public subnets distributed across Availability Zones (`eu-west-1a` and `eu-west-1b`), hitting container workloads guarded tightly by an application-specific stateful Security Group.

```mermaid
graph TD
    %% GitHub Actions CI/CD Pipeline
    subgraph GitHub_Repo [GitHub Repository]
        code[Code Push to main] --> workflow[GitHub Actions Workflow]
    end

    subgraph AWS_Cloud [AWS Cloud - eu-west-1]
        %% Authentication
        oidc[IAM OIDC Role Provider] <-->|Secure AssumeRole| workflow
        
        %% Container Registry
        ecr[(Amazon ECR: flask-app-dev)]
        workflow -->|1. Build & Push Image| ecr
        
        %% Networking & Compute
        subgraph VPC [Custom VPC]
            igw[Internet Gateway]
            
            subgraph Public_Subnets [Public Subnets a & b]
                sg[Security Group: flask-app-tasks-sg]
                ecs[AWS ECS Fargate Task]
            end
        end
    end

    %% Deployment Flow
    workflow -->|2. Force New Deployment| ecs
    ecr -->|3. Pulls latest Image| ecs
    igw <-->|4. Direct Public HTTP Traffic| ecs
    sg -.->|Protects Port 80| ecs

    %% Styles
    classDef github fill:#24292e,stroke:#fff,stroke-width:2px,color:#fff;
    classDef aws fill:#ff9900,stroke:#fff,stroke-width:2px,color:#fff;
    class code,workflow github;
    class oidc,ecr,vpc,igw,ecs,sg aws;



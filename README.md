# DevOps EKS

A complete DevOps project that provisions AWS infrastructure using Terraform and deploys a Flask application to EKS using GitHub Actions CI/CD pipelines.

---

## Architecture Overview

```
GitHub Actions
     │
     ├── Infra Pipeline  →  Terraform  →  AWS (VPC, EKS, RDS, ECR)
     │
     └── App Pipeline    →  Docker Build  →  ECR  →  EKS (Flask App)

AWS Infrastructure:
┌─────────────────────────────────────────┐
│  VPC (us-east-1)                        │
│  ├── Private Subnets (EKS nodes, RDS)   │
│  ├── Public Subnets  (NAT Gateway, ELB) │
│  ├── EKS Cluster     (devops-eks)       │
│  │   └── Node Group  (t3.micro x2)      │
│  ├── RDS PostgreSQL  (devops-postgres)  │
│  └── ECR Repository  (devops-app)       │
└─────────────────────────────────────────┘
```

---

## Prerequisites

Make sure you have the following installed locally before starting:

- **AWS CLI** — to interact with AWS from your terminal
- **Terraform** — to provision infrastructure
- **kubectl** — to interact with the EKS cluster
- **Docker** — to build and test container images
- **Git** — to clone and push the repo

---

## Project Structure

```
repo/
├── .github/
│   └── workflows/
│       ├── infra.yml       # Infrastructure deploy pipeline
│       ├── destroy.yml     # Infrastructure destroy pipeline
│       └── app.yml         # App CI/CD pipeline
├── infra/                  # All Terraform files
├── app/                    # Flask application + Dockerfile
└── k8s/                    # Kubernetes manifests
    └── deployment.yaml
    ├── service.yaml
```

---

## Part 1 — AWS One-Time Setup

These steps are done once manually before running any pipeline.

### Step 1 — Create S3 Bucket for Terraform State

Terraform needs a remote backend to store the infrastructure state file. Create an S3 bucket and enable versioning on it so you can recover previous states if needed.

### Step 2 — Create DynamoDB Table for State Locking

This prevents two pipeline runs from modifying infrastructure at the same time. Create a DynamoDB table with `LockID` as the partition key.

### Step 3 — Create OIDC Identity Provider

This allows GitHub Actions to authenticate with AWS without using static access keys. In AWS IAM, add an OpenID Connect provider with:
- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

### Step 4 — Create IAM Role for GitHub Actions

Create an IAM role named `github-actions-terraform-role` using **Web Identity** as the trusted entity. Set the trust policy to only allow your specific GitHub repository to assume the role. Attach the required permissions policy to the role covering S3, DynamoDB, EKS, ECR, RDS, VPC, IAM, KMS, and CloudWatch.

---

## Part 2 — GitHub Setup

### Step 5 — Create GitHub Environments

Go to **repo → Settings → Environments** and create two environments:

- **`dev`** — used as a manual approval gate before deploying the app. Add yourself as a required reviewer.
- **`destroy`** — used as a manual approval gate before destroying infrastructure. Add yourself as a required reviewer.

### Step 6 — Add GitHub Secrets

Go to **repo → Settings → Secrets and variables → Actions** and add the following secrets:

| Secret | Description |
|---|---|
| `AWS_ROLE_ARN` | The ARN of the IAM role created in Step 4 |
| `ECR_REPO` | The full ECR repository URL for your app image |
| `DB_HOST` | The RDS endpoint (available after infra pipeline runs) |
| `DB_NAME` | Your database name |
| `DB_USERNAME` | Your database username |
| `DB_PASSWORD` | Your database password — must not contain `/` `@` `"` or spaces |

---

## Part 3 — Deploy Infrastructure

### Step 7 — Trigger the Infrastructure Pipeline

Push any change to the `infra/` folder on the `main` branch. This triggers the **Deploy Infrastructure** pipeline which runs in three stages:

1. **terraform-plan** — Initialises Terraform, connects to the S3 backend, and generates a plan showing all resources to be created. The plan is uploaded as an artifact.

2. **approve** — Pauses for manual approval. Go to **Actions → the running workflow** and click **Review deployments** to approve.

3. **terraform-apply** — Downloads the saved plan and applies it. This provisions the full AWS infrastructure including VPC, EKS cluster, RDS database, and ECR repository. This step takes 20–30 minutes due to EKS cluster and node group creation.

---

## Part 4 — Connect kubectl Locally

After the infrastructure pipeline completes, connect your local machine to the EKS cluster.

### Step 8 — Configure AWS CLI

Run `aws configure` and enter your AWS Access Key, Secret Key, and region (`us-east-1`).

### Step 9 — Update kubeconfig

Run the following command to add the EKS cluster to your local kubeconfig:

```bash
aws eks update-kubeconfig --name devops-eks --region us-east-1
```

### Step 10 — Grant Your IAM User Cluster Access

EKS has its own access control separate from IAM. Run the following two commands to give your IAM user admin access to the cluster, replacing `YOUR_ACCOUNT_ID` and `YOUR_USERNAME` with your actual values:

```bash
aws eks create-access-entry \
  --cluster-name devops-eks \
  --principal-arn arn:aws:iam::YOUR_ACCOUNT_ID:user/YOUR_USERNAME \
  --region us-east-1

aws eks associate-access-policy \
  --cluster-name devops-eks \
  --principal-arn arn:aws:iam::YOUR_ACCOUNT_ID:user/YOUR_USERNAME \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region us-east-1
```

Verify the connection with:
```bash
kubectl get nodes
```

---

## Part 5 — Deploy the App

### Step 11 — Trigger the App CI/CD Pipeline

Push any change to the `app/` or `k8s/` folder on the `main` branch. This triggers the **App CI/CD** pipeline which runs in four stages:

1. **test** — Installs Python dependencies, runs lint checks (flake8), and executes unit tests using pytest. The pipeline fails if code quality or tests do not pass.

2. **build** — Builds the Docker image from the `app/` folder and pushes it to ECR tagged with the Git commit SHA.

3. **approve** — Pauses for manual approval. Go to **Actions → the running workflow** and click **Review deployments** to approve.

4. **deploy** — Connects to EKS, creates a Kubernetes secret from your GitHub secrets containing the DB credentials, applies the Kubernetes manifests, updates the deployment with the new image tag, and waits for the rollout to complete.

---

## Part 6 — Access the App

### Step 12 — Get the App URL

Run the following to get the LoadBalancer URL:

```bash
kubectl get service devops-app
```

Copy the value under `EXTERNAL-IP` and open it in your browser:

```
http://EXTERNAL-IP
```

> It may take 2–3 minutes after the first deploy for the AWS Load Balancer to fully provision and DNS to propagate.

---

## Part 7 — Destroy Infrastructure

### Step 13 — Trigger the Destroy Pipeline

Go to **GitHub repo → Actions → Destroy Infrastructure → Run workflow**.

Type `destroy-all-resources` in the confirmation field and click **Run workflow**. You will then be prompted for manual approval in the `destroy` environment before anything is deleted.

> ⚠️ This permanently deletes all AWS resources including VPC, EKS, RDS, and ECR. Ensure you no longer need the infrastructure before proceeding.

---

## Useful Commands

```bash
# Check pod status
kubectl get pods -l app=devops-app

# View live app logs
kubectl logs -f deployment/devops-app

# Describe a pod for errors
kubectl describe pod -l app=devops-app

# Check the service and get external URL
kubectl get service devops-app

# View all cluster resources
kubectl get all
```

---

## Common Issues

| Error | Cause | Fix |
|---|---|---|
| `Credentials could not be loaded` | `AWS_ROLE_ARN` secret missing or wrong | Verify the secret exists and matches the IAM role ARN exactly |
| `AccessDenied on S3` | IAM role missing S3 permissions or bucket policy blocking access | Add bucket policy allowing the IAM role |
| `Invalid password` on RDS | Password contains forbidden characters | Remove `/` `@` `"` and spaces from `DB_PASSWORD` |
| `AMI not supported` | EKS version is end-of-life | Update `cluster_version` to `1.32` in `eks.tf` |
| `Could not resolve host` on kubectl | EKS endpoint is private only | Set `cluster_endpoint_public_access = true` in `eks.tf` |
| `You must be logged in` on kubectl | IAM user not added to EKS access entries | Run the commands in Step 10 |
| `deployment not found` | K8s manifest not yet applied | Pipeline applies it automatically on first run |
| `Empty reply from server` | Wrong `targetPort` in service | Match `targetPort` to your app's actual listening port |
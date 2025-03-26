# FastAPI CI/CD Pipeline with AWS Fargate

This project sets up a fully automated CI/CD pipeline for deploying a **FastAPI** application using **AWS ECS Fargate**, **Docker**, **Amazon ECR**, and **GitHub-integrated CodePipeline**. All infrastructure is defined with modular **AWS CloudFormation** templates, including setup for **ECS clusters**, **IAM roles**, **CodeBuild projects**, **S3 artifact buckets**, and an **Application Load Balancer (ALB)**. A **Makefile** drives the deployment process end-to-end, eliminating manual setup and ensuring full reproducibility. Each commit to the `main` branch triggers a secure pipeline that builds and pushes the Docker image to **ECR**, updates the **ECS service**, and routes traffic through the **ALB**, enabling scalable, containerized API deployment with zero-touch operations.

## Demo:

<p align="left">
  <a href="https://youtu.be/GpLlE_EuBwc">
    <img src="https://img.youtube.com/vi/GpLlE_EuBwc/hqdefault.jpg" alt="Watch demo on YouTube" width="200">
  </a>
</p>

---

## Project Overview

- FastAPI app deployed to ECS Fargate via CodePipeline
- Infrastructure managed using CloudFormation + Makefile
- Local + CloudShell compatible
- Secure forecast API with token-based login (`/token` + `/forecast`)
- Future-ready frontend options: Jinja2 or Streamlit

---

## Working Model: Local → GitHub → CloudShell → Deploy

### Step 1: Develop Locally
- Clone the repo to your local machine
- Edit static variables in the Makefile (e.g., AWSSECRETS, PROJECT_NAME, etc.)
    > Located at the top of the `Makefile`, these variables define your project-specific naming and structure

### Step 2: Push to GitHub

```bash
git add Makefile
git commit -m "Update static deployment variables"
git push origin main
```
### Step 3.1: Setup cloudshell 

```bash
# Clone this repo (CI/CD setup) in cloudshell
git clone https://github.com/YOUR_USERNAME/aws_github_fastapi_pipeline.git
cd aws_github_fastapi_pipeline
```
> Update repo name as needed

### Step 3.2: Load secret name from the Makefile or create manually in AWS

```bash
export AWSSECRETS=$(grep '^AWSSECRETS' Makefile | cut -d '=' -f2 | xargs)
```

### Step 3.3: Create the secret (edit values inline before hitting enter) or create manually in AWS

```bash
aws secretsmanager create-secret \
  --name "$AWSSECRETS" \
  --description "CI/CD secret config for FastAPI pipeline" \
  --secret-string '{
    "Token": "ghp_xxxxxxxxxxxxxxxxxxxxxxxx",
    "GitHubOwner": "your-github-username-or-org",
    "GitHubRepo2": "your-repo-name",
    "AuthType": "PERSONAL_ACCESS_TOKEN",
    "ServerType": "GitHub",
    "DOCKERTOKEN": "your-dockerhub-token",
    "DOCKERUSERNAME": "your-dockerhub-username",
    "AWS_ACCOUNT_ID": "123456789012",
    "AWS_REGION": "us-east-1"
  }'
```
### Step 4: After creating your secret, you can deploy the full CI/CD stack using:

```bash
make setup-all
```
### This command will:

- Verify your AWS credentials
- Create the artifact S3 bucket
- Create IAM roles
- Deploy the setup resources (ECR, ECS Cluster, CodeBuild)
- Build and push the Docker image
- Deploy the CodePipeline and ECS service

> if you encounter any issues you will need to review the logs and delete service and redploy using the individual make commands

---

## Additional Commands



### Runtime Management
| Command                | Description                                          |
|------------------------|------------------------------------------------------|
| `make pause-services`  | Scale down the FastAPI ECS service to 0             |
| `make resume-services` | Scale the service back up to 1                      |
| `make get-endpoint`    | Get the public Load Balancer DNS for the deployed API |
| `make curl-endpoint`   | Test the root endpoint (`/`) using `curl`           |

### Full Cleanup
| Command                | Description                                              |
|------------------------|----------------------------------------------------------|
| `make cleanup`         | Run **all** cleanup steps: ALB → Pipeline → Setup → IAM → Bucket |
| `make cleanup-alb`     | Delete the load balancer, listeners, and target group    |
| `make cleanup-pipeline`| Delete the CodePipeline CloudFormation stack             |
| `make cleanup-setup`   | Delete the setup stack and ECR repository                |
| `make cleanup-iam`     | Delete the IAM stack used by the pipeline                |
| `make cleanup-bucket`  | Empty and delete the artifact S3 bucket                  |

### Local Development Commands
| Command              | Description                                              |
|----------------------|----------------------------------------------------------|
| `make run-api`       | Start the FastAPI app on port `8000`                     |
| `make run-streamlit` | Start the Streamlit frontend on port `8501`              |
| `make run`           | Print instructions to run both apps in parallel terminals|
| `make kill`          | Kill processes on ports `8000` and `8501` (FastAPI & Streamlit) |

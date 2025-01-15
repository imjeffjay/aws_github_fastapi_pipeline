# ====================
# Variables
# ====================
TEMPLATE_DIR = cloudformation
PIPELINE_TEMPLATE = $(TEMPLATE_DIR)/pipeline-template.yaml
STACK_NAME = FastAPIPipelineStack
AWS_REGION = us-east-1
SAMPLE_PIPELINE_PROJECT_ENV = sample_pipeline_project_env

# Dynamic inputs
AWS_ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
GITHUB_OAUTH_TOKEN = $(shell aws secretsmanager get-secret-value --secret-id $(SAMPLE_PIPELINE_PROJECT_ENV) --query SecretString --output text | jq -r '.GITHUB_OAUTH_TOKEN')
GITHUB_OWNER = imjeffjay
GITHUB_REPO = sample_ML_AWS_pipeline
TASK_FAMILY = fastapi-task
CONTAINER_NAME = fastapi-container
PROJECT_NAME = FastAPIBuildProject
ECR_REPO_NAME = fastapi-app
IMAGE_TAG = latest
CONFIG_DIR = configs
IMAGEDef_FILE = $(CONFIG_DIR)/imagedefinitions.json

# Fetch default VPC ID
VPC_ID = $(shell aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text)

# Dynamically fetch subnet IDs from the default VPC
SUBNET_IDS = $(shell aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(VPC_ID)" --query "Subnets[*].SubnetId" --output text | tr '\t' ',')

# ====================
# Debugging Subnets
# ====================
debug-config:
	@echo "VPC_ID: $(VPC_ID)"
	@echo "SUBNET_IDS: $(SUBNET_IDS)"

# ====================
# Deploy CloudFormation Stack
# ====================
deploy-cloudformation:
	@echo "Deploying CloudFormation stack..."
	aws cloudformation deploy \
		--template-file $(PIPELINE_TEMPLATE) \
		--stack-name $(STACK_NAME) \
		--parameter-overrides \
			GitHubOAuthToken=$(GITHUB_OAUTH_TOKEN) \
			GitHubOwner=$(GITHUB_OWNER) \
			GitHubRepo=$(GITHUB_REPO) \
			AWSRegion=$(AWS_REGION) \
			RepositoryName=$(ECR_REPO_NAME) \
			ClusterName=FastAPICluster \
			TaskFamily=$(TASK_FAMILY) \
			ContainerName=$(CONTAINER_NAME) \
			SubnetIds=$(SUBNET_IDS) \
			ProjectName=$(PROJECT_NAME) \
		--capabilities CAPABILITY_NAMED_IAM
	@echo "CloudFormation stack deployed successfully!"

# ====================
# Generate Image Definitions
# ====================

generate-imagedefinitions:
	@echo "Generating imagedefinitions.json..."
	@echo '[{"name": "fastapi-container", "imageUri": "$(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME):$(IMAGE_TAG)"}]' > $(IMAGEDef_FILE)
	@echo "imagedefinitions.json generated successfully!"
	@cat $(IMAGEDef_FILE)

# ====================
# Debugging Targets
# ====================
debug-secrets:
	@echo "Secrets:"
	@echo "  GITHUB_OAUTH_TOKEN: $(GITHUB_OAUTH_TOKEN)"

debug-config:
	@echo "Configuration:"
	@echo "  AWS_ACCOUNT_ID: $(AWS_ACCOUNT_ID)"
	@echo "  GITHUB_OWNER: $(GITHUB_OWNER)"
	@echo "  GITHUB_REPO: $(GITHUB_REPO)"
	@echo "  TASK_FAMILY: $(TASK_FAMILY)"
	@echo "  CONTAINER_NAME: $(CONTAINER_NAME)"
	@echo "  SUBNET_IDS: $(SUBNET_IDS)"
	@echo "  PROJECT_NAME: $(PROJECT_NAME)"
	@echo "  ECR_REPO_NAME: $(ECR_REPO_NAME)"
	@echo "  AWS_REGION: $(AWS_REGION)"

# ====================
# Help Command
# ====================
help:
	@echo "Available commands:"
	@echo "  make deploy-cloudformation  - Deploy CloudFormation stack"
	@echo "  make generate-imagedefinitions - Generate imagedefinitions.json"
	@echo "  make debug-secrets           - Print secrets from Secrets Manager"
	@echo "  make debug-config            - Print current configuration variables"

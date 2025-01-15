# ====================
# Static Variables
# ====================
TEMPLATE_DIR = cloudformation
PIPELINE_TEMPLATE = $(TEMPLATE_DIR)/pipeline-template.yaml
STACK_NAME = FastAPIPipelineStack
AWS_REGION = us-east-1
SAMPLE_PIPELINE_PROJECT_ENV = sample_pipeline_project_env
GITHUB_OWNER = imjeffjay
GITHUB_REPO = sample_ML_AWS_pipeline
TASK_FAMILY = fastapi-task
CONTAINER_NAME = fastapi-container
PROJECT_NAME = FastAPIBuildProject
ECR_REPO_NAME = fastapi-app
IMAGE_TAG = latest
CONFIG_DIR = configs
IMAGEDef_FILE = $(CONFIG_DIR)/imagedefinitions.json

# ====================
# Dynamic Variables
# ====================
AWS_ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
GITHUB_OAUTH_TOKEN = $(shell aws secretsmanager get-secret-value --secret-id $(SAMPLE_PIPELINE_PROJECT_ENV) --query SecretString --output text | jq -r '.GITHUB_OAUTH_TOKEN')
DOCKER_IMAGE = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME):$(IMAGE_TAG)

# Fetch default VPC ID
VPC_ID = $(shell aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text)

# Dynamically fetch subnet IDs from the default VPC
SUBNET_IDS = $(shell aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(VPC_ID)" --query "Subnets[*].SubnetId" --output text | tr '\t' ',')

# ====================
# Debugging Commands
# ====================

debug-config:
	@echo "AWS_ACCOUNT_ID: $(AWS_ACCOUNT_ID)"
	@echo "GITHUB_OAUTH_TOKEN: $(GITHUB_OAUTH_TOKEN)"
	@echo "DOCKER_IMAGE: $(DOCKER_IMAGE)"
	@echo "VPC_ID: $(VPC_ID)"
	@echo "SUBNET_IDS: $(SUBNET_IDS)"

# ====================
# Generate Image Definitions
# ====================

generate-imagedefinitions:
	@echo "Generating imagedefinitions.json..."
	@echo '[{"name": "$(CONTAINER_NAME)", "imageUri": "$(DOCKER_IMAGE)"}]' > $(IMAGEDef_FILE)
	@echo "imagedefinitions.json generated successfully!"
	@cat $(IMAGEDef_FILE)

# ====================
# Docker Commands
# ====================

docker-build:
	@echo "Building Docker image..."
	docker build -t $(ECR_REPO_NAME) .

docker-tag:
	@echo "Tagging Docker image..."
	docker tag $(ECR_REPO_NAME):$(IMAGE_TAG) $(DOCKER_IMAGE)

docker-login:
	@echo "Logging into ECR..."
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

docker-push:
	@echo "Pushing Docker image to ECR..."
	docker push $(DOCKER_IMAGE)

docker-deploy: docker-build docker-tag docker-login docker-push
	@echo "Docker image pushed successfully!"

# ====================
# Deployment Commands
# ====================

deploy-cloudformation: docker-deploy generate-imagedefinitions
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

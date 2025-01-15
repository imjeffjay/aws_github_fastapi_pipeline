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
DUMMY_IMAGE = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME):dummy

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
	@echo "DUMMY_IMAGE: $(DUMMY_IMAGE)"
	@echo "VPC_ID: $(VPC_ID)"
	@echo "SUBNET_IDS: $(SUBNET_IDS)"

# ====================
# Workflow
# ====================

# Deploy ECS and ECR infrastructure
deploy-ecr-ecs:
	@echo "Deploying ECS and ECR infrastructure..."
	aws cloudformation deploy \
		--template-file $(PIPELINE_TEMPLATE) \
		--stack-name $(STACK_NAME) \
		--parameter-overrides \
			RepositoryName=$(ECR_REPO_NAME) \
			AWSRegion=$(AWS_REGION) \
			TaskFamily=$(TASK_FAMILY) \
			ClusterName=FastAPICluster \
			SubnetIds=$(SUBNET_IDS) \
			GitHubOwner=$(GITHUB_OWNER) \
			GitHubOAuthToken=$(GITHUB_OAUTH_TOKEN) \
			GitHubRepo=$(GITHUB_REPO) \
		--capabilities CAPABILITY_NAMED_IAM

# Build IAM Role
build-iam-role:
	@echo "Building IAM roles for CodePipeline..."
	# Add specific commands for IAM role creation if required.

# Push Dummy Docker Image
push-dummy-image:
	@echo "Building and pushing a dummy Docker image..."
	docker build -t $(ECR_REPO_NAME) .
	docker tag $(ECR_REPO_NAME):dummy $(DUMMY_IMAGE)
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	docker push $(DUMMY_IMAGE)

# Generate imagedefinitions.json
generate-imagedefinitions:
	@echo "Generating imagedefinitions.json with dummy image..."
	@echo '[{"name": "$(CONTAINER_NAME)", "imageUri": "$(DUMMY_IMAGE)"}]' > $(IMAGEDef_FILE)
	@cat $(IMAGEDef_FILE)

# Deploy CodePipeline
deploy-pipeline:
	@echo "Deploying CodePipeline..."
	aws cloudformation deploy \
		--template-file $(PIPELINE_TEMPLATE) \
		--stack-name $(STACK_NAME) \
		--parameter-overrides \
			GitHubOAuthToken=$(GITHUB_OAUTH_TOKEN) \
			GitHubOwner=$(GITHUB_OWNER) \
			GitHubRepo=$(GITHUB_REPO) \
			AWSRegion=$(AWS_REGION) \
			RepositoryName=$(ECR_REPO_NAME) \
			ImageTag=$(IMAGE_TAG) \
			ProjectName=$(PROJECT_NAME) \
		--capabilities CAPABILITY_NAMED_IAM

# ====================
# Combined Workflow
# ====================

setup-all: deploy-ecr-ecs build-iam-role push-dummy-image generate-imagedefinitions deploy-pipeline
	@echo "Setup complete!"

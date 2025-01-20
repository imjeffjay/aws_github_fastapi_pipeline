# ====================
# Static Variables
# ====================
TEMPLATE_DIR = cloudformation
PIPELINE_TEMPLATE = $(TEMPLATE_DIR)/pipeline-template.yaml
IAM_TEMPLATE = $(TEMPLATE_DIR)/iam-template.yaml
STACK_NAME = FastAPIPipelineStack
AWS_REGION = us-east-1
AWSSECRETS = awspipeline #aws secrets name
TASK_FAMILY = fastapi-task
CONTAINER_NAME = fastapi-container
IAM_STACK_NAME = FastAPI-IAMStack
PROJECT_NAME = FastAPIBuildProject
ECR_REPO_NAME = fastapi-app
IMAGE_TAG = latest
CONFIG_DIR = configs
IMAGEDef_FILE = $(CONFIG_DIR)/imagedefinitions.json
CLUSTER_NAME = FastAPICluster # Define the cluster name here

# ====================
# Dynamic Variables
# ====================
GITHUB_OAUTH_TOKEN = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.GitHubOAuthToken')
GITHUB_OWNER = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.GitHubOwner')
GITHUB_REPO = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.GitHubRepo')
IAM_ROLE = $(shell aws cloudformation describe-stack-resources \
	--stack-name $(IAM_STACK_NAME) \
	--logical-resource-id CodePipelineRole \
	--query "StackResources[0].PhysicalResourceId" \
	--output text)

AWS_ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
DOCKER_IMAGE = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO_NAME):$(IMAGE_TAG)

# Fetch default VPC ID
VPC_ID = $(shell aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text)

# Dynamically fetch subnet IDs from the default VPC
SUBNET_IDS = $(shell aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(VPC_ID)" --query "Subnets[*].SubnetId" --output text | tr '\t' ',')

# ====================
# Debugging Commands
# ====================

validate-setup:
	@echo "Validating setup variables..."
	@echo "GITHUB_OWNER: $(GITHUB_OWNER)"
	@echo "GITHUB_REPO: $(GITHUB_REPO)"
	@echo "AWS_ACCOUNT_ID: $(AWS_ACCOUNT_ID)"
	@echo "DOCKER_IMAGE: $(DOCKER_IMAGE)"
	@echo "Validation completed!"

check-resources:
	@echo "Checking required AWS resources..."
	aws ecr describe-repositories --repository-names $(ECR_REPO_NAME) || echo "ECR repository $(ECR_REPO_NAME) does not exist."
	aws iam get-role --role-name CodeBuildServiceRole || echo "IAM role CodeBuildServiceRole does not exist."
	@echo "Resources check completed."

debug-config:
	@echo "AWS_ACCOUNT_ID: $(AWS_ACCOUNT_ID)"
	@echo "GITHUB_OAUTH_TOKEN: $(GITHUB_OAUTH_TOKEN)"
	@echo "DOCKER_IMAGE: $(DOCKER_IMAGE)"
	@echo "VPC_ID: $(VPC_ID)"
	@echo "SUBNET_IDS: $(SUBNET_IDS)"

validate-template:
	@echo "Validating CloudFormation template..."
	aws cloudformation validate-template --template-body file://$(PIPELINE_TEMPLATE) || exit 1
	@echo "Template validation successful!"


run-local:
	@echo "Running FastAPI locally..."
	uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# ====================
# Workflow
# ====================

# create the ECR repository
build-ecr:
	@echo "Creating ECR repository: $(ECR_REPO_NAME)..."
	aws ecr create-repository --repository-name $(ECR_REPO_NAME) || echo "ECR repository $(ECR_REPO_NAME) already exists."

# Authenticate Docker with ECR
auth-ecr:
	@echo "Authenticating Docker with ECR..."
	aws ecr get-login-password --region $(AWS_REGION) | \
	docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

# Build IAM Role
build-iam-role:
	@echo "Deploying IAM roles for CodePipeline and CodeBuild..."
	aws cloudformation deploy \
		--template-file $(IAM_TEMPLATE) \
		--stack-name $(IAM_STACK_NAME) \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameter-overrides \
			AWSSECRETS=$(AWSSECRETS) \
			GitHubOAuthToken=$(GITHUB_OAUTH_TOKEN) \
			GitHubOwner=$(GITHUB_OWNER) \
			GitHubRepo=$(GITHUB_REPO) \
			AWSRegion=$(AWS_REGION) \
			RepositoryName=$(ECR_REPO_NAME) \
			ClusterName=$(CLUSTER_NAME) \
			TaskFamily=$(TASK_FAMILY) \
			ContainerName=$(CONTAINER_NAME) \
			SubnetIds=$(SUBNET_IDS) \
			ProjectName=$(PROJECT_NAME)

create-codebuild-project:
	@echo "Creating CodeBuild project: $(PROJECT_NAME)..."
	aws codebuild create-project \
		--name $(PROJECT_NAME) \
		--source type=GITHUB,location=https://github.com/$(GITHUB_OWNER)/$(GITHUB_REPO).git \
		--artifacts type=NO_ARTIFACTS \
		--environment type=LINUX_CONTAINER,image=aws/codebuild/standard:5.0,computeType=BUILD_GENERAL1_SMALL,privilegedMode=true,environmentVariables=[
			{name=AWS_REGION,value=$(AWS_REGION),type=PLAINTEXT},
			{name=AWS_ACCOUNT_ID,value=$(AWS_ACCOUNT_ID),type=PLAINTEXT},
			{name=ECR_REPO_NAME,value=$(ECR_REPO_NAME),type=PLAINTEXT},
			{name=GITHUB_OAUTH_TOKEN,value=$(GITHUB_OAUTH_TOKEN),type=PLAINTEXT},
			{name=GITHUB_OWNER,value=$(GITHUB_OWNER),type=PLAINTEXT},
			{name=GITHUB_REPO,value=$(GITHUB_REPO),type=PLAINTEXT}
		] \
		--service-role $(IAM_ROLE)
	@echo "CodeBuild project created successfully!"

# Trigger CodeBuild to build and push Docker image
build-push-image:
	@echo "Triggering CodeBuild to build and push Docker image..."
	aws codebuild start-build \
		--project-name $(PROJECT_NAME) \
		--environment-variables-override \
			name=AWS_REGION,value=$(AWS_REGION),type=PLAINTEXT \
			name=AWS_ACCOUNT_ID,value=$(AWS_ACCOUNT_ID),type=PLAINTEXT \
			name=ECR_REPO_NAME,value=$(ECR_REPO_NAME),type=PLAINTEXT
			name=GITHUB_OAUTH_TOKEN,value=$(GITHUB_OAUTH_TOKEN),type=PLAINTEXT \
			name=GITHUB_OWNER,value=$(GITHUB_OWNER),type=PLAINTEXT \
			name=GITHUB_REPO,value=$(GITHUB_REPO),type=PLAINTEXT

# Deploy ECS Resources (Cluster, Task Definition, Service):
deploy-ecs:
	@echo "Deploying ECS-specific resources..."
	aws cloudformation deploy \
		--template-file $(PIPELINE_TEMPLATE) \
		--stack-name $(STACK_NAME) \
		--parameter-overrides \
			ClusterName=$(CLUSTER_NAME) \
			TaskFamily=$(TASK_FAMILY) \
			SubnetIds=$(SUBNET_IDS) \
			RepositoryName=$(ECR_REPO_NAME) \
		--capabilities CAPABILITY_NAMED_IAM

# Generate imagedefinitions.json
generate-imagedefinitions:
	@echo "Generating imagedefinitions.json for $(CONTAINER_NAME)..."
	@echo '[{"name": "$(CONTAINER_NAME)", "imageUri": "$(DOCKER_IMAGE)"}]' > $(IMAGEDef_FILE)
	@cat $(IMAGEDef_FILE)


# Deploy CodePipeline
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
			ClusterName=$(CLUSTER_NAME) \
			TaskFamily=$(TASK_FAMILY) \
			ContainerName=$(CONTAINER_NAME) \
			SubnetIds=$(SUBNET_IDS) \
			ProjectName=$(PROJECT_NAME) \
		--capabilities CAPABILITY_NAMED_IAM

# ====================
# Combined Workflow
# ====================

# All-in-One Deployment
deploy-all: check-resources build-iam-role build-ecr create-codebuild-project build-push-image deploy-cloudformation deploy-ecs
	@echo "All services successfully deployed!"


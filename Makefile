# ====================
# Static Variables
# ====================
TEMPLATE_DIR = cloudformation
PIPELINE_TEMPLATE = $(TEMPLATE_DIR)/pipeline-template.yaml
STACK_NAME = FastAPIPipelineStack
AWS_REGION = us-east-1
SAMPLE_PIPELINE_PROJECT_ENV = sample_pipeline_project_env
TASK_FAMILY = fastapi-task
CONTAINER_NAME = fastapi-container
PROJECT_NAME = FastAPIBuildProject
ECR_REPO_NAME = fastapi-app
IMAGE_TAG = latest
CONFIG_DIR = configs
IMAGEDef_FILE = $(CONFIG_DIR)/imagedefinitions.json
CLUSTER_NAME = FastAPICluster # Define the cluster name here

# ====================
# Dynamic Variables
# ====================
GITHUB_OAUTH_TOKEN = $(shell aws secretsmanager get-secret-value --secret-id $(SAMPLE_PIPELINE_PROJECT_ENV) --query SecretString --output text | jq -r '.GitHubOAuthToken')
GITHUB_OWNER = $(shell aws secretsmanager get-secret-value --secret-id $(SAMPLE_PIPELINE_PROJECT_ENV) --query SecretString --output text | jq -r '.GitHubOwner')
GITHUB_REPO = $(shell aws secretsmanager get-secret-value --secret-id $(SAMPLE_PIPELINE_PROJECT_ENV) --query SecretString --output text | jq -r '.GitHubRepo')

AWS_ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
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
	@echo "DUMMY_IMAGE: $(DUMMY_IMAGE)"
	@echo "VPC_ID: $(VPC_ID)"
	@echo "SUBNET_IDS: $(SUBNET_IDS)"

validate-template:
	@echo "Validating CloudFormation template..."
	aws cloudformation validate-template --template-body file://$(PIPELINE_TEMPLATE) || exit 1
	@echo "Template validation successful!"

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



# Push Docker Image
build-push-image:
	@echo "Building Docker image for $(ECR_REPO_NAME)..."
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	docker build -t $(ECR_REPO_NAME):latest .
	docker tag $(ECR_REPO_NAME):latest $(DOCKER_IMAGE)
	docker push $(DOCKER_IMAGE)



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

# Build IAM Role
build-iam-role:
	@echo "Building IAM roles for CodePipeline..."
	# Add specific commands for IAM role creation if required.


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
deploy-all: build-ecr build-push-image deploy-ecs generate-imagedefinitions deploy-cloudformation
	@echo "All services successfully deployed!"

# ====================
# Static Variables
# ====================
TEMPLATE_DIR = cloudformation
PIPELINE_TEMPLATE = $(TEMPLATE_DIR)/pipeline-template.yaml
IAM_TEMPLATE = $(TEMPLATE_DIR)/iam-template.yaml
STACK_NAME = FastAPIPipelineStack
AWS_REGION = us-east-1
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

AWSSECRETS = $(shell aws secretsmanager list-secrets --query "SecretList[?Name=='awspipeline'].Name" --output text)
AWSSECRETS2 = $(shell aws secretsmanager list-secrets --query "SecretList[?Name=='codebuild'].Name" --output text)
SECRET_ARN1 = $(shell aws secretsmanager list-secrets --query "SecretList[?Name=='awspipeline'].ARN" --output text)
SECRET_ARN2 = $(shell aws secretsmanager list-secrets --query "SecretList[?Name=='codebuild'].ARN" --output text)

GITHUB_TOKEN = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.Token')
GITHUB_OWNER = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.GitHubOwner')
GITHUB_REPO = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.GitHubRepo')
AUTH_TYPE = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.AuthType')
SERVER = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.Server')
	
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



# ====================
# Workflow
# ====================

# create the ECR repository
build-ecr:
	@echo "Creating ECR repository: $(ECR_REPO_NAME)..."
	aws ecr create-repository --repository-name $(ECR_REPO_NAME) || echo "ECR repository $(ECR_REPO_NAME) already exists."
	@echo "Repo created successfully!"

# Authenticate Docker with ECR
auth-ecr:
	@echo "Authenticating Docker with ECR..."
	aws ecr get-login-password --region $(AWS_REGION) | \
	docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

# Build IAM Role
build-iam-role:
	@echo "Deploying IAM roles..."
	aws cloudformation deploy \
		--template-file $(IAM_TEMPLATE) \
		--stack-name $(IAM_STACK_NAME) \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameter-overrides \
			SecretArn1=$(SECRET_ARN1) \
			SecretArn2=$(SECRET_ARN2)
	@echo "IAM roles deployed successfully!"

create-codebuild-project:
	@echo "Creating CodeBuild project: $(PROJECT_NAME)..."
	aws codebuild create-project \
		--name $(PROJECT_NAME) \
		--source "{\"type\":\"GITHUB\",\"location\":\"https://github.com/$(GITHUB_OWNER)/$(GITHUB_REPO).git\"}" \
		--artifacts type=NO_ARTIFACTS \
		--service-role $(IAM_ROLE) \
		--environment "{\"type\":\"LINUX_CONTAINER\",\"image\":\"aws/codebuild/standard:5.0\",\"computeType\":\"BUILD_GENERAL1_SMALL\",\"privilegedMode\":true,\"environmentVariables\":[ \
			{\"name\":\"AWS_REGION\",\"value\":\"$(AWS_REGION)\",\"type\":\"PLAINTEXT\"}, \
			{\"name\":\"ECR_REPO_NAME\",\"value\":\"$(ECR_REPO_NAME)\",\"type\":\"PLAINTEXT\"}, \
			{\"name\":\"AWS_ACCOUNT_ID\",\"value\":\"$(AWS_ACCOUNT_ID)\",\"type\":\"PLAINTEXT\"}, \
			{\"name\":\"AWSSECRETS\",\"value\":\"$(AWSSECRETS)\",\"type\":\"PLAINTEXT\"}, \
			{\"name\":\"AWSSECRETS2\",\"value\":\"$(AWSSECRETS2)\",\"type\":\"PLAINTEXT\"} \
		]}"
	@echo "CodeBuild project created successfully!"

# Trigger CodeBuild to build and push Docker image
build-push-image:
	@echo "Triggering CodeBuild to build and push Docker image..."
	aws codebuild start-build \
		--project-name $(PROJECT_NAME) \
		--environment-variables-override \
			"name=AWS_REGION,value=$(AWS_REGION),type=PLAINTEXT" \
			"name=AWS_ACCOUNT_ID,value=$(AWS_ACCOUNT_ID),type=PLAINTEXT" \
			"name=ECR_REPO_NAME,value=$(ECR_REPO_NAME),type=PLAINTEXT" \
			"name=GITHUB_TOKEN,value=$(GITHUB_TOKEN),type=PLAINTEXT" \
			"name=GITHUB_OWNER,value=$(GITHUB_OWNER),type=PLAINTEXT" \
			"name=GITHUB_REPO,value=$(GITHUB_REPO),type=PLAINTEXT" \
			"name=AUTH_TYPE,value=$(AUTH_TYPE),type=PLAINTEXT" \
			"name=SERVER,value=$(SERVER),type=PLAINTEXT"
	@echo "Build process triggered successfully!"

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
deploy-all: build-iam-role build-ecr create-codebuild-project build-push-image
	@echo "All services successfully deployed!"


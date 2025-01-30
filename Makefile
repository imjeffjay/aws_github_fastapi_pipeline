# ====================
# Static Variables
# ====================
TEMPLATE_DIR = cloudformation

IAM_TEMPLATE = $(TEMPLATE_DIR)/iam-template.yaml
SETUP_TEMPLATE = $(TEMPLATE_DIR)/setup-resources.yaml
PIPELINE_TEMPLATE = $(TEMPLATE_DIR)/pipeline-template.yaml

CONFIG_DIR = configs
IMAGEDef_FILE = $(CONFIG_DIR)/imagedefinitions.json
IMAGE_TAG = latest

PROJECT_PREFIX = fastapi2
STACK_NAME = $(PROJECT_PREFIX)-stack
TASK_FAMILY = $(PROJECT_PREFIX)-task
CONTAINER_NAME = $(PROJECT_PREFIX)-container
IAM_STACK_NAME = $(PROJECT_PREFIX)-IAMStack
PROJECT_NAME = $(PROJECT_PREFIX)-project
ECR_REPO_NAME = $(PROJECT_PREFIX)-app
CLUSTER_NAME = $(PROJECT_PREFIX)-cluster
ARTIFACT_BUCKET_NAME = $(AWS_ACCOUNT_ID)-codepipeline-artifacts-$(AWS_REGION)

# ====================
# Dynamic Variables
# ====================

AWSSECRETS = $(shell aws secretsmanager list-secrets --query "SecretList[?Name=='awspipeline'].Name" --output text)
SECRET_ARN = $(shell aws secretsmanager list-secrets --query "SecretList[?Name=='awspipeline'].ARN" --output text)
GITHUB_TOKEN = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.Token')
GITHUB_OWNER = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.GitHubOwner')
GITHUB_REPO = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.GitHubRepo2')
AUTH_TYPE = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.AuthType')
SERVER = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.Server')
DOCKERTOKEN = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.DOCKERTOKEN')
DOCKERUSERNAME = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.DOCKERUSERNAME')
AWS_ACCOUNT_ID = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.AWS_ACCOUNT_ID')
AWS_REGION = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.AWS_REGION')

IAM_ROLE = $(shell aws cloudformation describe-stack-resources \
	--stack-name $(IAM_STACK_NAME) \
	--logical-resource-id CodePipelineRole \
	--query "StackResources[0].PhysicalResourceId" \
	--output text)

IAM_ROLE_NAME = $(shell aws cloudformation describe-stack-resources \
	--stack-name $(IAM_STACK_NAME) \
	--logical-resource-id CodePipelineRole \
	--query "StackResources[0].PhysicalResourceId" \
	--output text)

IAM_ROLE_ARN = $(shell aws iam get-role \
	--role-name $(IAM_ROLE_NAME) \
	--query "Role.Arn" --output text)

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

### Step 1 - Run once per project  ###
# Build IAM Role
build-iam-role:
	@echo "Deploying IAM roles..."
	aws cloudformation deploy \
		--template-file $(IAM_TEMPLATE) \
		--stack-name $(IAM_STACK_NAME) \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameter-overrides \
			SecretArn=$(SECRET_ARN)
	@echo "IAM roles deployed successfully!"

### Step 2 - Run once per project  ###
# Deploy One-Time Setup Resources
deploy-setup-resources:
	@echo "Deploying one-time setup resources (ECR, ArtifactBucket, ECS Cluster, CodeBuild Project)..."
	aws cloudformation deploy \
		--template-file $(SETUP_TEMPLATE) \
		--stack-name $(STACK_NAME) \
		--parameter-overrides \
			ProjectName=$(PROJECT_NAME) \
			ECRRepoName=$(ECR_REPO_NAME) \
			ClusterName=$(CLUSTER_NAME) \
			ArtifactBucketName=$(ARTIFACT_BUCKET_NAME) \
			CodePipelineRoleArn=$(IAM_ROLE_ARN) \
			GitHubRepo=$(GITHUB_REPO) \
			GitHubOwner=$(GITHUB_OWNER) \
			GitHubOAuthToken=$(GITHUB_TOKEN) \
			AWSRegion=$(AWS_REGION) \
			AWSAccountId=$(AWS_ACCOUNT_ID) \
			DOCKERUSERNAME=$(DOCKERUSERNAME) \
			DOCKERTOKEN=$(DOCKERTOKEN) \
			SecretArn=$(SECRET_ARN) \
		--capabilities CAPABILITY_NAMED_IAM

### Step 3 - Run once per project  ###
deploy-pipeline:
	@echo "Deploying CloudFormation stack..."
	@echo "IAM_ROLE_ARN=$(IAM_ROLE_ARN)"
	aws cloudformation deploy \
		--template-file $(PIPELINE_TEMPLATE) \
		--stack-name $(STACK_NAME) \
		--parameter-overrides \
			GitHubOAuthToken=$(GITHUB_TOKEN) \
			GitHubOwner=$(GITHUB_OWNER) \
			GitHubRepo=$(GITHUB_REPO) \
			AWSRegion=$(AWS_REGION) \
			AWSAccountId=$(AWS_ACCOUNT_ID) \
			AuthType=$(AUTH_TYPE) \
			Server=$(SERVER) \
			RepositoryName=$(ECR_REPO_NAME) \
			ClusterName=$(CLUSTER_NAME) \
			TaskFamily=$(TASK_FAMILY) \
			ContainerName=$(CONTAINER_NAME) \
			SubnetIds=$(SUBNET_IDS) \
			ProjectName=$(PROJECT_NAME) \
			CodePipelineRoleArn=$(IAM_ROLE_ARN) \
			DOCKERUSERNAME=$(DOCKERUSERNAME) \
			DOCKERTOKEN=$(DOCKERTOKEN) \
		--capabilities CAPABILITY_NAMED_IAM




###############################
###############################
###############################


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
			"name=DOCKERTOKEN,value=$(DOCKERTOKEN),type=PLAINTEXT" \
			"name=DOCKERUSERNAME,value=$(DOCKERUSERNAME),type=PLAINTEXT" \
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
			GitHubOwner=$(GITHUB_OWNER) \
			GitHubOAuthToken=$(GITHUB_TOKEN) \
			GitHubRepo=$(GITHUB_REPO) \
			CodePipelineRoleArn=$(IAM_ROLE_ARN) \
			DOCKERUSERNAME=$(DOCKERUSERNAME) \
			DOCKERTOKEN=$(DOCKERTOKEN) \
		--capabilities CAPABILITY_NAMED_IAM

# Generate imagedefinitions.json
generate-imagedefinitions:
	@echo "Generating imagedefinitions.json for $(CONTAINER_NAME)..."
	@echo '[{"name": "$(CONTAINER_NAME)", "imageUri": "$(DOCKER_IMAGE)"}]' > ./imagedefinitions.json
	@cat ./imagedefinitions.json


# Deploy CodePipeline
deploy-cloudformation:
	@echo "Deploying CloudFormation stack..."
	@echo "IAM_ROLE_ARN=$(IAM_ROLE_ARN)"
	aws cloudformation deploy \
		--template-file $(PIPELINE_TEMPLATE) \
		--stack-name $(STACK_NAME) \
		--parameter-overrides \
			GitHubOAuthToken=$(GITHUB_TOKEN) \
			GitHubOwner=$(GITHUB_OWNER) \
			GitHubRepo=$(GITHUB_REPO) \
			AWSRegion=$(AWS_REGION) \
			AWSAccountId=$(AWS_ACCOUNT_ID) \
			AuthType=$(AUTH_TYPE) \
			Server=$(SERVER) \
			RepositoryName=$(ECR_REPO_NAME) \
			ClusterName=$(CLUSTER_NAME) \
			TaskFamily=$(TASK_FAMILY) \
			ContainerName=$(CONTAINER_NAME) \
			SubnetIds=$(SUBNET_IDS) \
			ProjectName=$(PROJECT_NAME) \
			CodePipelineRoleArn=$(IAM_ROLE_ARN) \
			DOCKERUSERNAME=$(DOCKERUSERNAME) \
			DOCKERTOKEN=$(DOCKERTOKEN) \
		--capabilities CAPABILITY_NAMED_IAM

# ====================
# Combined Workflow
# ====================






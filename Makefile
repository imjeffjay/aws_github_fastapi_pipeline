# ====================
# Static Variables
# ====================
TEMPLATE_DIR = cloudformation

BUCKET_TEMPLATE = $(TEMPLATE_DIR)/artifact-bucket.yaml
IAM_TEMPLATE = $(TEMPLATE_DIR)/iam-template.yaml
SETUP_TEMPLATE = $(TEMPLATE_DIR)/setup-resources.yaml
PIPELINE_TEMPLATE = $(TEMPLATE_DIR)/pipeline-template.yaml

IMAGE_TAG = latest

PROJECT_PREFIX = fastapi2
BUCKET_STACK_NAME = $(AWS_REGION)-BUCKETstack
SETUP_STACK_NAME = $(PROJECT_PREFIX)-SETUPstack
PIPELINE_STACK_NAME = $(PROJECT_PREFIX)-PIPELINEstack
TASK_FAMILY = $(PROJECT_PREFIX)-task
CONTAINER_NAME = $(PROJECT_PREFIX)-container
IAM_STACK_NAME = $(PROJECT_PREFIX)-IAMStack
PROJECT_NAME = $(PROJECT_PREFIX)-project
ECR_REPO_NAME = $(PROJECT_PREFIX)-app
CLUSTER_NAME = $(PROJECT_PREFIX)-cluster
BUCKET_NAME = $(AWS_ACCOUNT_ID)-codepipeline-artifacts-$(AWS_REGION)

# ====================
# Dynamic Variables
# ====================

AWSSECRETS = $(shell aws secretsmanager list-secrets --query "SecretList[?Name=='awspipeline'].Name" --output text)
SECRET_ARN = $(shell aws secretsmanager list-secrets --query "SecretList[?Name=='awspipeline'].ARN" --output text)
GITHUB_TOKEN = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.Token')
GITHUB_OWNER = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.GitHubOwner')
GITHUB_REPO = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.GitHubRepo2')
AUTH_TYPE = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.AuthType')
SERVER = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.ServerType')
DOCKERTOKEN = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.DOCKERTOKEN')
DOCKERUSERNAME = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.DOCKERUSERNAME')
AWS_ACCOUNT_ID = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.AWS_ACCOUNT_ID')
AWS_REGION = $(shell aws secretsmanager get-secret-value --secret-id $(AWSSECRETS) --query SecretString --output text | jq -r '.AWS_REGION')

### From Setup-Resoucres
ARTIFACT_BUCKET_NAME=$(shell aws s3api list-buckets --query "Buckets[?contains(Name, \`${AWS_ACCOUNT_ID}-\`)].Name" --output text | grep $(AWS_REGION) || echo "")
ARTIFACT_BUCKET_ARN=$(shell echo "arn:aws:s3:::$(ARTIFACT_BUCKET_NAME)")
ECR_REPO=$(shell aws cloudformation describe-stack-resources --stack-name fastapi2-SETUPstack --query "StackResources[?LogicalResourceId=='ECRRepository'].PhysicalResourceId" --output text)
CLUSTER=$(shell aws cloudformation describe-stack-resources --stack-name fastapi2-SETUPstack --query "StackResources[?LogicalResourceId=='ECSCluster'].PhysicalResourceId" --output text)
CODEBUILD_PROJECT=$(shell aws cloudformation describe-stack-resources --stack-name fastapi2-SETUPstack --query "StackResources[?ResourceType=='AWS::CodeBuild::Project'].PhysicalResourceId" --output text)

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

### Create bucket for region if not created already
deploy-artifact-bucket:
	@echo "Deploying artifact bucket..."
	aws cloudformation deploy \
		--template-file $(BUCKET_TEMPLATE) \
		--stack-name $(BUCKET_STACK_NAME) \
		--parameter-overrides \
			BucketName=$(BUCKET_NAME)


### Step 1 - Run once per project  ###
# Build IAM Role
build-iam-role:
	@echo "Deploying IAM roles..."
	aws cloudformation deploy \
		--template-file $(IAM_TEMPLATE) \
		--stack-name $(IAM_STACK_NAME) \
		--capabilities CAPABILITY_NAMED_IAM \
		--parameter-overrides \
			SecretArn=$(SECRET_ARN) \
			AWSAccountId=$(AWS_ACCOUNT_ID) \
			AWSRegion=$(AWS_REGION) \
			ArtifactBucketName=$(ARTIFACT_BUCKET_NAME) \
			ArtifactBucketArn=$(ARTIFACT_BUCKET_ARN)
	@echo "IAM roles deployed successfully!"

### Step 2 - Run once per project  ###
# Deploy One-Time Setup Resources
deploy-setup-resources: deploy-artifact-bucket build-iam-role
	@echo "Deploying one-time setup resources (ECR, ECS Cluster, CodeBuild Project)..."
	aws cloudformation deploy \
		--template-file $(SETUP_TEMPLATE) \
		--stack-name $(SETUP_STACK_NAME) \
		--parameter-overrides \
			ProjectName=$(PROJECT_NAME) \
			ECRRepoName=$(ECR_REPO_NAME) \
			ClusterName=$(CLUSTER_NAME) \
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
deploy-pipeline: deploy-setup-resources
	@echo "Deploying CloudFormation stack..."
	@echo "IAM_ROLE_ARN=$(IAM_ROLE_ARN)"
	@echo "ECR_REPO=$(ECR_REPO)"
	@echo "CLUSTER=$(CLUSTER)"
	@echo "ARTIFACT_BUCKET=$(ARTIFACT_BUCKET)"

	aws cloudformation deploy \
		--template-file $(PIPELINE_TEMPLATE) \
		--stack-name $(PIPELINE_STACK_NAME) \
		--parameter-overrides \
			GitHubOAuthToken=$(GITHUB_TOKEN) \
			GitHubOwner=$(GITHUB_OWNER) \
			GitHubRepo=$(GITHUB_REPO) \
			AWSRegion=$(AWS_REGION) \
			AWSAccountId=$(AWS_ACCOUNT_ID) \
			AuthType=$(AUTH_TYPE) \
			Server=$(SERVER) \
			ClusterName=$(CLUSTER) \
			TaskFamily=$(TASK_FAMILY) \
			ContainerName=$(CONTAINER_NAME) \
			SubnetIds=$(SUBNET_IDS) \
			ProjectName=$(CODEBUILD_PROJECT) \
			CodePipelineRoleArn=$(IAM_ROLE_ARN) \
			DOCKERUSERNAME=$(DOCKERUSERNAME) \
			DOCKERTOKEN=$(DOCKERTOKEN) \
			ArtifactBucketName=$(ARTIFACT_BUCKET_NAME) \
			ECRRepoName=$(ECR_REPO)
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

setup-all: check-aws-credentials deploy-artifact-bucket build-iam-role deploy-setup-resources deploy-pipeline

check-aws-credentials:
	@echo "Checking AWS credentials..."
	@aws sts get-caller-identity || (echo "AWS credentials not configured properly" && exit 1)
	@echo "AWS credentials verified"

# ====================
# Cleanup
# ====================

cleanup:
	@echo "Cleaning up AWS resources..."
	aws cloudformation delete-stack --stack-name $(PIPELINE_STACK_NAME)
	aws cloudformation wait stack-delete-complete --stack-name $(PIPELINE_STACK_NAME)
	aws cloudformation delete-stack --stack-name $(SETUP_STACK_NAME)
	aws cloudformation wait stack-delete-complete --stack-name $(SETUP_STACK_NAME)
	aws cloudformation delete-stack --stack-name $(IAM_STACK_NAME)
	aws cloudformation wait stack-delete-complete --stack-name $(IAM_STACK_NAME)
	aws cloudformation delete-stack --stack-name $(BUCKET_STACK_NAME)
	aws cloudformation wait stack-delete-complete --stack-name $(BUCKET_STACK_NAME)
	@echo "Cleanup completed"






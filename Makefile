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
VPC_ID := $(shell aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)

### From Setup-Resoucres
ARTIFACT_BUCKET_NAME=$(shell aws s3api list-buckets --query "Buckets[?contains(Name, \`${AWS_ACCOUNT_ID}-\`)].Name" --output text | grep $(AWS_REGION) || echo "")
ARTIFACT_BUCKET_ARN=$(shell echo "arn:aws:s3:::$(ARTIFACT_BUCKET_NAME)")
ECR_REPO=$(shell aws cloudformation describe-stack-resources --stack-name $(SETUP_STACK_NAME) --query "StackResources[?LogicalResourceId=='ECRRepository'].PhysicalResourceId" --output text)
CLUSTER=$(shell aws cloudformation describe-stack-resources --stack-name $(SETUP_STACK_NAME) --query "StackResources[?LogicalResourceId=='ECSCluster'].PhysicalResourceId" --output text)
CODEBUILD_PROJECT=$(shell aws cloudformation describe-stack-resources --stack-name $(SETUP_STACK_NAME) --query "StackResources[?ResourceType=='AWS::CodeBuild::Project'].PhysicalResourceId" --output text)

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

### Step 1: Create artifact bucket for storing pipeline artifacts
deploy-artifact-bucket:
	@echo "Checking for existing artifact bucket..."
	@if ! aws s3api head-bucket --bucket $(BUCKET_NAME) 2>/dev/null; then \
		echo "Creating new artifact bucket $(BUCKET_NAME)..."; \
		aws cloudformation deploy \
			--template-file $(BUCKET_TEMPLATE) \
			--stack-name $(BUCKET_STACK_NAME) \
			--parameter-overrides \
				BucketName=$(BUCKET_NAME); \
	else \
		echo "Using existing artifact bucket $(BUCKET_NAME)"; \
	fi

### Step 2: Create IAM roles and permissions
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
			ArtifactBucketName=$(BUCKET_NAME) \
			ArtifactBucketArn=$(ARTIFACT_BUCKET_ARN)
	@echo "IAM roles deployed successfully!"

### Step 3: Create basic infrastructure (ECR, ECS Cluster, CodeBuild)
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

### Step 4: Build and push initial Docker image
build-push-image:
	@echo "Triggering CodeBuild to build and push Docker image..."
	@aws codebuild start-build \
		--project-name $(CODEBUILD_PROJECT) \
		--environment-variables-override \
			"name=AWS_REGION,value=$(AWS_REGION),type=PLAINTEXT" \
			"name=AWS_ACCOUNT_ID,value=$(AWS_ACCOUNT_ID),type=PLAINTEXT" \
			"name=ECR_REPO_NAME,value=$(ECR_REPO),type=PLAINTEXT" \
			"name=GITHUB_TOKEN,value=$(GITHUB_TOKEN),type=PLAINTEXT" \
			"name=GITHUB_OWNER,value=$(GITHUB_OWNER),type=PLAINTEXT" \
			"name=GITHUB_REPO,value=$(GITHUB_REPO),type=PLAINTEXT" \
			"name=AUTH_TYPE,value=$(AUTH_TYPE),type=PLAINTEXT" \
			"name=DOCKERTOKEN,value=$(DOCKERTOKEN),type=PLAINTEXT" \
			"name=DOCKERUSERNAME,value=$(DOCKERUSERNAME),type=PLAINTEXT" \
			"name=SERVER,value=$(SERVER),type=PLAINTEXT" \
			"name=CONTAINER_NAME,value=$(CONTAINER_NAME),type=PLAINTEXT" | cat
	@echo "Waiting for new image to be available in ECR..."
	@TIMEOUT=15  # 15 seconds
	@START_TIME=$$(date +%s)
	@while true; do \
		CURRENT_TIME=$$(date +%s); \
		ELAPSED=$$((CURRENT_TIME - START_TIME)); \
		if [ $$ELAPSED -gt $$TIMEOUT ]; then \
			echo "Timeout waiting for new image to be available"; \
			exit 1; \
		fi; \
		IMAGE_PUSH_TIME=$$(aws ecr describe-images --repository-name $(ECR_REPO_NAME) --query 'imageDetails[?imageTags[?@==`latest`]].imagePushedAt' --output text); \
		if [ ! -z "$$IMAGE_PUSH_TIME" ]; then \
			PUSH_TIMESTAMP=$$(date -d "$$IMAGE_PUSH_TIME" +%s); \
			CURRENT_TIMESTAMP=$$(date +%s); \
			TIME_DIFF=$$((CURRENT_TIMESTAMP - PUSH_TIMESTAMP)); \
			if [ $$TIME_DIFF -lt 30 ]; then \
				echo "New image is available in ECR!"; \
				break; \
			fi; \
		fi; \
		echo "Waiting for new image to be available..."; \
		sleep 5; \
	done

### Step 5: Create the CI/CD pipeline and ECS Service
deploy-pipeline: 
	@echo "Verifying required resources..."
	@aws ecr describe-images --repository-name $(ECR_REPO_NAME) --query 'imageDetails[?imageTags[?@==`latest`]]' --output text || (echo "Docker image not found in ECR!" && exit 1)
	@aws ecs describe-clusters --clusters $(CLUSTER) --query 'clusters[0].status' --output text | grep -q "ACTIVE" || (echo "ECS Cluster not active!" && exit 1)
	
	@echo "Checking stack status..."
	@if aws cloudformation describe-stacks --stack-name $(PIPELINE_STACK_NAME) 2>/dev/null | grep -q "ROLLBACK_COMPLETE"; then \
		echo "Stack is in ROLLBACK_COMPLETE state. Deleting before redeploying..."; \
		aws cloudformation delete-stack --stack-name $(PIPELINE_STACK_NAME); \
		aws cloudformation wait stack-delete-complete --stack-name $(PIPELINE_STACK_NAME); \
	fi
	
	@echo "Deploying CloudFormation stack..."
	@echo "IAM_ROLE_ARN=$(IAM_ROLE_ARN)"
	@echo "ECR_REPO=$(ECR_REPO)"
	@echo "CLUSTER=$(CLUSTER)"
	@echo "ARTIFACT_BUCKET=$(ARTIFACT_BUCKET_NAME)"

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
			ProjectName=$(PROJECT_NAME) \
			CodePipelineRoleArn=$(IAM_ROLE_ARN) \
			DOCKERUSERNAME=$(DOCKERUSERNAME) \
			DOCKERTOKEN=$(DOCKERTOKEN) \
			ArtifactBucketName=$(ARTIFACT_BUCKET_NAME) \
			ECRRepoName=$(ECR_REPO) \
			VPCId=$(VPC_ID) \
		--capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM
	@echo "Pipeline deployed successfully!"
	@echo "The pipeline will now monitor GitHub for updates and automatically build and deploy new images."

# ====================
# Combined Workflow
# ====================

# Main target that orchestrates the entire setup process
setup-all: check-aws-credentials deploy-artifact-bucket build-iam-role deploy-setup-resources build-push-image deploy-pipeline

check-aws-credentials:
	@echo "Checking AWS credentials..."
	@aws sts get-caller-identity || (echo "AWS credentials not configured properly" && exit 1)
	@echo "AWS credentials verified"

# ====================
# Cleanup
# ====================

.PHONY: cleanup-alb cleanup-pipeline cleanup-setup cleanup-iam cleanup-bucket

cleanup-alb:
	@echo "Cleaning up ALB and its dependencies..."
	@if aws elbv2 describe-load-balancers --names fastapi2-project-alb >/dev/null 2>&1; then \
		echo "Deleting ALB listener..."; \
		aws elbv2 describe-listeners --load-balancer-arn $$(aws elbv2 describe-load-balancers --names fastapi2-project-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text) --query 'Listeners[*].ListenerArn' --output text | xargs -I {} aws elbv2 delete-listener --listener-arn {}; \
		echo "Deleting target group..."; \
		aws elbv2 describe-target-groups --names fastapi2-project-tg --query 'TargetGroups[0].TargetGroupArn' --output text | xargs -I {} aws elbv2 delete-target-group --target-group-arn {}; \
		echo "Deleting ALB..."; \
		aws elbv2 delete-load-balancer --load-balancer-arn $$(aws elbv2 describe-load-balancers --names fastapi2-project-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text); \
		echo "Waiting for ALB deletion to complete..."; \
		aws elbv2 wait load-balancer-available --load-balancer-arns $$(aws elbv2 describe-load-balancers --names fastapi2-project-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text); \
	else \
		echo "ALB not found, skipping ALB cleanup..."; \
	fi

cleanup-pipeline: cleanup-alb
	@echo "Cleaning up pipeline stack..."
	@if aws cloudformation describe-stacks --stack-name $(PIPELINE_STACK_NAME) >/dev/null 2>&1; then \
		echo "Deleting pipeline stack..."; \
		aws cloudformation delete-stack --stack-name $(PIPELINE_STACK_NAME); \
		echo "Waiting for stack deletion to complete..."; \
		aws cloudformation wait stack-delete-complete --stack-name $(PIPELINE_STACK_NAME); \
	else \
		echo "Pipeline stack not found, skipping pipeline cleanup..."; \
	fi

cleanup-setup: cleanup-pipeline
	@echo "Cleaning up setup resources..."
	@if aws cloudformation describe-stacks --stack-name $(SETUP_STACK_NAME) >/dev/null 2>&1; then \
		echo "Deleting ECR repository first..."; \
		aws ecr delete-repository --repository-name $(ECR_REPO_NAME) --force || true; \
		echo "Deleting setup stack..."; \
		aws cloudformation delete-stack --stack-name $(SETUP_STACK_NAME); \
		echo "Waiting for stack deletion to complete..."; \
		aws cloudformation wait stack-delete-complete --stack-name $(SETUP_STACK_NAME); \
	else \
		echo "Setup stack not found, skipping setup cleanup..."; \
	fi

cleanup-iam: cleanup-setup
	@echo "Cleaning up IAM resources..."
	@if aws cloudformation describe-stacks --stack-name $(IAM_STACK_NAME) >/dev/null 2>&1; then \
		echo "Deleting IAM stack..."; \
		aws cloudformation delete-stack --stack-name $(IAM_STACK_NAME); \
		echo "Waiting for stack deletion to complete..."; \
		aws cloudformation wait stack-delete-complete --stack-name $(IAM_STACK_NAME); \
	else \
		echo "IAM stack not found, skipping IAM cleanup..."; \
	fi

cleanup-bucket: cleanup-iam
	@echo "Cleaning up S3 bucket..."
	@if aws s3api head-bucket --bucket $(BUCKET_NAME) 2>/dev/null; then \
		echo "Deleting contents of bucket $(BUCKET_NAME)..."; \
		aws s3 rm s3://$(BUCKET_NAME) --recursive || true; \
		echo "Deleting bucket $(BUCKET_NAME)..."; \
		aws s3api delete-bucket --bucket $(BUCKET_NAME) || true; \
	else \
		echo "Bucket $(BUCKET_NAME) not found, skipping bucket cleanup..."; \
	fi

cleanup: cleanup-bucket
	@echo "Cleanup completed!"

get-endpoint:
	@echo "Fetching FastAPI endpoint from stack: $(PIPELINE_STACK_NAME)"
	@aws cloudformation describe-stacks \
		--stack-name $(PIPELINE_STACK_NAME) \
		--query "Stacks[0].Outputs[?OutputKey=='LoadBalancerDNS'].OutputValue" \
		--output text

curl-endpoint:
	@echo "Pinging FastAPI root endpoint..."
	@curl http://$$(make --no-print-directory get-endpoint)/






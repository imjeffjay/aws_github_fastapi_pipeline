# ====================
# Variables
# ====================
TEMPLATE_DIR = configs
OUTPUT_DIR = configs

TASK_TEMPLATE = $(TEMPLATE_DIR)/task-definition-template.json
SERVICE_TEMPLATE = $(TEMPLATE_DIR)/service-template.json
PIPELINE_TEMPLATE = $(TEMPLATE_DIR)/pipeline-template.json

TASK_OUTPUT = $(OUTPUT_DIR)/task-definition.json
SERVICE_OUTPUT = $(OUTPUT_DIR)/service.json
PIPELINE_OUTPUT = $(OUTPUT_DIR)/pipeline.json

# Secrets Manager variable
SAMPLE_PIPELINE_PROJECT_ENV = sample_pipeline_project_env

# Fetch secrets and parse each field dynamically
AWS_ACCOUNT_ID := $(shell aws secretsmanager get-secret-value --secret-id $(SAMPLE_PIPELINE_PROJECT_ENV) --query SecretString --output text | jq -r '.AWS_ACCOUNT_ID')
AWS_REGION := $(shell aws secretsmanager get-secret-value --secret-id $(SAMPLE_PIPELINE_PROJECT_ENV) --query SecretString --output text | jq -r '.AWS_REGION')
GITHUB_REPO := $(shell aws secretsmanager get-secret-value --secret-id $(SAMPLE_PIPELINE_PROJECT_ENV) --query SecretString --output text | jq -r '.GITHUB_REPO')
GITHUB_USERNAME := $(shell aws secretsmanager get-secret-value --secret-id $(SAMPLE_PIPELINE_PROJECT_ENV) --query SecretString --output text | jq -r '.GITHUB_USERNAME')
GITHUB_OAUTH_TOKEN := $(shell aws secretsmanager get-secret-value --secret-id $(SAMPLE_PIPELINE_PROJECT_ENV) --query SecretString --output text | jq -r '.GITHUB_OAUTH_TOKEN')

# ====================
# Debugging Commands
# ====================
debug:
	@echo "AWS_ACCOUNT_ID: $(AWS_ACCOUNT_ID)"
	@echo "AWS_REGION: $(AWS_REGION)"
	@echo "GITHUB_REPO: $(GITHUB_REPO)"
	@echo "GITHUB_USERNAME: $(GITHUB_USERNAME)"
	@echo "GITHUB_OAUTH_TOKEN: $(GITHUB_OAUTH_TOKEN)"

# ====================
# Help Command
# ====================
help:
	@echo "Available commands:"
	@echo "  make aws-ecr           - Create ECR repository"
	@echo "  make aws-ecs-cluster   - Create ECS cluster"
	@echo "  make aws-ecs-task      - Register ECS task definition"
	@echo "  make aws-ecs-service   - Create ECS service"
	@echo "  make aws-pipeline      - Create CodePipeline"
	@echo "  make aws-setup         - Run full AWS setup"
	@echo "  make debug             - Print parsed variables"

# ====================
# AWS Setup Commands
# ====================
aws-ecr:
	@echo "Creating ECR repository..."
	aws ecr create-repository --repository-name fastapi-app || true

aws-ecs-cluster:
	@echo "Creating ECS cluster..."
	aws ecs create-cluster --cluster-name FastAPICluster || true

aws-ecs-task:
	@echo "Registering ECS task definition..."
	sed "s/<your-account-id>/$(AWS_ACCOUNT_ID)/g" $(TASK_TEMPLATE) | \
	sed "s/<region>/$(AWS_REGION)/g" > $(TASK_OUTPUT)
	aws ecs register-task-definition --cli-input-json file://$(TASK_OUTPUT)

aws-ecs-service:
	@echo "Creating ECS service..."
	sed "s/<your-account-id>/$(AWS_ACCOUNT_ID)/g" $(SERVICE_TEMPLATE) | \
	sed "s/<region>/$(AWS_REGION)/g" > $(SERVICE_OUTPUT)
	aws ecs create-service --cli-input-json file://$(SERVICE_OUTPUT)

aws-pipeline:
	@echo "Creating CodePipeline..."
	sed "s/<your-account-id>/$(AWS_ACCOUNT_ID)/g" $(PIPELINE_TEMPLATE) | \
	sed "s/<region>/$(AWS_REGION)/g" | \
	sed "s/<github-repo>/$(GITHUB_REPO)/g" | \
	sed "s/<github-username>/$(GITHUB_USERNAME)/g" | \
	sed "s/<github-oauth-token>/$(GITHUB_OAUTH_TOKEN)/g" > $(PIPELINE_OUTPUT)
	aws codepipeline create-pipeline --cli-input-json file://$(PIPELINE_OUTPUT)

aws-setup: aws-ecr aws-ecs-cluster aws-ecs-task aws-ecs-service aws-pipeline
	@echo "AWS setup completed successfully!"

# ====================
# Cleanup Commands
# ====================
clean:
	rm -f $(OUTPUT_DIR)/*.json

# aws_pipeline_setup
A repository to automate the setup of AWS CI/CD pipelines using a Makefile and reusable templates. It creates ECR, ECS, and CodePipeline resources, integrates with Secrets Manager for secure configuration, and enables GitHub-triggered deployments for containerized applications.

## Cloudshell command - Clone github repos
git clone https://imjeffjay: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@github.com/imjeffjay/sample_ML_AWS_pipeline.git
git clone https://imjeffjay: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@github.com/imjeffjay/aws_pipeline_setup.git

## Update Repo
git pull origin main

## Setup services

Steps:
make setup-all


## Delete AWS and restart:

cd aws_pipeline_setup

cd aws_pipeline_setup
aws cloudformation delete-stack --stack-name FastAPIPipelineStack
aws cloudformation wait stack-delete-complete --stack-name FastAPIPipelineStack
aws ecr delete-repository --repository-name fastapi-app --force
aws ecs delete-cluster --cluster FastAPICluster
aws iam delete-role --role-name CodePipelineRole
git pull origin main
make setup-all

cd aws_pipeline_setup
git pull origin main

make build-ecr
make create-codestar-connection
make build-iam-role
make create-codebuild-project

cd aws_github_fastapi_pipeline


DEBUG:


aws ecs describe-task-definition --task-definition fastapi2-task

aws cloudformation describe-stack-events --stack-name fastapi2-stack

aws ecs describe-services --cluster fastapi2-cluster --services fastapi2-stack-ECSService-JFYmbmzr9yhC 


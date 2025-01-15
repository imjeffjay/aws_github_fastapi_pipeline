# aws_pipeline_setup
A repository to automate the setup of AWS CI/CD pipelines using a Makefile and reusable templates. It creates ECR, ECS, and CodePipeline resources, integrates with Secrets Manager for secure configuration, and enables GitHub-triggered deployments for containerized applications.

## Cloudshell command - Clone github repos
git clone https://imjeffjay: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@github.com/imjeffjay/sample_ML_AWS_pipeline.git
git clone https://imjeffjay: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@github.com/imjeffjay/aws_pipeline_setup.git

## Update Repo
git pull origin main

## Setup services

Steps:
#1
make generate-imagedefinitions
#2
make deploy-cloudformation


## Delete AWS and restart:

aws cloudformation delete-stack --stack-name FastAPIPipelineStack
aws cloudformation wait stack-delete-complete --stack-name FastAPIPipelineStack

aws ecr delete-repository --repository-name fastapi-app --force
aws ecs delete-cluster --cluster FastAPICluster
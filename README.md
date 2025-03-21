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



aws codepipeline get-pipeline --name fastapi2-PIPELINEstack-CodePipeline-3w6R6Wd2XiXt --query 'pipeline.roleArn' --output text
aws iam list-attached-role-policies --role-name fastapi2-IAMStack-CodePipelineRole-a7Ervmoi7TAb
aws iam list-role-policies --role-name fastapi2-IAMStack-CodePipelineRole-a7Ervmoi7TAb


TASK_ARN="arn:aws:ecs:us-east-1:475634715655:task/fastapi2-cluster/af4486bc5a3b420981497cddd8674393"


[cloudshell-user@ip-10-136-35-161 aws_github_fastapi_pipeline]$ TASK_ARN=$(aws ecs list-tasks --cluster fastapi2-cluster --query "taskArns[0]" --output text)

[cloudshell-user@ip-10-136-35-161 aws_github_fastapi_pipeline]$ echo "Task ARN: $TASK_ARN"
Task ARN: arn:aws:ecs:us-east-1:475634715655:task/fastapi2-cluster/ceefe85b51cc47128d174a938d9a84b4
[cloudshell-user@ip-10-136-35-161 aws_github_fastapi_pipeline]$ 

[cloudshell-user@ip-10-136-35-161 aws_github_fastapi_pipeline]$ aws ecs describe-tasks \
>   --cluster fastapi2-cluster \
>   --tasks "$TASK_ARN" \
>   --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
>   --output text
eni-04438891e249fd4ec


aws ec2 describe-network-interfaces \
  --network-interface-ids eni-04438891e249fd4ec \
  --query "NetworkInterfaces[0].Association.PublicIp" \
  --output text
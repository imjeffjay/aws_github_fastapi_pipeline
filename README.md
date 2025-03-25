# aws_pipeline_setup
A repository to automate the setup of AWS CI/CD pipelines using a Makefile and reusable templates. It creates ECR, ECS, and CodePipeline resources, integrates with Secrets Manager for secure configuration, and enables GitHub-triggered deployments for containerized applications.

## Cloudshell command - Clone github repos
git clone https://imjeffjay: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@github.com/imjeffjay/sample_ML_AWS_pipeline.git
git clone https://imjeffjay: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@github.com/imjeffjay/aws_pipeline_setup.git

## Update Repo
git pull origin main

ls -> find project
cd

make comands 


### Local Execution
python -m venv ../venv-credit-api  # outside the folder to keep it clean
source ../venv-credit-api/bin/activate

python -m venv venv # inside project dir
source venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt

uvicorn main:app --reload

lsof -i :8000
kill #####

uvicorn main:app --reload

streamlit run app/app.py


alice@example.com
secret
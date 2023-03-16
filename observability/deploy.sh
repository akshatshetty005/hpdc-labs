#!/bin/bash

# Set the Console ARN
export CONSOLE_ROLE_ARN=$(aws sts get-caller-identity --output text --query Arn)
echo "Console ARN Set to $CONSOLE_ROLE_ARN"
echo "export CONSOLE_ROLE_ARN=${CONSOLE_ROLE_ARN}" | tee -a ~/.bash_profile

# Get the User ARN for accessing EKS cluster
export USER_ARN=$(aws iam list-users --output text --query Users[].Arn | grep CandlAwsAccount)
echo "User ARN $USER_ARN"
echo "export USER_ARN=${USER_ARN}" | tee -a ~/.bash_profile


# Remove default creds
rm -vf ${HOME}/.aws/credentials

# Install Tools
curl -sSL https://raw.githubusercontent.com/aws-samples/one-observability-demo/main/PetAdoptions/envsetup.sh | bash -s stable

# Setup environment parameters for later usage

export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region

# Validate ENv
test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set

aws sts get-caller-identity --query Arn | grep observabilityworkshop-admin -q && echo "You're good. IAM role IS valid." || echo "IAM role NOT valid. DO NOT PROCEED."

# Install CDK Package
cd workshopfiles/one-observability-demo/PetAdoptions/cdk/pet_stack
npm install
cdk bootstrap
echo  "Ignore if there are warnings about vulnerabilities "


# Deploy stack
EKS_ADMIN_ARN=$(../../getrole.sh)

echo -e "\nRole \"${EKS_ADMIN_ARN}\" will be part of system\:masters group\n" 

if [ -z $CONSOLE_ROLE_ARN ]; then echo -e "\nEKS Console access will be restricted\n"; else echo -e "\nRole \"${CONSOLE_ROLE_ARN}\" will have access to EKS Console\n"; fi

cdk deploy --no-rollback --context admin_role=$EKS_ADMIN_ARN Services --context dashboard_role_arn=$CONSOLE_ROLE_ARN --require-approval never

# Set permission to User to access EKS cluster
eksctl create iamidentitymapping --cluster PetSite --region=us-east-1 --arn ${USER_ARN}   --group system:masters --username ${CONSOLE_ROLE_ARN}


# Deploy the application
cdk deploy Applications --require-approval never

# Update Kubeconfig
aws eks update-kubeconfig --name PetSite --region $AWS_REGION            
kubectl get nodes   

# The Application URL
aws ssm get-parameter --name '/petstore/petsiteurl'  | jq -r .Parameter.Value


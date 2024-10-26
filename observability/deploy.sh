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

# Install the JQ package
#sudo snap install jq


# Install Tools
# curl -sSL https://raw.githubusercontent.com/aws-samples/one-observability-demo/main/PetAdoptions/envsetup.sh | bash -s stable


git clone https://github.com/aws-samples/one-observability-demo.git

# Setup environment parameters for later usage

export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION="us-east-1"
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region

# Validate ENv
test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set

aws sts get-caller-identity --query Arn | grep observabilityworkshop-admin -q && echo "You're good. IAM role IS valid." || echo "IAM role NOT valid. DO NOT PROCEED."

# Install CDK Package
cd one-observability-demo/PetAdoptions/cdk/pet_stack
npm install
cdk bootstrap
echo  "Ignore if there are warnings about vulnerabilities "


# Deploy stack
EKS_ADMIN_ARN=$(/root/environment/hpdc-labs/observability/one-observability-demo/PetAdoptions/getrole.sh)

echo -e "\nRole \"${EKS_ADMIN_ARN}\" will be part of system\:masters group\n" 

if [ -z $CONSOLE_ROLE_ARN ]; then echo -e "\nEKS Console access will be restricted\n"; else echo -e "\nRole \"${CONSOLE_ROLE_ARN}\" will have access to EKS Console\n"; fi

while true; do
    read -p "Do you wish to install this program? " yn
    case $yn in
        [Yy]* ) make install; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Deploy both EKSCTL and KUBECTL
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.27.7/2023-11-14/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin


cdk deploy --no-rollback --context admin_role=$EKS_ADMIN_ARN Services --context dashboard_role_arn=$CONSOLE_ROLE_ARN --require-approval never

# Set permission to User to access EKS cluster
eksctl create iamidentitymapping --cluster PetSite --region=us-east-1 --arn ${USER_ARN}   --group system:masters --username ${CONSOLE_ROLE_ARN}


# Deploy the application
cdk deploy --no-rollback Applications --require-approval never

# Update Kubeconfig
aws eks update-kubeconfig --name PetSite --region $AWS_REGION            
kubectl get nodes   

# The Application URL
aws ssm get-parameter --name '/petstore/petsiteurl'  | jq -r .Parameter.Value


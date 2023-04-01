#!/bin/bash

echo "Insalling pre-requisites"
sudo pip install boto boto3 botocore
sudo yum -y install ansible
ansible-galaxy collection install community.aws

bkt_name="ecomm-app-`uuidgen`"
bkt_lst=$( aws s3 ls | cut -d " " -f3 | grep "ecomm-app" | head -n 1 )
echo $bkt_lst
if [ $bkt_lst ]; then
	echo "Bucket already exists $bkt_lst"
	bkt_name=$bkt_lst
else
	echo "Creating S3 bucket $bkt_name"
	aws s3 mb s3://$bkt_name
fi

cd frontend/code
echo "Synching files to S3 bucket $bkt_name"
aws s3 sync . s3://$bkt_name

export S3_Bucket="$bkt_name" | tee -a ~/.bash_profile


#!/bin/bash

#curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
#unzip awscliv2.zip
#pip3 install --upgrade --user awscli
#sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin
#sudo ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/bin/aws

pip install --target ./ pymysql
pip install --target ./ boto3
pip install --target ./ faker

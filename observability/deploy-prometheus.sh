	#!/bin/bash
	export AWS_REGION="us-east-1"
	 
	eksctl create iamserviceaccount \
	--name amp-iamproxy-ingest-role \
	--namespace prometheus \
	--cluster PetSite \
	--attach-policy-arn arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess \
	--approve \
	--override-existing-serviceaccounts

	kubectl apply -f https://amazon-eks.s3.amazonaws.com/docs/addons-otel-permissions.yaml
	
	CLUSTER_NAME=PetSite
	aws eks create-addon --addon-name adot --addon-version v0.78.0-eksbuild.1 --cluster-name $CLUSTER_NAME                                                          

	aws eks describe-addon --addon-name adot --cluster-name $CLUSTER_NAME | jq .addon.status

	WORKSPACE_ID=$(aws amp list-workspaces --alias observability-workshop | jq .workspaces[0].workspaceId -r)
	AMP_ENDPOINT_URL=$(aws amp describe-workspace --workspace-id $WORKSPACE_ID | jq .workspace.prometheusEndpoint -r)
	AMP_REMOTE_WRITE_URL=${AMP_ENDPOINT_URL}api/v1/remote_write
	curl -O https://raw.githubusercontent.com/aws-samples/one-observability-demo/main/PetAdoptions/cdk/pet_stack/resources/otel-collector-prometheus.yaml
	sed -i -e s/AWS_REGION/$AWS_REGION/g otel-collector-prometheus.yaml
	sed -i -e s^AMP_WORKSPACE_URL^$AMP_REMOTE_WRITE_URL^g otel-collector-prometheus.yaml
	kubectl apply -f ./otel-collector-prometheus.yaml

	kubectl get all -n prometheus

	kubectl delete -f ./otel-collector-prometheus.yaml

	curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
	chmod 700 get_helm.sh
	./get_helm.sh

	eksctl utils associate-iam-oidc-provider --cluster PetSite --region $AWS_REGION --approve

	eksctl create iamserviceaccount   \
	--name ebs-csi-controller-sa   \
	--namespace kube-system   \
	--cluster PetSite   \
	--attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy  \
	--approve \
	--role-only \
	--role-name AmazonEKS_EBS_CSI_DriverRole

	export SERVICE_ACCOUNT_ROLE_ARN=$(aws iam get-role --role-name AmazonEKS_EBS_CSI_DriverRole | jq -r '.Role.Arn')

	eksctl create addon --name aws-ebs-csi-driver --cluster PetSite --service-account-role-arn $SERVICE_ACCOUNT_ROLE_ARN --force

	kubectl get pods -n kube-system | grep ebs
	
	sleep 30
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add kube-state-metrics https://kubernetes.github.io/kube-state-metrics
	helm repo update

	eksctl create iamserviceaccount \
	--name amp-iamproxy-ingest-role \
	--namespace prometheus \
	--cluster PetSite \
	--attach-policy-arn arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess \
	--approve \
	--override-existing-serviceaccounts

	WORKSPACE_ID=$(aws amp list-workspaces --alias observability-workshop | jq .workspaces[0].workspaceId -r)
	helm install amp-prometheus-chart prometheus-community/prometheus -n prometheus -f https://raw.githubusercontent.com/aws-samples/one-observability-demo/main/PetAdoptions/cdk/pet_stack/resources/amp_ingest_override_values.yaml \
	--set server.remoteWrite[0].url="https://aps-workspaces.${AWS_REGION}.amazonaws.com/workspaces/${WORKSPACE_ID}/api/v1/remote_write" \
	--set server.remoteWrite[0].sigv4.region=${AWS_REGION}

	sleep 30
	kubectl port-forward -n prometheus pods/amp-prometheus-chart-server-0 8080:9090 &

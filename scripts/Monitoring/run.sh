curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
-o "awscliv2.zip"
sudo apt install unzip
unzip awscliv2.zip
sudo ./aws/install
aws configure
sudo snap install terraform --classic
git clone https://github.com/jaiswaladi246/EKS-Terraform.git
cd EKS-Terraform/Terraform
terraform init
terraform plan
terraform apply -auto-approve
aws eks --region ap-south-1 update-kubeconfig --name kkp-cluster
kubectl get nodes
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash
helm version
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/prometheus \
--namespace monitoring --create-namespace -f Monitoring/values.yml
kubectl apply -f Monitoring/pv.yml -n monitoring
kubectl get svc -n monitoring

# Optionally set PROMETHEUS_SVC_NAME to override auto-discovery.
PROM_SVC_NAME="${PROMETHEUS_SVC_NAME:-$(kubectl get svc -n monitoring -l app.kubernetes.io/instance=prometheus,app.kubernetes.io/component=server -o jsonpath='{.items[0].metadata.name}')}"

if [ -z "$PROM_SVC_NAME" ]; then
	echo "Could not auto-detect Prometheus server service name in namespace monitoring."
	echo "Available services:"
	kubectl get svc -n monitoring
	exit 1
fi

echo "Using Prometheus service: $PROM_SVC_NAME"
kubectl patch svc "$PROM_SVC_NAME" -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install grafana grafana/grafana --namespace monitoring --create-namespace --set adminPassword=admin123
helm install blackbox-exporter prometheus-community/prometheus-blackbox-exporter --namespace monitoring --create-namespace

# Optionally set BLACKBOX_SVC_NAME to override auto-discovery.
BLACKBOX_SVC_NAME="${BLACKBOX_SVC_NAME:-$(kubectl get svc -n monitoring -l app.kubernetes.io/instance=blackbox-exporter,app.kubernetes.io/name=prometheus-blackbox-exporter -o jsonpath='{.items[0].metadata.name}')}"

if [ -z "$BLACKBOX_SVC_NAME" ]; then
	echo "Could not auto-detect Blackbox Exporter service name in namespace monitoring."
	echo "Available services:"
	kubectl get svc -n monitoring
	exit 1
fi

echo "Using Blackbox service: $BLACKBOX_SVC_NAME"
kubectl patch svc "$BLACKBOX_SVC_NAME" -n monitoring -p '{"spec":{"type":"LoadBalancer"}}'

kubectl get configmap prometheus-server -n monitoring -o yaml > Monitoring/prometheus-configmap.yaml
kubectl apply -f Monitoring/prometheus-configmap.yaml
kubectl delete pod -n monitoring -l app.kubernetes.io/instance=prometheus,app.kubernetes.io/component=server
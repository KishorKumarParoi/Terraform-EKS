sudo apt-get update -y
sudo apt install docker.io -y
sudo chmod 666 /var/run/docker.sock
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg -y
sudo mkdir -p -m 755 /etc/apt/keyrings

# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubeadm=1.35.0-1.1 kubelet=1.35.0-1.1 kubectl=1.35.0-1.1

# (Optional: Pin to specific version)
# sudo apt-mark hold kubeadm kubelet kubectl


# ---master-node
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# The output of above command to run slave node

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# calico network
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# nginx ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.0/deploy/static/provider/baremetal/deploy.yaml

# for kubernetes dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

kubectl create serviceaccount dashboard-admin -n default
kubectl create clusterrolebinding dashboard-admin-binding --clusterrole=cluster-admin --serviceaccount=default:dashboard-admin

kubectl create token dashboard-admin -n default

apiVersion: v1
kind: Secret
metadata:
  name: dashboard-admin-token
  annotations:
    kubernetes.io/service-account.name: dashboard-admin
type: kubernetes.io/service-account-token       


kubectl get secret dashboard-admin-token -n default -o jsonpath="{.data.token}" | base64 --decode
eyJhbGciOiJSUzI1NiIsImtpZCI6IjhvVENfWmY1Vzl5NU9oMllFUFlFVjZmMHN2azJrZUVVSkM3UUlvbFNOQ3MifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxNzc2Njk3MTAyLCJpYXQiOjE3NzY2OTM1MDIsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwianRpIjoiN2Y3YmY3NWQtYmFjZi00YTVlLWFhZmUtZjU2MmJhMmRhZDZkIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJkZWZhdWx0Iiwic2VydmljZWFjY291bnQiOnsibmFtZSI6ImRhc2hib2FyZC1hZG1pbiIsInVpZCI6ImUxYmEzMWUxLTMyMzctNGVjMy1iNDY4LWM2ZThkN2UzMTJiYiJ9fSwibmJmIjoxNzc2NjkzNTAyLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6ZGVmYXVsdDpkYXNoYm9hcmQtYWRtaW4ifQ.oSYUVEegzUnggCFmXvPqFcgYa16Rq5kVOcZ05jypn2YrUo0CfznrtP6302MN8254MPi3n34GVl4cdC0SJAUhCct8KcpP0jTVySXPoiLAzuHyiTZ8y4mnOg1RVrZEuNx58UG9D1kK2u35U_ShVjHaorxrTpm6Li1e-NlmAz5-3MkNMhCpRiOHWu1i8NbY9v4lOU-ZBX4AdTRMGbXyR0vkbULKYjlmZIm1PDI_tFiJ8AmSb9geuP2mJWDzfqq0W7hImtvBQML4siQuYUEEhgK4902AyBAiApxneTKoFRPDtO4dQ5-jVtcPGhJJQvQMa5ggYQt36EjM-0qQloKkQPvFWQ
# Setting variables
namesuffix=$((10000 + RANDOM % 99999))
RG="azresourcelauncher" # Name of resource group for the AKS cluster
location="uksouth" # Name of the location 
AKS="aks-kubenetlb-${namesuffix}" # Name of the AKS cluster

echo "Creating AKS cluster $AKS in resource group $RG"
# Create new Resource Group
az group create -g $RG -l $location

# Create AKS cluster
az aks create --resource-group $RG --name $AKS --enable-aad --enable-azure-rbac --generate-ssh-keys --enable-addons monitoring --node-count 2 \
--network-plugin kubenet --network-policy calico

sleep 5
# Wait for the AKS cluster creation to be in Running state
# aksextension=$(az aks show --resource-group $aksClusterGroupName --name $aksName --query id --output tsv)
# az resource wait --ids $aksextension --custom "properties.provisioningState!='Creating'"

# Get the AKS infrastructure resource group name
infra_rg=$(az aks show --resource-group $RG --name $AKS --output tsv --query nodeResourceGroup)
echo "The infrastructure resource group is $infra_rg"

# sleep 1
# echo "Let's see if you have 'kubectl' installed locally. Please ignore any errors."
# Install kubectl locally:
# az aks install-cli

sleep 1
# Configuring "kubectl" to connect to the Kubernetes cluster
# echo "If you want to connect to the cluster to run commands, run the following:"
az aks get-credentials --resource-group $RG --name $AKS --admin --overwrite-existing

# Verify network policy

kubectl create namespace demo
--overrides='{"spec": { "nodeSelector": {"kubernetes.io/os": "linux|windows"}}}'

kubectl run server -n demo --image=k8s.gcr.io/e2e-test-images/agnhost:2.33 --labels="app=server" --port=80 --command -- /agnhost serve-hostname --tcp --http=false --port "80"
kubectl run -it client -n demo --image=k8s.gcr.io/e2e-test-images/agnhost:2.33 --command -- bash
kubectl get pod --output=wide -n demo

cat <<EOF > demo-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: demo-policy
  namespace: demo
spec:
  podSelector:
    matchLabels:
      app: server
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: client
    ports:
    - port: 80
      protocol: TCP
EOF

kubectl apply -f demo-policy.yaml

# Tesing with
kubectl exec -it client -n demo -- bash
/agnhost connect <server-ip>:80 --timeout=3s --protocol=tcp
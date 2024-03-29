# Create new Resource Group
aksClusterGroupName="myAks" # Name of resource group for the AKS cluster
resourceLocation="westeurope"
az group create -g $aksClusterGroupName -l $resourceLocation

# Create AKS cluster in the created Resource Group:
aksName="${aksClusterGroupName}-cluster" # Name of the AKS cluster
WINDOWS_USERNAME="M"
WINDOWS_PASSWORD="LetmeInside123!"

az aks create \
    --resource-group $aksClusterGroupName \
    --name $aksName \
    --node-count 1 \
    --enable-addons monitoring \
    --generate-ssh-keys \
    --windows-admin-username $WINDOWS_USERNAME \
    --windows-admin-password $WINDOWS_PASSWORD \
    --vm-set-type VirtualMachineScaleSets \
    --network-plugin azure

az aks nodepool add \
    --resource-group $aksClusterGroupName \
    --cluster-name $aksName \
    --os-type Windows \
    --os-sku Windows2022 \
    --name npwin \
    --node-count 1

# More variables to ready Bastion connection to Windows node

infra_rg=$(az aks show --resource-group $aksClusterGroupName --name $aksName --output tsv --query nodeResourceGroup)
#aksvnet="/subscriptions/d3d07f62-04cb-4701-a543-9c40a9c5a6f4/resourceGroups/MC_myAks_myAks-cluster_northeurope/providers/Microsoft.Network/virtualNetworks/aks-vnet-30092161"
#aksvnetsubnet="/subscriptions/d3d07f62-04cb-4701-a543-9c40a9c5a6f4/resourceGroups/MC_myAks_myAks-cluster_northeurope/providers/Microsoft.Network/virtualNetworks/aks-vnet-30092161/subnets/aks-subnet"

# az network public-ip create -g $infra_rg -n MyPublicIpAddress

#az network bastion create \
#--location $resourceLocation \
#--name aks-vnet-30092161-bastion \
#--public-ip-address aks-vnet-30092161-ip \
#--resource-group $infra_rg \
#--vnet-name $aksvnet

# Configure "kubectl" to connect to the Kubernetes cluster
az aks get-credentials --resource-group $aksClusterGroupName --name $aksName --admin --overwrite-existing

cat <<EOF > akswinsample.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample
  labels:
    app: sample
spec:
  replicas: 3
  template:
    metadata:
      name: sample
      labels:
        app: sample
    spec:
      nodeSelector:      
        kubernetes.io/os: windows
      containers:
      - name: sample
        image: mcr.microsoft.com/dotnet/framework/samples:aspnetapp
        ports:
          - containerPort: 80
  selector:
    matchLabels:
      app: sample
---
apiVersion: v1
kind: Service
metadata:
  name: sample
spec:
  type: LoadBalancer
  ports:
  - protocol: TCP
    port: 80
  selector:
    app: sample
EOF

cat <<EOF > akswinhostsystemprocess.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    pod: hostsysprocess
  name: hostsysprocess
spec:
  securityContext:
    windowsOptions:
      hostProcess: true
      runAsUserName: "NT AUTHORITY\\SYSTEM"
  hostNetwork: true
  containers:
    - name: test
      image: mcr.microsoft.com/oss/kubernetes/pause:3.9-windows-ltsc2022-amd64
      imagePullPolicy: IfNotPresent
      command:
        - pause.exe
  nodeSelector:
    kubernetes.io/os: windows
EOF

kubectl apply -f akswinsample.yaml
kubectl apply -f akswinhostsystemprocess.yaml

# Verify virtual node pod
kubectl get pods -o wide

echo "kubectl exec -it hostsysprocess powershell"

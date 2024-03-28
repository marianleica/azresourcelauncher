# Setting variables
aksClusterGroupName="myAks" # Name of resource group for the AKS cluster
resourceLocation="westeurope" # Name of the location 
aksName="${aksClusterGroupName}-cluster" # Name of the AKS cluster

# Create new Resource Group
az group create -g $aksClusterGroupName -l $resourceLocation

# Create virtual network and subnets
az network vnet create \
--resource-group $aksClusterGroupName \
--name aksVnet \
--address-prefixes 10.0.0.0/8 \
--subnet-name aks_subnet \
--subnet-prefix 10.240.0.0/16

az network vnet subnet create \
--resource-group $aksClusterGroupName \
--vnet-name aksVnet \
--name vnode_subnet \
--address-prefixes 10.241.0.0/16

# Create AKS cluster
subnetId=$(az network vnet subnet show --resource-group $aksClusterGroupName --vnet-name aksVnet --name aks_subnet --query id -o tsv)

az aks create \
--resource-group $aksClusterGroupName \
--name $aksName \
--node-count 3 \
--network-plugin azure \
--vnet-subnet-id $subnetId \
--enable-aad --generate-ssh-keys

# Wait for the AKS cluster creation to be in Running state
# aksextension=$(az aks show --resource-group $aksClusterGroupName --name $aksName --query id --output tsv)
# az resource wait --ids $aksextension --custom "properties.provisioningState!='Creating'"

# Get the AKS infrastructure resource group name
# infra_rg=$(az aks show --resource-group $aksClusterGroupName --name $aksName --output tsv --query nodeResourceGroup)
# Install kubectl locally: az aks install-cli

# Configure "kubectl" to connect to the Kubernetes cluster
az aks get-credentials --resource-group $aksClusterGroupName --name $aksName --admin --overwrite-existing

# Add the ACI resource provider to the subscription
az provider list --query "[?contains(namespace,'Microsoft.ContainerInstance')]" -o table
az provider register --namespace Microsoft.ContainerInstance

# Enable virtual node
az aks enable-addons \
--resource-group $aksClusterGroupName \
--name $aksName \
--addons virtual-node \
--subnet-name vnode_subnet

cat <<EOF >> virtual-node.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aci-helloworld
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aci-helloworld
  template:
    metadata:
      labels:
        app: aci-helloworld
    spec:
      containers:
      - name: aci-helloworld
        image: mcr.microsoft.com/azuredocs/aci-helloworld
        ports:
        - containerPort: 80
      nodeSelector:
        kubernetes.io/role: agent
        beta.kubernetes.io/os: linux
        type: virtual-kubelet
      tolerations:
      - key: virtual-kubelet.io/provider
        operator: Exists
      - key: azure.com/aci
        effect: NoSchedule
EOF

kubectl apply -f virtual-node.yaml

# Verify virtual node pod
kubectl get pods -o wide

: <<'END_COMMENT'
# Test virtual node pod
kubectl run -it --rm testvk --image=mcr.microsoft.com/dotnet/runtime-deps:6.0
apt-get update && apt-get install -y curl
curl -L http://10.241.0.4
END_COMMENT

# The output should look like
#<html>
#<head>
#  <title>Welcome to Azure Container Instances!</title>
#</head>
#[...]

# Remove virtual node from the cluster
# kubectl delete -f virtual-node.yaml
# az aks disable-addons --resource-group myResourceGroup --name myAKSCluster --addons virtual-node

# Change the name of your resource group, cluster and network resources as needed
: <<'END_COMMENT'
# Change the name of your resource group, cluster and network resources as needed
RES_GROUP=myResourceGroup
AKS_CLUSTER=myAKScluster
AKS_VNET=myVnet
AKS_SUBNET=myVirtualNodeSubnet

# Get AKS node resource group
NODE_RES_GROUP=$(az aks show --resource-group $RES_GROUP --name $AKS_CLUSTER --query nodeResourceGroup --output tsv)

# Get network profile ID
NETWORK_PROFILE_ID=$(az network profile list --resource-group $NODE_RES_GROUP --query "[0].id" --output tsv)

# Delete the network profile
az network profile delete --id $NETWORK_PROFILE_ID -y

# Grab the service association link ID
SAL_ID=$(az network vnet subnet show --resource-group $RES_GROUP --vnet-name $AKS_VNET --name $AKS_SUBNET --query id --output tsv)/providers/Microsoft.ContainerInstance/serviceAssociationLinks/default

# Delete the service association link for the subnet
az resource delete --ids $SAL_ID --api-version 2021-10-01

# Delete the subnet delegation to Azure Container Instances
az network vnet subnet update --resource-group $RES_GROUP --vnet-name $AKS_VNET --name $AKS_SUBNET --remove delegations
END_COMMENT


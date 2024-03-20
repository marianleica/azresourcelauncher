# Setting variables
aksClusterGroupName="myAkss" # Name of resource group for the AKS cluster
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
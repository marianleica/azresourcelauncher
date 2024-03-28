# Ref: https://learn.microsoft.com/en-us/azure/aks/private-clusters?tabs=azure-portal
# Setting variables
aksClusterGroupName="myAks" # Name of resource group for the AKS cluster
resourceLocation="westeurope" # Name of the location 
aksName="${aksClusterGroupName}-privcluster" # Name of the AKS cluster

# Create new Resource Group
az group create -g $aksClusterGroupName -l $resourceLocation

# Create private AKS cluster
az aks create -n $aksName -g $aksClusterGroupName --load-balancer-sku standard --enable-private-cluster --enable-aad --generate-ssh-keys

# Configure "kubectl" to connect to the Kubernetes cluster
az aks get-credentials --resource-group $aksClusterGroupName --name $aksName --admin --overwrite-existing
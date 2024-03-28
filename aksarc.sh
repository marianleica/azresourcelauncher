# Setting variables
aksClusterGroupName="myAks" # Name of resource group for the AKS cluster
resourceLocation="westeurope" # Name of the location 
aksName="${aksClusterGroupName}-cluster" # Name of the AKS cluster

# Create new Resource Group
az group create -g $aksClusterGroupName -l $resourceLocation

# Create AKS cluster
az aks create --resource-group $aksClusterGroupName --name $aksName --enable-aad --generate-ssh-keys

infra_rg=$(az aks show --resource-group $aksClusterGroupName --name $aksName --output tsv --query nodeResourceGroup)

# Wait for the AKS cluster creation to be in Running state

aksextension=$(az aks show --resource-group $aksClusterGroupName --name $aksName --query id --output tsv)
az resource wait --ids $aksextension --custom "properties.provisioningState!='Creating'"

# Configure "kubectl" to connect to the Kubernetes cluster
az aks get-credentials --resource-group $aksClusterGroupName --name $aksName --admin --overwrite-existing

# Onboard Kubernetes cluster to Azure Arc-enabled Kubernetes
# Register providers and verify

az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az extension add --upgrade --yes --name connectedk8s

# Connect the Kubernetes cluster to Azure Arc
connectedclustermame="${aksClusterGroupName}-connected" # Name of the connected cluster resource
az connectedk8s connect --resource-group $aksClusterGroupName --name $connectedclustermame

# Confirm the cluster is connected
az connectedk8s show --resource-group $aksClusterGroupName --name $connectedclustermame


# Setting variables
aksClusterGroupName="myAks" # Name of resource group for the AKS cluster
resourceLocation="westeurope" # Name of the location 
aksName="${aksClusterGroupName}-cluster" # Name of the AKS cluster

# Create new Resource Group
az group create -g $aksClusterGroupName -l $resourceLocation

# Create AKS cluster
az aks create --resource-group $aksClusterGroupName --name $aksName --enable-aad --generate-ssh-keys

# Wait for the AKS cluster creation to be in Running state
# aksextension=$(az aks show --resource-group $aksClusterGroupName --name $aksName --query id --output tsv)
# az resource wait --ids $aksextension --custom "properties.provisioningState!='Creating'"

# Get the AKS infrastructure resource group name
# infra_rg=$(az aks show --resource-group $aksClusterGroupName --name $aksName --output tsv --query nodeResourceGroup)

# Install kubectl locally: az aks install-cli

# Configure "kubectl" to connect to the Kubernetes cluster
az aks get-credentials --resource-group $aksClusterGroupName --name $aksName --admin --overwrite-existing


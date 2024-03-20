# Assembled by Marian Leica (maleica@microsoft.com)
# Azure Login and set subscription context with a service principal (Un-comment if necessary)

az login
subscriptionId=$(az account show --query id --output tsv)
# az ad sp create-for-rbac -n "ArcUser" --role "Contributor" --scopes /subscriptions/$subscriptionId

az account set --subscription $subscriptionId

# Setting initial variables

aksClusterGroupName="myAks" # Name of resource group for the AKS cluster
resourceLocation="eastus"
az group create -g $aksClusterGroupName -l $resourceLocation

# Create AKS cluster in the created Resource Group:

aksName="${aksClusterGroupName}-cluster" # Name of the AKS cluster
az aks create --resource-group $aksClusterGroupName --name $aksName --enable-aad --generate-ssh-keys
infra_rg=$(az aks show --resource-group $aksClusterGroupName --name $aksName --output tsv --query nodeResourceGroup)

# Wait for the AKS cluster creation to be in Running state

aksextension=$(az aks show --resource-group $aksClusterGroupName --name $aksName --query id --output tsv)
az resource wait --ids $aksextension --custom "properties.provisioningState!='Creating'"

# Configure "kubectl" to connect to the Kubernetes cluster

az aks get-credentials --resource-group $aksClusterGroupName --name $aksName --admin --overwrite-existing

# Install the Flux v2 extension on the AKS cluster

az k8s-configuration flux create \
--resource-group myAKS \
--cluster-name myAks-cluster \
--cluster-type managedClusters \
--name myconfig \
--scope cluster \
--namespace my-namespace \
--kind git \
--url https://github.com/Azure/arc-k8s-demo \
--branch main \
--kustomization name=my-kustomization

# To get information about the flux configuration

az k8s-configuration flux show -n myconfig -g myAks -t managedClusters -c myAks-cluster

# To get information about the flux extension

az k8s-extension show -n flux -g myAks -c myAks-cluster -t managedClusters

# To update the version of the Flux extension

az k8s-extension update -n myconfig -g myAks -c myAks-cluster -t managedClusters --auto-upgrade false
az k8s-extension update -n flux -g myAks -c myAks-cluster -t managedClusters --version 1.1.2

# Spring cleaning the resources

az group delete -n myAks -y
az group delete -n az group delete -n MC_myAks_myAks-cluster_westeurope -y

# Command to install Flux v2 with config added

az k8s-extension create \
-g myAks \
-c myAks-cluster \
-t managedClusters \
--name flux \
--extension-type microsoft.flux \
--config image-automation-controller.enabled=true

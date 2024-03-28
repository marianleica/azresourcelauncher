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

# to have the ML extesnion for the AKS cluster only
# this next command is only if you do NOT onboard it to Azure Arc

az k8s-extension create \
--name arcml-extension \
--extension-type Microsoft.AzureML.Kubernetes \
--config enableTraining=True \
--cluster-type managedClusters \
--cluster-name myAks-cluster \
--resource-group myAks \
--scope cluster \
--auto-upgrade-minor-version False

# Onboard Kubernetes cluster to Azure Arc-enabled Kubernetes
# Register providers and verify

az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait
az extension add --upgrade --yes --name connectedk8s

# Create a separate resource group

groupName="myArcc" # Name of resource group for the connected cluster
az group create -g $groupName -l $resourceLocation

# Connect the Kubernetes cluster to Azure Arc

clusterName="${groupName}-cluster" # Name of the connected cluster resource
az connectedk8s connect --resource-group $groupName --name $clusterName

# Confirm the cluster is connected

az connectedk8s show --resource-group $groupName --name $clusterName

# Starting procedure for Machine Learning extension create

az k8s-extension create \
--name arcml-extension \
--extension-type Microsoft.AzureML.Kubernetes \
--config enableTraining=True \
--cluster-type connectedClusters \
--cluster-name <your-connected-cluster-name> \
--resource-group <resource-group> \
--scope cluster \
--auto-upgrade-minor-version False

# Spring cleaning the resources
# az group delete -n myAks
# az group delete -n myArc
# az group delete -n az group delete -n MC_myAks_myAks-cluster_westeurope

# Create new Resource Group
aksClusterGroupName="myAkss" # Name of resource group for the AKS cluster
resourceLocation="northeurope"
az group create -g $aksClusterGroupName -l $resourceLocation

# Create AKS cluster in the created Resource Group:
aksName="${aksClusterGroupName}-cluster" # Name of the AKS cluster

az aks create --resource-group $aksClusterGroupName --name $aksName --enable-aad --generate-ssh-keys

# Save the AKS infrastructure resource group name
infra_rg=$(az aks show --resource-group $aksClusterGroupName --name $aksName --output tsv --query nodeResourceGroup)

# Wait for the AKS cluster creation to be in Running state
aksextension=$(az aks show --resource-group $aksClusterGroupName --name $aksName --query id --output tsv)
az resource wait --ids $aksextension --custom "properties.provisioningState!='Creating'"

# Configure "kubectl" to connect to the Kubernetes cluster
az aks get-credentials --resource-group $aksClusterGroupName --name $aksName --admin --overwrite-existing

# Find the nodes to troubleshoot
kubectl get nodes --output wide

kbug="kubectl debug"
echo "kubectl debug node/aks-nodepool1-10943041-vmss000000 -it --image=mcr.microsoft.com/dotnet/runtime-deps:6.0"
echo "apt-get update && apt-get install tcpdump"
echo "tcpdump --snapshot-length=0 -vvv -w /capture.cap"
echo "kubectl cp node-debugger-aks-nodepool1-10943041-vmss000000-dkhkx:capture.cap capture.cap"

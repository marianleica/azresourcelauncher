# Setting variables
LOCATION=westeurope             # the location of your cluster
RESOURCEGROUP=aro-rg            # the name of the resource group where you want to create your cluster
CLUSTER=cluster                 # the name of your cluster

# Create resource group
az group create --name $RESOURCEGROUP --location $LOCATION

# Create VNET and subnets for the ARO cluster
az network vnet create --resource-group $RESOURCEGROUP --name aro-vnet --address-prefixes 10.0.0.0/22
az network vnet subnet create --resource-group $RESOURCEGROUP --vnet-name aro-vnet --name master-subnet --address-prefixes 10.0.0.0/23
az network vnet subnet create --resource-group $RESOURCEGROUP --vnet-name aro-vnet --name worker-subnet --address-prefixes 10.0.2.0/23

# Create the ARO cluster
az aro create --resource-group $RESOURCEGROUP --name $CLUSTER --vnet aro-vnet --master-subnet master-subnet --worker-subnet worker-subnet --master-vm-size Standard_D8s_v3 --worker-vm-size Standard_D4s_v3
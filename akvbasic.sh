# Setting variables
rg='myKV'
location='northeurope'
kv='myKV765621378'

# Create resource group
az group create --name $rg --location $location

# Create Key Vault resource with unique name
az keyvault create --name $kv --resource-group $rg --location $location


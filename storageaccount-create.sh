# Setting Variables
rg="somerg"
loc="northeurope"
accountName="somespace"
containerName="space1"
# sasExpiryDate=$(date -u -d '1 day' '+%Y-%m-%dT%H:%MZ')

# Create a resource group
az group create --name $rgName --location $location

# Create a storage account
az storage account create --name $accountName --resource-group $rgName --location $loc --sku Standard_LRS

# Create containers
az storage container create --name $containerName \
 --account-name $accountName \
 --account-key $(az storage account keys list \
 --resource-group $rg \
 --account-name $accountName \
 --query "[0].value" -o tsv)
# Setting Variables
acrname="myacr234235234"
rg="acrRG1"
loc='northeurope'

# Create Resource Group
az group create -n $rg -l $loc

# Create ACR resource
az acr create -n $acrname -g $rg --sku Premium --public-network-enabled False
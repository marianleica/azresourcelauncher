# Setting Variables
namesuffix=$((10000 + RANDOM % 99999))
acrname="myacr$namesuffix"
rg="acrRG1"
loc='northeurope'

# Create Resource Group
az group create -n $rg -l $loc

# Create ACR resource
az acr create -n $acrname -g $rg --sku Premium --public-network-enabled False
# Setting variables
aksClusterGroupName="myAks" # Name of resource group for the AKS cluster
resourceLocation="westeurope" # Name of the location 
aksName="${aksClusterGroupName}-cluster" # Name of the AKS cluster

# Create new Resource Group
az group create -g $aksClusterGroupName -l $resourceLocation

# Create virtual network and subnets
az network vnet create \
--resource-group $aksClusterGroupName \
--name aksVnet \
--address-prefixes 10.0.0.0/8 \
--subnet-name aks_subnet \
--subnet-prefix 10.240.0.0/16

az network vnet subnet create \
--resource-group $aksClusterGroupName \
--vnet-name aksVnet \
--name vnode_subnet \
--address-prefixes 10.241.0.0/16

# Create AKS cluster
subnetId=$(az network vnet subnet show --resource-group $aksClusterGroupName --vnet-name aksVnet --name aks_subnet --query id -o tsv)
vnetId=$(az network vnet show --resource-group $aksClusterGroupName --name aksVnet)

az aks create \
--resource-group $aksClusterGroupName \
--name $aksName \
--node-count 1 \
--network-plugin azure \
--vnet-subnet-id $subnetId \
--outbound-type userDefinedRouting \
--enable-aad --generate-ssh-keys

# Wait for the AKS cluster creation to be in Running state
# aksextension=$(az aks show --resource-group $aksClusterGroupName --name $aksName --query id --output tsv)
# az resource wait --ids $aksextension --custom "properties.provisioningState!='Creating'"

# Get the AKS infrastructure resource group name
# infra_rg=$(az aks show --resource-group $aksClusterGroupName --name $aksName --output tsv --query nodeResourceGroup)
# Install kubectl locally: az aks install-cli

# Configure "kubectl" to connect to the Kubernetes cluster
az aks get-credentials --resource-group $aksClusterGroupName --name $aksName --admin --overwrite-existing

# Deploy an Azure Firewall

PREFIX="aks-egress"
RG="${PREFIX}-rg"
LOC="eastus"
PLUGIN=azure
AKSNAME="${PREFIX}"
VNET_NAME="${PREFIX}-vnet"
AKSSUBNET_NAME="aks-subnet"
# DO NOT CHANGE FWSUBNET_NAME - This is currently a requirement for Azure Firewall.
FWSUBNET_NAME="AzureFirewallSubnet"
FWNAME="${PREFIX}-fw"
FWPUBLICIP_NAME="${PREFIX}-fwpublicip"
FWIPCONFIG_NAME="${PREFIX}-fwconfig"
FWROUTE_TABLE_NAME="${PREFIX}-fwrt"
FWROUTE_NAME="${PREFIX}-fwrn"
FWROUTE_NAME_INTERNET="${PREFIX}-fwinternet"

az network public-ip create -g $RG -n $FWPUBLICIP_NAME -l $LOC --sku "Standard"

# Install Azure Firewall preview CLI extension
az extension add --name azure-firewall

# Deploy Azure Firewall
az network firewall create -g $RG -n $FWNAME -l $LOC --enable-dns-proxy true

# Configure Firewall IP Config

az network firewall ip-config create -g $RG -f $FWNAME -n $FWIPCONFIG_NAME --public-ip-address $FWPUBLICIP_NAME --vnet-name $VNET_NAME

# Capture Firewall IP Address for Later Use

FWPUBLIC_IP=$(az network public-ip show -g $RG -n $FWPUBLICIP_NAME --query "ipAddress" -o tsv)
FWPRIVATE_IP=$(az network firewall show -g $RG -n $FWNAME --query "ipConfigurations[0].privateIPAddress" -o tsv)


# Create eggress route table for the BYO VNET
az network route-table create -n aksrt -g $aksClusterGroupName
az network route-table route create -n aksrt -g $aksClusterGroupName \
--route-table-name aksrt --name aksroute \
--next-hop-type VirtualAppliance --address-prefix 0.0.0.0/0
--next-hop-ip-address 

# OR
# Create UDR and add a route for Azure Firewall

az network route-table create -g $RG -l $LOC --name $FWROUTE_TABLE_NAME
az network route-table route create -g $RG --name $FWROUTE_NAME --route-table-name $FWROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FWPRIVATE_IP
az network route-table route create -g $RG --name $FWROUTE_NAME_INTERNET --route-table-name $FWROUTE_TABLE_NAME --address-prefix $FWPUBLIC_IP/32 --next-hop-type Internet

###################

az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr' -n 'apiudp' --protocols 'UDP' --source-addresses '*' --destination-addresses "AzureCloud.$LOC" --destination-ports 1194 --action allow --priority 100
az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr' -n 'apitcp' --protocols 'TCP' --source-addresses '*' --destination-addresses "AzureCloud.$LOC" --destination-ports 9000
az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr' -n 'time' --protocols 'UDP' --source-addresses '*' --destination-fqdns 'ntp.ubuntu.com' --destination-ports 123

az network firewall application-rule create -g $RG -f $FWNAME --collection-name 'aksfwar' -n 'fqdn' --source-addresses '*' --protocols 'http=80' 'https=443' --fqdn-tags "AzureKubernetesService" --action allow --priority 100

az network vnet subnet update --ids $subnetId --route-table aksrt

# Change the outbound type from Load Balancer to UserDefinedRouting
az aks update -g $aksClusterGroupName -n $aksName --outbound-type userDefinedRouting

az aks update -g myAkss -n myAkss-cluster \
--outbound-type userDefinedRouting \
--vnet-subnet-id $subnetId
# Docs: https://learn.microsoft.com/en-us/azure/aks/limit-egress-traffic?tabs=aks-with-system-assigned-identities
# Setting variables

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

# Create resource group
az group create --name $RG --location $LOC

# Create VNET and subnet
# Dedicated virtual network with AKS subnet
az network vnet create --resource-group $RG --name $VNET_NAME --location $LOC --address-prefixes 10.42.0.0/16 --subnet-name $AKSSUBNET_NAME --subnet-prefix 10.42.1.0/24

# Dedicated subnet for Azure Firewall (Firewall name can't be changed)
az network vnet subnet create --resource-group $RG --vnet-name $VNET_NAME --name $FWSUBNET_NAME --address-prefix 10.42.2.0/24

# Create and set up firewall
az network public-ip create -g $RG -n $FWPUBLICIP_NAME -l $LOC --sku "Standard"

az extension add --name azure-firewall
az network firewall create -g $RG -n $FWNAME -l $LOC --enable-dns-proxy true

az network firewall ip-config create -g $RG -f $FWNAME -n $FWIPCONFIG_NAME --public-ip-address $FWPUBLICIP_NAME --vnet-name $VNET_NAME

FWPUBLIC_IP=$(az network public-ip show -g $RG -n $FWPUBLICIP_NAME --query "ipAddress" -o tsv)
FWPRIVATE_IP=$(az network firewall show -g $RG -n $FWNAME --query "ipConfigurations[0].privateIPAddress" -o tsv)

# Create route with a hop to Azure Firewall

az network route-table create -g $RG -l $LOC --name $FWROUTE_TABLE_NAME

az network route-table route create -g $RG --name $FWROUTE_NAME --route-table-name $FWROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FWPRIVATE_IP
az network route-table route create -g $RG --name $FWROUTE_NAME_INTERNET --route-table-name $FWROUTE_TABLE_NAME --address-prefix $FWPUBLIC_IP/32 --next-hop-type Internet

# Add firewall rules

az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr' -n 'apiudp' --protocols 'UDP' --source-addresses '*' --destination-addresses "AzureCloud.$LOC" --destination-ports 1194 --action allow --priority 100

az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr' -n 'apitcp' --protocols 'TCP' --source-addresses '*' --destination-addresses "AzureCloud.$LOC" --destination-ports 9000

az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr' -n 'time' --protocols 'UDP' --source-addresses '*' --destination-fqdns 'ntp.ubuntu.com' --destination-ports 123

az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr' -n 'ghcr' --protocols 'TCP' --source-addresses '*' --destination-fqdns ghcr.io pkg-containers.githubusercontent.com --destination-ports '443'

az network firewall network-rule create -g $RG -f $FWNAME --collection-name 'aksfwnr' -n 'docker' --protocols 'TCP' --source-addresses '*' --destination-fqdns docker.io registry-1.docker.io production.cloudflare.docker.com --destination-ports '443'

az network firewall application-rule create -g $RG -f $FWNAME --collection-name 'aksfwar' -n 'fqdn' --source-addresses '*' --protocols 'http=80' 'https=443' --fqdn-tags "AzureKubernetesService" --action allow --priority 100

# Associate the route table to AKS

az network vnet subnet update -g $RG --vnet-name $VNET_NAME --name $AKSSUBNET_NAME --route-table $FWROUTE_TABLE_NAME

# Now deploy AKS cluster that follows the outbound rules

SUBNETID=$(az network vnet subnet show -g $RG --vnet-name $VNET_NAME --name $AKSSUBNET_NAME --query id -o tsv)

# for git bash for windows need to run "export MSYS_NO_PATHCONV=1"
# otherwise, will show a "--vnet-subnet-id is not a valid Azure resource ID." error

az aks create -g $RG -n $AKSNAME \
-l $LOC --node-count 3 \
--network-plugin azure \
--outbound-type userDefinedRouting \
--vnet-subnet-id $SUBNETID

# enable access to the cluster API server
az aks get-credentials --resource-group $RG --name $AKSNAME --admin --overwrite-existing

# deploy a service
# https://github.com/Azure-Samples/aks-store-demo/blob/main/aks-store-quickstart.yaml
kubectl get services -A

SERVICE_IP=$(kubectl get svc store-front -o jsonpath='{.status.loadBalancer.ingress[*].ip}')

az network firewall nat-rule create --collection-name exampleset --destination-addresses $FWPUBLIC_IP --destination-ports 80 --firewall-name $FWNAME --name inboundrule --protocols Any --resource-group $RG --source-addresses '*' --translated-port 80 --action Dnat --priority 100 --translated-address $SERVICE_IP

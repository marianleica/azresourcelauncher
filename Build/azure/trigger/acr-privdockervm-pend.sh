# Setting Variables
acrname="myacr234235234"
rg="acrRG1"
loc='northeurope'
vm="dockerVM"

# Create Resource Group
az group create -n $rg -l $loc

# Create ACR resource
az acr create -n $acrname -g $rg --sku Premium # --public-network-enabled False

# Create a docker-enabled VM
az vm create \
--resource-group $rg \
--name $vm \
--image Ubuntu2204 \
--admin-username azureuser \
--nsg-rule ssh \
--public-ip-sku Standard \
--generate-ssh-keys

# Grab public IP address into variable
vmpip=`az vm list-ip-addresses -g $rg -n $vm \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv`

# Connect to the VM via ssh
ssh azureuser@$vmpip -o StrictHostKeyChecking=no

# Install docker
sudo apt-get update
sudo apt install docker.io -y

# Double-check docker is working as expected
sudo docker run -it hello-world
# The output should be smth like:
# Hello from Docker!
# This message shows that your installation appears to be working correctly.
# [...]

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to the ACR
# az login
# az acr login --name $acrname

# Exit ssh session
exit

# Configure network access for the registry
az network vnet list --resource-group $rg --query "[].{Name: name, Subnet: subnets[0].name}"

# Set up private link

NETWORK_NAME=<virtual-network-name>
SUBNET_NAME=<subnet-name>

# Disable network policy in the subnet
az network vnet subnet update \
--name $SUBNET_NAME \
--vnet-name $NETWORK_NAME \
--resource-group $RESOURCE_GROUP \
--disable-private-endpoint-network-policies

# Configure Azure Private DNS zone
az network private-dns zone create \
--resource-group $RESOURCE_GROUP \
--name "privatelink.azurecr.io"

# Create association link
az network private-dns link vnet create \
--resource-group $RESOURCE_GROUP \
--zone-name "privatelink.azurecr.io" \
--name MyDNSLink \
--virtual-network $NETWORK_NAME \
--registration-enabled false

# Create private registry endpoint
acrid=$(az acr show --name $acrname --query 'id' --output tsv)
az network private-endpoint create \
--name myPrivateEndpoint \
--resource-group $rg \
--vnet-name $NETWORK_NAME \
--subnet $SUBNET_NAME \
--private-connection-resource-id $acrid \
--group-ids registry \
--connection-name myConnection

# Get endpoint IP configuration
NETWORK_INTERFACE_ID=$(az network private-endpoint show --name myPrivateEndpoint --resource-group $RESOURCE_GROUP --query 'networkInterfaces[0].id' --output tsv)
REGISTRY_PRIVATE_IP=$(az network nic show --ids $NETWORK_INTERFACE_ID --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry'].privateIpAddress" --output tsv)
DATA_ENDPOINT_PRIVATE_IP=$(az network nic show --ids $NETWORK_INTERFACE_ID --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry_data_$REGISTRY_LOCATION'].privateIpAddress" --output tsv)

# An FQDN is associated with each IP address in the IP configurations
REGISTRY_FQDN=$(az network nic show --ids $NETWORK_INTERFACE_ID --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry'].privateLinkConnectionProperties.fqdns" --output tsv)
DATA_ENDPOINT_FQDN=$(az network nic show --ids $NETWORK_INTERFACE_ID --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry_data_$REGISTRY_LOCATION'].privateLinkConnectionProperties.fqdns" --output tsv)

# Create DNS record in the private zone
az network private-dns record-set a create --name $REGISTRY_NAME --zone-name privatelink.azurecr.io --resource-group $RESOURCE_GROUP

# Specify registry region in data endpoint name
az network private-dns record-set a create --name ${REGISTRY_NAME}.${REGISTRY_LOCATION}.data --zone-name privatelink.azurecr.io --resource-group $RESOURCE_GROUP


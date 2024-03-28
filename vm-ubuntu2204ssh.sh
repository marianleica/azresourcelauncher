# Setting variables
RG="myVM"
VM="bestVM"
location="northeurope"

# Create resource group
az group create -n $RG -l $location

# Create VM
az vm create -n $VM -g $RG \
--image Ubuntu2204 \
--generate-ssh-keys \
--admin-username bestuser \
--size Standard_D2s_v3 \
--nsg-rule ssh \
--public-ip-sku Standard

# Grab public IP address into variable
vmpip=`az vm list-ip-addresses -g $RG -n $VM \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv`

# Connect to the VM via ssh
ssh bestuser@$vmpip -o StrictHostKeyChecking=no

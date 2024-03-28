# Setting variables
rg='myVM'
location='northeurope'
vmName='dockerubuntu'
image='Ubuntu2204'

# Create resource group
az group create -n $rg -l $location

az vm create \
--resource-group $rg \
--name $vmName \
--image Ubuntu2204 \
--admin-username bestuser \
--nsg-rule ssh \
--public-ip-sku Standard \
--generate-ssh-keys

# This is the public IP address
vmip=$(az vm list-ip-addresses -g $rg -n $vmName \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)

# Connect to the VM via ssh
ssh bestuser@$vmip -o StrictHostKeyChecking=no

sudo apt-get update
sudo apt install docker.io -y
sudo docker run -it hello-world

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
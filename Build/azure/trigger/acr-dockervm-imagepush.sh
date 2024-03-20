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

az login
az acr login --name myacr234235234

sudo docker tag hello-world myacr234235234.azurecr.io/samples/hello-world:v2
sudo docker push myacr234235234.azurecr.io/samples/hello-world:v2
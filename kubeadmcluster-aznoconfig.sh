# Assembled by Marian Leica (maleica@microsoft.com)
# Azure Login and set subscription context with a service principal (Un-comment if necessary)

# az login
# subscriptionId=$(az account show --query id --output tsv)

# if required, uncomment:
# az ad sp create-for-rbac -n "ArcUser" --role "Contributor" --scopes /subscriptions/$subscriptionId

# az account set --subscription $subscriptionId

# Setting variables

rg="kubeadm"
vnet="kubeadm"
subnet="kube"
nodeimage="Ubuntu2204"
adminuser="maleica"

# Step 1. Create infrastructure: VNET, NSG, 2 master VMs, 2 worker VMs, load balncer for master VMs

az group create -n kubeadm -l uksouth

az network vnet create \
    --resource-group kubeadm \
    --name kubeadm \
    --address-prefix 192.168.0.0/16 \
    --subnet-name kube \
    --subnet-prefix 192.168.0.0/16

sleep 1

az network nsg create \
    --resource-group kubeadm \
    --name kubeadm

sleep 1

az network nsg rule create \
    --resource-group kubeadm \
    --nsg-name kubeadm \
    --name kubeadmssh \
    --protocol tcp \
    --priority 1000 \
    --destination-port-range 22 \
    --access allow

sleep 1

az network nsg rule create \
    --resource-group kubeadm \
    --nsg-name kubeadm \
    --name kubeadmWeb \
    --protocol tcp \
    --priority 1001 \
    --destination-port-range 6443 \
    --access allow

sleep 1

az network vnet subnet update \
    -g kubeadm \
    -n kube \
    --vnet-name kubeadm \
    --network-security-group kubeadm

sleep 1

# Creating the Virtual Machines

az vm create -n kube-master-1 -g kubeadm \
--image Ubuntu2204 \
--vnet-name kubeadm --subnet kube \
--admin-username maleicaadmin \
--ssh-key-value @~/.ssh/id_rsa.pub \
--size Standard_D2ds_v4 \
--nsg kubeadm \
--public-ip-sku Standard --no-wait

sleep 2

az vm create -n kube-master-2 -g kubeadm \
--image Ubuntu2204 \
--vnet-name kubeadm --subnet kube \
--admin-username maleicaadmin \
--ssh-key-value @~/.ssh/id_rsa.pub \
--size Standard_D2ds_v4 \
--nsg kubeadm \
--public-ip-sku Standard --no-wait

sleep 2

az vm create -n kube-worker-1 -g kubeadm \
--image Ubuntu2204 \
--vnet-name kubeadm --subnet kube \
--admin-username maleicaadmin \
--ssh-key-value @~/.ssh/id_rsa.pub \
--size Standard_D2ds_v4 \
--nsg kubeadm \
--public-ip-sku Standard --no-wait

sleep 2

az vm create -n kube-worker-2 -g kubeadm \
--image Ubuntu2204 \
--vnet-name kubeadm --subnet kube \
--admin-username maleicaadmin \
--ssh-key-value @~/.ssh/id_rsa.pub \
--size Standard_D2ds_v4 \
--nsg kubeadm \
--public-ip-sku Standard

sleep 2

# Creating the load balancer

az network public-ip create \
    --resource-group kubeadm \
    --name controlplaneip \
    --sku Standard \
    --dns-name maleicakubeadm

sleep 1

 az network lb create \
    --resource-group kubeadm \
    --name kubemaster \
    --sku Standard \
    --public-ip-address controlplaneip \
    --frontend-ip-name controlplaneip \
    --backend-pool-name masternodes

sleep 1

az network lb probe create \
    --resource-group kubeadm \
    --lb-name kubemaster \
    --name kubemasterweb \
    --protocol tcp \
    --port 6443

sleep 1

az network lb rule create \
    --resource-group kubeadm \
    --lb-name kubemaster \
    --name kubemaster \
    --protocol tcp \
    --frontend-port 6443 \
    --backend-port 6443 \
    --frontend-ip-name controlplaneip \
    --backend-pool-name masternodes \
    --probe-name kubemasterweb \
    --disable-outbound-snat true \
    --idle-timeout 15 \
    --enable-tcp-reset true

sleep 1

az network nic ip-config address-pool add \
    --address-pool masternodes \
    --ip-config-name ipconfigkube-master-1 \
    --nic-name kube-master-1VMNic \
    --resource-group kubeadm \
    --lb-name kubemaster

sleep 1

az network nic ip-config address-pool add \
    --address-pool masternodes \
    --ip-config-name ipconfigkube-master-2 \
    --nic-name kube-master-2VMNic \
    --resource-group kubeadm \
    --lb-name kubemaster

sleep 1

# Getting public IPs of all the nodes ready

MASTER1IP=$(az vm list-ip-addresses -g kubeadm -n kube-master-1 \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
MASTER2IP=$(az vm list-ip-addresses -g kubeadm -n kube-master-2 \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
WORKER1IP=$(az vm list-ip-addresses -g kubeadm -n kube-worker-1 \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
WORKER2IP=$(az vm list-ip-addresses -g kubeadm -n kube-worker-2 \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
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

az network nsg create \
    --resource-group kubeadm \
    --name kubeadm

az network nsg rule create \
    --resource-group kubeadm \
    --nsg-name kubeadm \
    --name kubeadmssh \
    --protocol tcp \
    --priority 1000 \
    --destination-port-range 22 \
    --access allow

az network nsg rule create \
    --resource-group kubeadm \
    --nsg-name kubeadm \
    --name kubeadmWeb \
    --protocol tcp \
    --priority 1001 \
    --destination-port-range 6443 \
    --access allow

az network vnet subnet update \
    -g kubeadm \
    -n kube \
    --vnet-name kubeadm \
    --network-security-group kubeadm

# Creating the Virtual Machines

az vm create -n kube-master-1 -g kubeadm \
--image Ubuntu2204 \
--vnet-name kubeadm --subnet kube \
--admin-username maleicaadmin \
--ssh-key-value @~/.ssh/id_rsa.pub \
--size Standard_D2ds_v4 \
--nsg kubeadm \
--public-ip-sku Standard --no-wait

az vm create -n kube-master-2 -g kubeadm \
--image Ubuntu2204 \
--vnet-name kubeadm --subnet kube \
--admin-username maleicaadmin \
--ssh-key-value @~/.ssh/id_rsa.pub \
--size Standard_D2ds_v4 \
--nsg kubeadm \
--public-ip-sku Standard --no-wait

az vm create -n kube-worker-1 -g kubeadm \
--image Ubuntu2204 \
--vnet-name kubeadm --subnet kube \
--admin-username maleicaadmin \
--ssh-key-value @~/.ssh/id_rsa.pub \
--size Standard_D2ds_v4 \
--nsg kubeadm \
--public-ip-sku Standard --no-wait

az vm create -n kube-worker-2 -g kubeadm \
--image Ubuntu2204 \
--vnet-name kubeadm --subnet kube \
--admin-username maleicaadmin \
--ssh-key-value @~/.ssh/id_rsa.pub \
--size Standard_D2ds_v4 \
--nsg kubeadm \
--public-ip-sku Standard

# Creating the load balancer

az network public-ip create \
    --resource-group kubeadm \
    --name controlplaneip \
    --sku Standard \
    --dns-name maleicakubeadm

 az network lb create \
    --resource-group kubeadm \
    --name kubemaster \
    --sku Standard \
    --public-ip-address controlplaneip \
    --frontend-ip-name controlplaneip \
    --backend-pool-name masternodes

az network lb probe create \
    --resource-group kubeadm \
    --lb-name kubemaster \
    --name kubemasterweb \
    --protocol tcp \
    --port 6443

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

az network nic ip-config address-pool add \
    --address-pool masternodes \
    --ip-config-name ipconfigkube-master-1 \
    --nic-name kube-master-1VMNic \
    --resource-group kubeadm \
    --lb-name kubemaster

az network nic ip-config address-pool add \
    --address-pool masternodes \
    --ip-config-name ipconfigkube-master-2 \
    --nic-name kube-master-2VMNic \
    --resource-group kubeadm \
    --lb-name kubemaster

# Getting public IPs of all the nodes ready

MASTER1IP=$(az vm list-ip-addresses -g kubeadm -n kube-master-1 \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
MASTER2IP=$(az vm list-ip-addresses -g kubeadm -n kube-master-2 \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
WORKER1IP=$(az vm list-ip-addresses -g kubeadm -n kube-worker-1 \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
WORKER2IP=$(az vm list-ip-addresses -g kubeadm -n kube-worker-2 \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)

# Setup the first master node

sleep 2
ssh maleicaadmin@$MASTER1IP -o StrictHostKeyChecking=no

sleep 1
sudo apt update
sudo apt -y install curl apt-transport-https </dev/null

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update

# packages have changed
# sudo apt -y install vim git curl wget kubelet kubeadm kubectl containerd </dev/null
# change with what's next:
sudo snap install kubelet --classic
sudo snap install kubeadm --classic
sudo snap install kubectl --classic
sudo apt -y install containerd

# this one too fails to locate package in ubuntu 2204
# sudo apt-mark hold kubelet kubeadm kubectl
# hold is used to mark a package as held back, which will prevent the package from being automatically installed, upgraded or removed.
# I guess we can ignore it

kubectl version --client && kubeadm version

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# Setting up Kubernetes via kubeadm
# new error here on Ubuntu 2204, can't find crictl and it's required
# installing crictl first via wget bypasses the error of not having crictl capability

VERSION="v1.26.0" # check latest version in /releases page
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz

# new error for not having "socat" in system path
# installing with:
sudo apt-get install socat

# socat is installed now, but new error is that kubelet is not enabled. enabling kubelet:
# running "sudo systemctl enable kubelet.service" says it does not exist
# finding what could be next:
RELEASE_VERSION="v0.4.0"
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service
sudo mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sudo systemctl enable kubelet.service
# passed this issue too

# now the error is that conntrack was not found in system path
sudo apt-get install conntrack

# new error "port 10250 is in use" ?
# confirmed it is in use with "netstat -plnt"
# Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
# tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      -                   
# tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -                   
# tcp        0      0 127.0.0.1:10248         0.0.0.0:*               LISTEN      -                   
# tcp        0      0 127.0.0.1:33285         0.0.0.0:*               LISTEN      -                   
# tcp6       0      0 :::22                   :::*                    LISTEN      -                   
# tcp6       0      0 :::10255                :::*                    LISTEN      -                   
# tcp6       0      0 :::10250                :::*                    LISTEN      -                   
# but i don't know what is using it ... it's not showing anything
# running "netstat -lnp"
# running "sudo netstat -lnp | grep 10250" and there you go:
# tcp6       0      0 :::10250                :::*                    LISTEN      6506/kubelet 
# what now? kill the kubelet and it will be complaining that the service is not running
# maybe I can be fast enough, kill the kubelet PID and run kubeadm init, seems to be working
# but now it's timing out waiting for the kubelet to boot up the control plane "/etc/kubernetes/manifests"

sudo kubeadm init --control-plane-endpoint "maleicakubeadm.westeurope.cloudapp.azure.com:6443" --upload-certs

# The output will provide information like:
# Where to get the kubeconfig to configure kubectl to work with this cluster
# How to join additional control plane nodes
# Prepare the node and run: 
# sudo kubeadm join maleicakubeadm.westeurope.cloudapp.azure.com:6443 --token tqczj3.65y68j4nx5wggtvz \
#        --discovery-token-ca-cert-hash sha256:2dddb301bab413138dd42a46d5a6e49bf665a6ab90ed4b3646d50804ef2d719 \
#        --control-plane --certificate-key f8af04b6d58e0013d4cac3a97ac2275a693798f3d5f1f51973bdb2c9fadd3247
# How to join worker nodes
# Prepare the node and run:
# sudo kubeadm join maleicakubeadm.westeurope.cloudapp.azure.com:6443 --token tqczj3.65y68j4nx5wggtvz \
#        --discovery-token-ca-cert-hash sha256:2dddb301bab413138dd42a46d5a6e49bf665a6ab90ed4b3646d50804ef2d719

# Copy aside the two kubeadm join commands for the other nodes

# Run:

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Try interacting with the cluster

kubectl get nodes

# Nodes shouldn't be ready yet, CNI was not set up yet

# kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
# ^command started having issues, probably since kubernetes version changed to 1.25 
# Use instead:
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# Recheck the nodes, wait until it appears as 'Ready'

kubectl get nodes

# When done, exit the ssh session

exit

# Set up kube config on your shell outside the node

scp maleicaadmin@$MASTER1IP:/home/maleicaadmin/.kube/config .config
export KUBECONFIG=`pwd`/.config

# Test checking the nodes

kubectl get nodes

# Prepare 2nd node

ssh maleicaadmin@$MASTER2IP
yes

sudo apt update
sudo apt -y install curl apt-transport-https </dev/null

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt -y install vim git curl wget kubelet kubeadm kubectl containerd </dev/null

sudo apt-mark hold kubelet kubeadm kubectl

kubectl version --client && kubeadm version

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# Run the pasted join commands for the second control plane
# Of course, there will be different values for the same parameters

sudo kubeadm join maleicakubeadm.westeurope.cloudapp.azure.com:6443 --token tqczj3.65y68j4nx5wggtvz \
        --discovery-token-ca-cert-hash sha256:2dddb301bab413138dd42a46d5a6e49bf665a6ab90ed4b3646d50804ef2d719 \
        --control-plane --certificate-key f8af04b6d58e0013d4cac3a97ac2275a693798f3d5f1f51973bdb2c9fadd3247

exit

# Recheck nodes

kubectl get nodes

# Set up the worker nodes

ssh maleicaadmin@$WORKER1IP
yes

sudo apt update
sudo apt -y install curl apt-transport-https </dev/null


curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt -y install vim git curl wget kubelet kubeadm kubectl containerd </dev/null


sudo apt-mark hold kubelet kubeadm kubectl

kubectl version --client && kubeadm version

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

sudo kubeadm join maleicakubeadm.westeurope.cloudapp.azure.com:6443 --token tqczj3.65y68j4nx5wggtvz \
    --discovery-token-ca-cert-hash sha256:2dddb301ba8b413138dd42a46d5a6e49bf665a6ab90ed4b3646d50804ef2d719 

exit

ssh maleicaadmin@$WORKER2IP

sudo apt update
sudo apt -y install curl apt-transport-https </dev/null
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt -y install vim git curl wget kubelet kubeadm kubectl containerd </dev/null
sudo apt-mark hold kubelet kubeadm kubectl

kubectl version --client && kubeadm version

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

sudo kubeadm join maleicakubeadm.westeurope.cloudapp.azure.com:6443 --token tqczj3.65y68j4nx5wggtvz \
    --discovery-token-ca-cert-hash sha256:2dddb301ba8b413138dd42a46d5a6e49bf665a6ab90ed4b3646d50804ef2d719 

exit

# Recheck nodes

kubectl get nodes

# Prepare for onboarding to Azure Arc-enabled Kubernetes

ssh maleicaadmin@$MASTER1IP

# Installing Helm

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure

az login

# Run the onboarding command

az connectedk8s connect -g kubeadm -n connectedkubeadm

# Check the status

kubectl get all -n azure-arc

# Delete the Arc operators from the cluster

az connectedk8s delete -g kubeadm -n connectedkubeadm

# Clean-up everything

exit
az group delete -n kubeadm -y

# Resources:
# https://blog.nillsf.com/index.php/2021/10/29/setting-up-kubernetes-on-azure-using-kubeadm/
# https://github.com/NillsF/blog/tree/master/kubeadm
# https://raw.githubusercontent.com/NillsF/blog/master/kubeadm/prep-node.sh

<<'END_COMMENT'

# Next steps
######################

# Defender extension

az k8s-extension create \
--name microsoft.azuredefender.kubernetes \
--cluster-type connectedClusters \
--cluster-name connectedkubeadm \
--resource-group kubeadm \
--extension-type microsoft.azuredefender.kubernetes

az k8s-extension delete \
--name microsoft.azuredefender.kubernetes \
--cluster-type connectedClusters \
--cluster-name connectedkubeadm \
--resource-group kubeadm

# Monitor 

az k8s-extension create \
--name azuremonitor-containers \
--cluster-name connectedkubeadm \
--resource-group kubeadm \
--cluster-type connectedClusters \
--extension-type Microsoft.AzureMonitor.Containers

az k8s-extension delete \
--name azuremonitor-containers \
--cluster-name connectedkubeadm \
--resource-group kubeadm \
--cluster-type connectedClusters

# Policy

az k8s-extension create \
--cluster-type connectedClusters \
--cluster-name connectedkubeadm \
--resource-group kubeadm \
--extension-type Microsoft.PolicyInsights \
--name azurepolicy

az k8s-extension delete \
--cluster-type connectedClusters \
--cluster-name connectedkubeadm \
--resource-group kubeadm \
--name azurepolicy

# Flux v2

az k8s-configuration flux create \
--resource-group kubeadm \
--cluster-name connectedkubeadm \
--cluster-type connectedClusters \
--name myconfig \
--scope cluster \
--namespace my-namespace \
--kind git \
--url https://github.com/Azure/arc-k8s-demo \
--branch main \
--kustomization name=my-kustomization

# Resource requirements testing

# 1 master node Standard_D2ds_v4 is not enough for Azure Arc deployment
# Pods remain stuck in Pending state all with 0/1 or 0/2
# The diagnoser doesn't run with error:
# "There exist no ConnectedCluster resource corresponding to this kubernetes Cluster."

# 1 master node Standard_D2ds_v4
# 1 worker node Standard_D2ds_v4
# enough to onboard to Azure Arc-enabled Kubernetes
# enough to install the Policy extension on top

END_COMMENT
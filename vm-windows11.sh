# Setting variables
rg='myVM'
location='northeurope'
vmName='winclient1'
image='MicrosoftWindowsDesktop:windows-11:win11-23h2-pro:22631.2428.231023'
# 'CentOS85Gen2', 'Debian11', 'FlatcarLinuxFreeGen2', 'OpenSuseLeap154Gen2', 'RHELRaw8LVMGen2',
# 'SuseSles15SP3', 'Ubuntu2204', 'Win2022Datacenter', 'Win2022AzureEditionCore', 'Win2019Datacenter',
# 'Win2016Datacenter', 'Win2012R2Datacenter', 'Win2012Datacenter', 'Win2008R2SP1'
# az vm image list -f windows-11 -o table --all 
subscriptionID='d3d07f62-04cb-4701-a543-9c40a9c5a6f4'

# Create RG
az group create -n $rg -l $location

# Create NSG
#az network nsg create --name NSG4VM --resource-group $rg
#az network nsg rule create \
#--name inboundrule4vm \
#--nsg-name NSG4VM \
#--priority 200 \
#--resource-group $rg \
#--access Allow \
#--destination-port-ranges 3383 \
#--direction Inbound \
#--protocol Tcp

# Create Windows 11
az vm create -g $rg -n $vmName \
--image $image \
--admin-user "M" --admin-password "getwoT-tenfo9-cipqiv" \
--public-ip-sku Standard \
--nsg NSG4VM \
--nsg-rule RDP

# This is the public IP address
vmip=$(az vm list-ip-addresses -g $rg -n $vmName \
--query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)

cd /Applications
open "Microsoft Remote Desktop.app"
echo $vmip
echo getwoT-tenfo9-cipqiv

#pwsh
#$rg='myVM'
#$location='northeurope'
#$vmName='winclient1'
#Get-AzRemoteDesktopFile -ResourceGroupName $rg -Name $vmName -Launch

# Setting variables
rg='myVM'
location='northeurope'
vmName='ubuntu1'
image='Ubuntu2204'
# 'CentOS85Gen2', 'Debian11', 'FlatcarLinuxFreeGen2', 'OpenSuseLeap154Gen2', 'RHELRaw8LVMGen2',
# 'SuseSles15SP3', 'Ubuntu2204', 'Win2022Datacenter', 'Win2022AzureEditionCore', 'Win2019Datacenter',
# 'Win2016Datacenter', 'Win2012R2Datacenter', 'Win2012Datacenter', 'Win2008R2SP1'

# Create Ubuntu2204 VM
az group create -n $rg -l $location
az vm create -g $rg -n $vmName --image $image --generate-ssh-keys
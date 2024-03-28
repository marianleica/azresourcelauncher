New-AzResourceGroup -Name 'myResourceGroup' -Location 'EastUS'

New-AzVm `
    -ResourceGroupName 'myResourceGroup' `
    -Name 'myVM' `
    -Location 'EastUS' `
    -Image 'MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest' `
    -VirtualNetworkName 'myVnet' `
    -SubnetName 'mySubnet' `
    -SecurityGroupName 'myNetworkSecurityGroup' `
    -PublicIpAddressName 'myPublicIpAddress' `
    -OpenPorts 80,3389

Invoke-AzVMRunCommand -ResourceGroupName 'myResourceGroup' -VMName 'myVM' -CommandId 'RunPowerShellScript' -ScriptString 'Install-WindowsFeature -Name Web-Server -IncludeManagementTools'

# Get-PublicIPAddress
# Remove-AzResourceGroup -Name 'myResourceGroup'
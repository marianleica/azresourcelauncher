# Create resource group
New-AzResourceGroup -Name "TestRG1" -Location "EastUS"

# Create VNET

$vnet = New-AzVirtualNetwork `
-ResourceGroupName "TestRG1" `
-Location "EastUS" `
-Name "VNet1" `
-AddressPrefix 10.1.0.0/16

# Create subnets

$subnetConfigFrontend = Add-AzVirtualNetworkSubnetConfig `
  -Name Frontend `
  -AddressPrefix 10.1.0.0/24 `
  -VirtualNetwork $vnet

$subnetConfigGW = Add-AzVirtualNetworkSubnetConfig `
  -Name GatewaySubnet `
  -AddressPrefix 10.1.255.0/27 `
  -VirtualNetwork $vnet

  $vnet | Set-AzVirtualNetwork

# Request public IP address

$gwpip = New-AzPublicIpAddress -Name "GatewayIP" -ResourceGroupName "TestRG1" -Location "EastUS" -AllocationMethod Static -Sku Standard

$vnet = Get-AzVirtualNetwork -Name "VNet1" -ResourceGroupName "TestRG1"
$gwsubnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet
$gwipconfig = New-AzVirtualNetworkGatewayIpConfig -Name gwipconfig1 -SubnetId $gwsubnet.Id -PublicIpAddressId $gwpip.Id

# Create VPN Gateway

New-AzVirtualNetworkGateway -Name "VNet1GW" -ResourceGroupName "TestRG1" `
-Location "EastUS" -IpConfigurations $gwipconfig -GatewayType Vpn `
-VpnType RouteBased -EnableBgp $false -GatewaySku VpnGw2 -VpnGatewayGeneration "Generation2" -VpnClientProtocol IkeV2,OpenVPN

Get-AzVirtualNetworkGateway -Name VNet1GW -ResourceGroup TestRG1

# Add a VPN client address pool

$VNetName  = "VNet1"
$VPNClientAddressPool = "172.16.201.0/24"
$RG = "TestRG1"
$Location = "EastUS"
$GWName = "VNet1GW"

$Gateway = Get-AzVirtualNetworkGateway -ResourceGroupName $RG -Name $GWName
Set-AzVirtualNetworkGateway -VirtualNetworkGateway $Gateway -VpnClientAddressPool $VPNClientAddressPool

# Generate certificate (MacOS)
## generates a 2048-bit (recommended) RSA private key.
openssl genrsa -out key.pem 2048
##  generates a Certificate Signing Request, which you could instead use to generate a CA-signed certificate. This step will ask you questions; be as accurate as you like since you probably aren’t getting this signed by a CA.
openssl req -new -sha256 -key key.pem -out csr.csr
## generates a self-signed x509 certificate suitable for use on web servers. This is the file you were after all along, congrats!
openssl req -x509 -sha256 -days 365 -key key.pem -in csr.csr -out certificate.pem
## ensures you will be able to use your certificate beyond 2016. OpenSSL on OS X is currently insufficient, and will silently generate a SHA-1 certificate that will be rejected by browsers in 2017. Update using your package manager, or with Homebrew on a Mac and start the process over
openssl req -in csr.csr -text -noout | grep -i "Signature.*SHA256" && echo "All is well" || echo "This certificate will stop working in 2017! You must update OpenSSL to generate a widely-compatible certificate"

# Upload root certificate public key information

# Declare the variable for your certificate name, replacing the value with your own
$P2SRootCertName = "P2SRootCert.cer"

# Replace the file path with your own, and then run the cmdlets
$filePathForCert = "C:\cert\P2SRootCert.cer"
$cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate2($filePathForCert)
$CertBase64 = [system.convert]::ToBase64String($cert.RawData)

# Upload the public key information to Azure. Once the certificate information is uploaded, Azure considers it to be a trusted root certificate. 
Add-AzVpnClientRootCertificate -VpnClientRootCertificateName $P2SRootCertName -VirtualNetworkGatewayname "VNet1GW" -ResourceGroupName "TestRG1" -PublicCertData $CertBase64

# Follow steps at https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-vpn-client-cert-mac#ikev2-native-vpn-client---macos-steps


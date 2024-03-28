pwsh
Get-AzDisk | Select-Object -Property Name, ResourceGroupName, DiskSizeGB, @{Name = 'DiskType'; Expression = {$_.sku.name}}
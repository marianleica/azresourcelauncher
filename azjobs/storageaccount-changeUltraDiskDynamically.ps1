$DiskUpdateconfig = New-AzDiskUpdateConfig -DiskIOPSReadWrite $iops
Update-AzDisk -ResourceGroupName $rg -DiskName $diskname -DiskUpdate $DiskUpdateconfig

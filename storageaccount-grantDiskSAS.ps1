$diskSas = Grant-AzDiskAccess -ResourceGroupName $rg -DiskName $diskname -DurationInSeconds 3600 -Access 'Read'
$diskSas
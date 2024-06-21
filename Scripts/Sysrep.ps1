# Run sysprep needs tobe run by custom script extension
Start-Process -FilePath C:\Windows\System32\Sysprep\Sysprep.exe -ArgumentList '/generalize /oobe /quit /quiet'  -Wait
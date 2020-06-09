<#
.DESCRIPTION
    Requires CertifyTheWeb - https://certifytheweb.com/home/download
    Install certificate generated from CertifyTheWeb to MSSQL instances and restart associated instances.
    Script is service impacting as SQL services are restarted. Schedule renewals accordingly.
.NOTES
    Version:        0.2.1
    Last updated:   06/08/2020
    Creation date:  06/01/2020
    Author:         Zachary Choate
    URL:            https://raw.githubusercontent.com/KSMC-TS/letsencrypt-scripts/master/certify/Install-LECertify-MsSql.ps1
#>

param($result)

$thumbprint = $result.ManagedItem.CertificateThumbprintHash

$instanceNames = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
$instances = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server").InstalledInstances

foreach($instance in $instances) {

    $instanceReg = $instanceNames.$instance
    $instanceRegPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceReg\MSSQLServer\SuperSocketNetLib"
    Set-ItemProperty -Path $instanceRegPath -Name "Certificate" -Value $thumbprint -Force

    }

# Get certificate private key path to use to set ACLs later on.
$certificate = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object {$_.thumbprint -eq $thumbprint}
$privateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
$keyFile = $privateKey.Key.UniqueName
$keyPath = "$env:ALLUSERSPROFILE\Microsoft\Crypto\RSA\MachineKeys\$keyFile"

# Get MsSql services
$services = Get-Service | Where-Object {$_.Name -match ($instances -Join "|") -and $_.DisplayName -like "*SQL Server*" -and $_.DisplayName -notlike "*SQL Server Agent*" -and $_.DisplayName -notlike "*SQL Server Analysis Services*"}

foreach($service in $services) {

    # Get service account used to start service
    $acct = Get-WmiObject win32_service | Where-Object {$_.Name -like "$($service.Name)"} | Select-Object StartName

    # Set private key ACLs for service accounts.
    $permissions = Get-Acl -Path $keyPath
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($acct.StartName, 'Read', 'None', 'None', 'Allow')
    $permissions.AddAccessRule($accessRule)
    Set-Acl -Path $keyPath -AclObject $permissions

    # restart services
    Restart-Service $service.Name -Force

    }

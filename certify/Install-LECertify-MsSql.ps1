<#
.DESCRIPTION
    Requires CertifyTheWeb - https://certifytheweb.com/home/download
    Install certificate generated from CertifyTheWeb to MSSQL instances and restart associated instances.
    Script is service impacting as SQL services are restarted. Schedule renewals accordingly.
.NOTES
    Version:        0.1
    Last updated:   06/01/2020
    Creation date:  06/01/2020
    Author:         Zachary Choate
    URL:            https://raw.githubusercontent.com/zchoate/letsencrypt-scripts/master/certify/Install-LECertifyMsSql.ps1
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

$services = Get-Service | Where-Object {$_.Name -match ($instances -Join "|") -and $_.DisplayName -like "*SQL Server*" -and $_.DisplayName -notlike "*SQL Server Agent*" -and $_.DisplayName -notlike "*SQL Server Analysis Services*"}

foreach($service in $services) {

    Restart-Service $service.Name -Force

    }
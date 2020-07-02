<#
.DESCRIPTION
    Requires CertifyTheWeb - https://certifytheweb.com/home/download
    Install certificate generated from CertifyTheWeb NTDS cert store and apply for LDAPS.
    Removes old LDAPS certificates.
.NOTES
    Version:        0.1.1
    Last updated:   06/08/2020
    Creation date:  04/29/2020
    Author:         Zachary Choate
    URL:            https://raw.githubusercontent.com/KSMC-TS/letsencrypt-scripts/main/certify/Install-LECertify-LDAPS.ps1
#>

param($result)

$thumbprint = $result.ManagedItem.CertificateThumbprintHash

# test thumbprint and compare against current certificate installed
If(!(Test-Path "HKLM:\SOFTWARE\Microsoft\Cryptography\Services\NTDS\SystemCertificates\My\Certificates")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Cryptography\Services\NTDS\SystemCertificates\My\Certificates" -Force
} else {
    $currentCerts = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Cryptography\Services\NTDS\SystemCertificates\My\Certificates" -Recurse
    ForEach($currentCert in $currentCerts) {
        If($thumbprint -eq $currentCert.PSChildName) {
            Break
        } else {
            Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Cryptography\Services\NTDS\SystemCertificates\My\Certificates\$($currentCert.PSChildName)" -Force
        }
    }
}

# Copy LDAPS cert to NTDS store for use with LDAPS.
$copyParameters = @{
    'Path' = "HKLM:\Software\Microsoft\SystemCertificates\MY\Certificates\$thumbprint"
    'Destination' = "HKLM:\SOFTWARE\Microsoft\Cryptography\Services\NTDS\SystemCertificates\My\Certificates\$thumbprint"
    'Recurse' = $true
}
Copy-Item @copyParameters

# Apply LDAPS cert.
"dn:
changetype: modify
add: renewServerCertificate
renewServerCertificate: 1
-" | Out-File -FilePath $env:TEMP\ldap-reload.txt

Start-Process ldifde -ArgumentList "-i -f $env:Temp\ldap-reload.txt"

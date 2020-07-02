<#

.DESCRIPTION
    Add certificate from CertifyTheWeb to Fortigate.
    Apply certificate for use on VPN.
    Apply certificate as admin interface certificate.
    Remove old certificate.
.NOTES
    Refer to https://github.com/KSMC-TS/docs/blob/main/fortinet/AutomatedCertificateRenewal/readme.md for setup instructions.

    Updated:    07/02/2020
    Author:     Zach Choate
        
#>

param($result)

$fortigateAddress = "Address/HostnameGoesHere"
$fortigateAdminPort = "PortGoesHere"
$encryptedToken = "PathToTextFileContainingToken"

$apiToken = Get-Content $encryptedToken | ConvertTo-SecureString -Key (1..16)
$sourcePFX = $result.ManagedItem.CertificatePath

# Get PFX and strip private key and export for use to import into Fortigate.
$pfxObject = New-Object -TypeName 'System.Security.Cryptography.X509Certificates.X509Certificate2Collection'
$pfxObject.Import($sourcePfx,$null,[System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet)
$caCert = [System.Convert]::ToBase64String($($pfxObject[0].Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)))

# Get PFX as base64 string
$pfx = [System.Convert]::ToBase64String($(Get-Content $sourcePFX -Encoding Byte))

# Ignore invalid certificate warning
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12

# Define some variables
$baseUrl = "https://$fortigateAddress`:$fortigateAdminPort/api/v2"

# Decrypt the API token for execution, set into the request header, and clear the appropriate variables.
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiToken)
$apiToken = [System.Runtime.INteropServices.Marshal]::PtrToStringAuto($BSTR)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
$requestHeader = @{Authorization="Bearer $apiToken"}
$apiToken = $null

$certName = "$(Get-Date -Format yyyyMMddhhmmss)-LECert"

# Upload new cert
$newCertPath = "/monitor/vpn-certificate/local/import"
$newCertUrl = "$baseUrl$newCertPath"
$newCertBody = @{
    type="pkcs12"
    certname="$certName"
    scope="global"
    file_content="$pfx"
    }
$newCertJson = $newCertBody | ConvertTo-Json

# Upload CA cert
$caCertPath = "/monitor/vpn-certificate/ca/import"
$caCertUrl = "$baseUrl$newCertPath"
$caCertBody = @{
    import_method="file"
    scope="global"
    file_content=$caCert
    }
$caCertJson = $caCertBody | ConvertTo-Json

# Change active cert on VPN
$vpnSettingsPath = "/cmdb/vpn.ssl/settings"
$vpnSettingsUrl = "$baseUrl$vpnSettingsPath"
$vpnSettingsBody = @{
    servercert="$certName"
    }
$vpnSettingsJson = $vpnSettingsBody | ConvertTo-Json

# Change active cert on admin interface
$adminSettingsPath = "/cmdb/system/global"
$adminSettingsUrl = "$baseUrl$adminSettingsPath"
$adminSettingsBody = @{
    'admin-server-cert'="$certName"
    }
$adminSettingsJson = $adminSettingsBody | ConvertTo-Json

# Get current certificate used for VPN
$currentCert = Invoke-RestMethod -Uri $vpnSettingsUrl -Headers $requestHeader -Method Get
$currentCert = $currentCert.results.servercert

# Execute post for uploading new cert
Invoke-RestMethod -Uri $newCertUrl -Headers $requestHeader -Body $newCertJson -Method Post -ContentType 'application/x-www-form-urlencoded'
Start-Sleep -Seconds 1

# Execute post for uploading new CA cert
Try {
    Invoke-RestMethod -Uri $caCertUrl -Headers $requestHeader -Body $caCertJson -Method Post -ContentType 'application/x-www-form-urlencoded' -ErrorAction SilentlyContinue
} catch {
    Write-Output "Intermediate CA cert failed on upload. This is likely a result of it already existing on the Fortigate."
}
Start-Sleep -Seconds 1

# Execute put for updating active vpn cert
Invoke-RestMethod -Uri $vpnSettingsUrl -Headers $requestHeader -Body $vpnSettingsJson -Method Put -ContentType 'application/x-www-form-urlencoded'
Start-Sleep -Seconds 1

# Execute put for updating active admin cert
Try {
    Invoke-RestMethod -Uri $adminSettingsUrl -Headers $requestHeader -Body $adminSettingsJson -Method Put -ContentType 'application/x-www-form-urlencoded' -ErrorAction SilentlyContinue
} catch {
    Write-Output "The connection to $adminSettingsUrl dropped. This is to be expected as it is rebinding the certificate."
}
Start-Sleep -Seconds 5

# Remove old certificate
$deleteCertUrl = "$baseUrl/cmdb/vpn.certificate/local/$currentCert"
Invoke-RestMethod -Uri $deleteCertUrl -Headers $requestHeader -Method Delete

# Clear request header.
$requestHeader = $null

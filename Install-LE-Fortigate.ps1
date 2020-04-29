<#   
    .DESCRIPTION
        Add certificate from CertifyTheWeb to Fortigate.
        Apply certificate for use on VPN.
        Apply certificate as admin interface certificate.
        Remove old certificate.
    .NOTES
        You'll need to encrypt the Fortigate API token for use with this script:
            $token = Read-Host -AsSecureString
            $tokenFile = ConvertFrom-SecureString -SecureString $token -Key (1..16)
            $tokenFile | Set-Content PathToTokenFile.txt
        This will need to be run in the same context that the CertifyTheWeb service is run under (SYSTEM)
        
#>

param($result)

$fortigateAddress = "Address/HostnameGoesHere"
$fortigateAdminPort = "PortGoesHere"
$encryptedToken = "PathToTextFileContainingToken"

$apiToken = Get-Content $encryptedToken | ConvertTo-SecureString -Key (1..16)
$sourcePFX = $result.ManagedItem.CertificatePath

$pfx = Get-Content $sourcePFX -Encoding Byte
$pfx = [System.Convert]::ToBase64String($pfx)

<# Uncomment this section to allow connections to URLs not secured with a trusted certificate.

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

#>

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
$currentCert = Invoke-RestMethod -Uri $updateUrl -Headers $requestHeader -Method Get
$currentCert = $currentCert.results.servercert

# Execute post for uploading new cert
Invoke-RestMethod -Uri $newCertUrl -Headers $requestHeader -Body $newCertJson -Method Post -ContentType 'application/x-www-form-urlencoded'

# Execute put for updating active vpn cert
Invoke-RestMethod -Uri $vpnSettingsUrl -Headers $requestHeader -Body $vpnSettingsJson -Method Put -ContentType 'application/x-www-form-urlencoded'

# Execute put for updating active admin cert
Invoke-RestMethod -Uri $adminSettingsUrl -Headers $requestHeader -Body $adminSettingsJson -Method Put -ContentType 'application/x-www-form-urlencoded' -ErrorAction SilentlyContinue

Start-Sleep -Seconds 5

# Remove old certificate
$deleteCertUrl = "$baseUrl/cmdb/vpn.certificate/local/$currentCert"
Invoke-RestMethod -Uri $deleteCertUrl -Headers $requestHeader -Method Delete

# Clear request header.
$requestHeader = $null
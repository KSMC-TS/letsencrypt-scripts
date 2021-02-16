<#
.DESCRIPTION
    Requires CertifyTheWeb - https://certifytheweb.com/home/download
    Install certificate on SSRS
.NOTES
    Version:        0.1.0
    Last updated:   02/15/2021
    Author:         Zachary Choate
#>

param($result)

$thumbprint = $result.ManagedItem.CertificateThumbprintHash

# specify the SRSS instance name - can be found by running Get-WmiObject -namespace root\Microsoft\SqlServer\ReportServer -class __Namespace
$rsInstance = "RS_SRSS"

$rsName     = (Get-WmiObject -namespace root\Microsoft\SqlServer\ReportServer -Filter "Name=$rsInstance" -class __Namespace).name
$rsVersion  = (Get-WmiObject -namespace root\Microsoft\SqlServer\ReportServer\$rsName -class __Namespace).name
$rsConfig   = Get-WmiObject -namespace root\Microsoft\SqlServer\ReportServer\$rsName\$rsVersion -class MSReportServer_ConfigurationSetting

# get current thumbprint to remove if new certificate exists
$currentThumbprint = $rsConfig.ListSSLCertificateBindings(1033).CertificateHash.Item([array]::LastIndexOf($rsConfig.ListSSLCertificateBindings(1033).Application, 'ReportServerWebService'))

if($currentThumbprint -ne $thumbprint) {
    $rsConfig.RemoveSSLCertificateBindings('ReportManager', $currentThumbprint, "0.0.0.0", 443, 1033)
    $rsConfig.RemoveSSLCertificateBindings('ReportServerWebService', $currentThumbprint, "0.0.0.0", 443, 1033)
    $rsConfig.CreateSSLCertificateBindings('ReportManager', $thumbprint, "0.0.0.0", 443, 1033)
    $rsConfig.CreateSSLCertificateBindings('ReportServerWebService', $thumbprint, "0.0.0.0", 443, 1033)
}
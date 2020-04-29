<#
.DESCRIPTION
  This script will install certificates for an RDS environment.
  This script is dependent on CertifyTheWeb - download here: https://certifytheweb.com/home/download.
  Run this script outside of production hours by disabling the Certify service until a brief interruption is tolerated in RDS.
#>

param($result)

Import-Module RemoteDesktopServices
Import-Module RemoteDesktop

#Set the certificate for the 4 core RDS services
Set-RDCertificate -Role RDGateway -ImportPath $result.ManagedItem.CertificatePath -Force
Set-RDCertificate -Role RDWebAccess -ImportPath $result.ManagedItem.CertificatePath -Force
Set-RDCertificate -Role RDRedirector -ImportPath $result.ManagedItem.CertificatePath -Force
Set-RDCertificate -Role RDPublishing -ImportPath $result.ManagedItem.CertificatePath -Force

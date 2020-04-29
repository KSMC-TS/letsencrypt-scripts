param($result)

Import-Module RemoteDesktopServices
Import-Module RemoteDesktop

#Set the certificate for the 4 core RDS services
Set-RDCertificate -Role RDGateway -ImportPath $result.ManagedItem.CertificatePath -Force
Set-RDCertificate -Role RDWebAccess -ImportPath $result.ManagedItem.CertificatePath -Force
Set-RDCertificate -Role RDRedirector -ImportPath $result.ManagedItem.CertificatePath -Force
Set-RDCertificate -Role RDPublishing -ImportPath $result.ManagedItem.CertificatePath -Force
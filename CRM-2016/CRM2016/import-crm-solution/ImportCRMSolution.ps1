#
# ImportCRMSolution.ps1
#
[CmdletBinding(DefaultParameterSetName = 'None')]
param(
    [Parameter(mandatory=$true)]
    [string]$UserName,
    [Parameter(mandatory=$true)]
    [string]$UserPwd,
    [Parameter(mandatory=$true)]
    [string]$CRMSvrUrl,
    [Parameter(mandatory=$true)]
    [string]$CRMOrgName,
    [Parameter(mandatory=$true)]
    [string]$CRMSolutionName,
    [Parameter(mandatory=$true)]
    [string]$SolutionZipFilePath,
    [Parameter(mandatory=$true)]
    [string] $CRMSolutionManaged,
    [Parameter(mandatory=$true)]
    [int]$SolutionImportWaitSeconds
   )

$ErrorActionPreference = "Stop"
Write-Host "Version 1.1.7"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 

Import-Module $PSScriptRoot\PSModules\Microsoft.Xrm.Data.PowerShell -Verbose:$false -WarningAction SilentlyContinue

Write-Host "Connecting to $CRMSvrUrl $CRMOrgName ... "

$secpasswd = ConvertTo-SecureString $UserPwd -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($UserName, $secpasswd)

$crmcon = Get-CrmConnection -ServerUrl $CRMSvrUrl -OrganizationName $CRMOrgName -Credential $cred  -Verbose #-Timeout $CRMTimeout

Write-Host "CRM connection obtained."



$SolutionZipFilePath = Resolve-Path $SolutionZipFilePath 
if($CRMSolutionManaged.ToLower() -eq "true")
{
    Write-Host ("Importing Managed CRM Solution: {0} with file: {1} ..." -f $CRMSolutionName, $SolutionZipFilePath) 
}
else
{
    Write-Host ("Importing Unmanaged CRM Solution: {0} with file: {1} ..." -f $CRMSolutionName, $SolutionZipFilePath) 
}

try{
	#Try importing with override customizations    
	Import-CrmSolution -conn $crmcon -SolutionFilePath $SolutionZipFilePath -MaxWaitTimeInSeconds $SolutionImportWaitSeconds -OverwriteUnManagedCustomizations -ActivatePlugIns -PublishChanges -Verbose
	Write-Host ("Importing completed for CRM solution: {0} with file: {1}." -f $CRMSolutionName, $SolutionZipFilePath)	

				

}Catch {

    if($CRMSolutionManaged.ToLower() -eq "true") # only try hold import if this is a managed solution
    {
		Write-Warning ("##vso[task.logissue type=warning;]Importing failed for CRM Solution: {0} with file: {1}." -f $CRMSolutionName, $SolutionZipFilePath)
        Write-Warning ("##vso[task.logissue type=warning;]{0}" -f $_.Exception)
								
		Write-Host "--------------------------------------------------------------------------------------------"
		Write-Warning ("##vso[task.logissue type=warning;]Trying import with hold promote mechanism for CRM Solution: {0} with file {1}." -f $CRMSolutionName, $SolutionZipFilePath)
		Import-CrmSolution -conn $crmcon -SolutionFilePath $SolutionZipFilePath -MaxWaitTimeInSeconds $SolutionImportWaitSeconds -ImportAsHoldingSolution -ActivatePlugIns -PublishChanges -Verbose
		Write-Host ("Importing with hold completed for CRM Solution: {0} with file {1}." -f $CRMSolutionName, $SolutionZipFilePath)	
		Write-Host "--------------------------------------------------------------------------------------------"
				
		Write-Host ("Promoting CRM Solution {0} ." -f $CRMSolutionName)	
		DeleteAndPromote-CrmSolution -conn $crmcon -SolutionName $CRMSolutionName -MaxWaitTimeInSeconds $SolutionImportWaitSeconds -Verbose
		Write-Host ("Promoting CRM Solution {0} ." -f $CRMSolutionName)	

		}
}

Remove-Module Microsoft.Xrm.Data.PowerShell -Verbose:$false
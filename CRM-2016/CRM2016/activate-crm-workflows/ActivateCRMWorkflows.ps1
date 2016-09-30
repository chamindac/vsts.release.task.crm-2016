param(
    [Parameter(mandatory=$true)]
    [string]$UserName,
    [Parameter(mandatory=$true)]
    [string]$UserPwd,
    [Parameter(mandatory=$true)]
    [string]$CRMSvrUrl,
    [Parameter(mandatory=$true)]
    [string]$CRMOrgName,
    [string[]]$wfIdsToDeactivate    
   )

$ErrorActionPreference = "Stop"

Write-Host "Version 1.1.5"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 

Import-Module $PSScriptRoot\PSModules\Microsoft.Xrm.Data.PowerShell -Verbose:$false -WarningAction SilentlyContinue

Write-Host "Connecting to $CRMSvrUrl $CRMOrgName ... "

$secpasswd = ConvertTo-SecureString $UserPwd -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($UserName, $secpasswd)

$crmcon = Get-CrmConnection -ServerUrl $CRMSvrUrl -OrganizationName $CRMOrgName -Credential $cred  -Verbose #-Timeout $CRMTimeout

Write-Host "CRM connection obtained."

$workfows = Get-CrmRecords -EntityLogicalName "workflow" -conn $crmcon -Fields "workflowid","name","statecode","statuscode" -WarningAction SilentlyContinue

Write-Host ("Total workflows found:{0}" -f $workfows.CrmRecords.count)

$activateStatecodeStatus = "Activated"
$activateStatuscodeStatusReason = "Activated"
$deactivateStatecodeStatus = "Draft"
$deactivateStatuscodeStatusReason = "Draft"

$ActivatedCount=0
$DeactivatedCount=0
$ActivationFailsCount=0
$DeactivationFailsCount=0
$ActivationSkipCount=0
$DeactivationSkipCount=0
$ActivationUnknownCount=0
$DeactivationUnknownCount=0

foreach($workflow in  $workfows.CrmRecords)
{
    if (($wfIdsToDeactivate -ne $null) -and $wfIdsToDeactivate.Contains($workflow.workflowid.Guid))
    {
        # Deactivating workflow since set to deativate
        if ($workflow.statecode -eq $activateStatecodeStatus)
        {   try{ 
                Write-Host ("Deactivating... workflow with id:{0} have statecode:{1} statuscode:{2}, name:{3}" -f $workflow.workflowid, $workflow.statecode, $workflow.statuscode, $workflow.name)
                Set-CrmRecordState -conn $crmcon -CrmRecord $workflow -StateCode $deactivateStatecodeStatus -StatusCode $deactivateStatuscodeStatusReason -Verbose
                Write-Warning ("##vso[task.logissue type=warning;]Deactivated workflow with id:{0}, name:{1}" -f $workflow.workflowid, $workflow.name)
                $DeactivatedCount=$DeactivatedCount+1
            }
            catch{
                Write-Warning ("##vso[task.logissue type=warning;]{0}" -f $crmcon.LastCrmError) 
                $DeactivationFailsCount=$DeactivationFailsCount+1
            }
        }
        elseif($workflow.statecode -eq $deactivateStatecodeStatus)
        {
            Write-Host ("Already deactivated - workflow with id:{0}, name:{1}" -f $workflow.workflowid, $workflow.name)
            $DeactivationSkipCount=$DeactivationSkipCount+1
        }
        else
        {
            Write-Warning ("##vso[task.logissue type=warning;]Workflow with id:{0} have statecode:{1} statuscode:{2}, name:{3}" -f $workflow.workflowid, $workflow.statecode, $workflow.statuscode, $workflow.name)
            $DeactivationUnknownCount=$DeactivationUnknownCount+1
        }
    }
    elseif($workflow.statecode -eq $activateStatecodeStatus)
    {
        Write-Host ("Already activated - workflow with id:{0}, name:{1}" -f $workflow.workflowid, $workflow.name)
        $ActivationSkipCount=$ActivationSkipCount+1
    }
    elseif($workflow.statecode -eq $deactivateStatecodeStatus)
    {
        # 0,1 to 1,2 (state,status) to activate
        
        try{
            Write-Host ("Activating... workflow with id:{0} have statecode:{1} statuscode:{2}, name:{3}" -f $workflow.workflowid, $workflow.statecode, $workflow.statuscode, $workflow.name)
            Set-CrmRecordState -conn $crmcon -CrmRecord $workflow -StateCode $activateStatecodeStatus -StatusCode $activateStatuscodeStatusReason -Verbose
            Write-Host ("Activated workflow with id:{0}, name:{1}" -f $workflow.workflowid, $workflow.name)
            $ActivatedCount=$ActivatedCount+1
        }
        catch{
            Write-Warning ("##vso[task.logissue type=warning;]{0}" -f $crmcon.LastCrmError)
            $ActivationFailsCount=$ActivationFailsCount+1 
        }
    }
    else{
        Write-Warning ("##vso[task.logissue type=warning;]Workflow with id:{0} have statecode:{1} statuscode:{2}, name:{3}" -f $workflow.workflowid, $workflow.statecode, $workflow.statuscode, $workflow.name)
        $ActivationUnknownCount=$ActivationUnknownCount+1
    }    
}

Write-Host "-------------------------------------------------------"
Write-Host ("Total workflows processed:{0}" -f $workfows.CrmRecords.count)
Write-Host "-------------------------------------------------------"
Write-Host ("Activated: {0}, Already Activated:{1}, Total Activated:{2}" -f $ActivatedCount, $ActivationSkipCount, ($ActivatedCount + $ActivationSkipCount))
if($wfIdsToDeactivate -ne $null)
{
    Write-Host ("Deactivated: {0}, Already Deactivated:{1}, Total Deactivated:{2}" -f $DeactivatedCount, $DeactivationSkipCount, ($DeactivatedCount + $DeactivationSkipCount))
}
if($ActivationFailsCount -gt 0)
{
    Write-Warning ("##vso[task.logissue type=warning;]Activation fails for {0} workflows. check detailed log for reasons." -f $ActivationFailsCount)
}
if($DeactivationFailsCount -gt 0)
{
    Write-Warning ("##vso[task.logissue type=warning;]Deactivation fails for {0} workflows. check detailed log for reasons." -f $DeactivationFailsCount)
}
if($ActivationUnknownCount -gt 0)
{
    Write-Warning ("##vso[task.logissue type=warning;]Activation unknown status for {0} workflows. check detailed log for reasons." -f $ActivationUnknownCount)
}
if($DeactivationUnknownCount -gt 0)
{
    Write-Warning ("##vso[task.logissue type=warning;]Deactivation unknown status for {0} workflows. check detailed log for reasons." -f $DeactivationUnknownCount)
}
Write-Host "-------------------------------------------------------"

Remove-Module Microsoft.Xrm.Data.PowerShell -Verbose:$false
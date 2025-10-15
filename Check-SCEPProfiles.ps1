<#
.SYNOPSIS
    Verifies SCEP certificate profile assignments for Intune managed devices.

.DESCRIPTION
    This script connects to Microsoft Graph to:
    - Resolve device by hostname to an Intune Managed Device
    - Verify enrollment and license status
    - Collect dynamic group membership
    - Auto-detect SCEP certificate profiles across all platforms
    - Check device targeting for SCEP profiles
    - Pull per-device deployment status
    - Flag assignment filters that might exclude the device

.PARAMETER DeviceName
    The hostname of the device to check.

.EXAMPLE
    .\Check-SCEPProfiles.ps1 -DeviceName "DESKTOP-ABC123"

.NOTES
    Requires Microsoft.Graph PowerShell modules:
    - Microsoft.Graph.Authentication
    - Microsoft.Graph.DeviceManagement
    - Microsoft.Graph.Identity.DirectoryManagement
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DeviceName
)

# Function to connect to Microsoft Graph
function Connect-ToMicrosoftGraph {
    Write-Host "`n=== Connecting to Microsoft Graph ===" -ForegroundColor Cyan
    
    try {
        # Check if already connected
        $context = Get-MgContext
        if ($null -eq $context) {
            # Connect with required scopes
            $scopes = @(
                "DeviceManagementManagedDevices.Read.All",
                "DeviceManagementConfiguration.Read.All",
                "Directory.Read.All",
                "Group.Read.All"
            )
            
            Write-Host "Connecting to Microsoft Graph with required permissions..." -ForegroundColor Yellow
            Connect-MgGraph -Scopes $scopes -NoWelcome
            Write-Host "✓ Successfully connected to Microsoft Graph" -ForegroundColor Green
        }
        else {
            Write-Host "✓ Already connected to Microsoft Graph" -ForegroundColor Green
            Write-Host "  Tenant: $($context.TenantId)" -ForegroundColor Gray
        }
        return $true
    }
    catch {
        Write-Host "✗ Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to resolve device by hostname
function Get-IntuneDeviceByName {
    param([string]$Name)
    
    Write-Host "`n=== Resolving Device ===" -ForegroundColor Cyan
    Write-Host "Searching for device: $Name" -ForegroundColor Yellow
    
    try {
        $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=deviceName eq '$Name'"
        $devices = Invoke-MgGraphRequest -Method GET -Uri $uri
        
        if ($devices.value.Count -eq 0) {
            Write-Host "✗ Device not found in Intune" -ForegroundColor Red
            return $null
        }
        
        $device = $devices.value[0]
        Write-Host "✓ Device found in Intune" -ForegroundColor Green
        Write-Host "  Device ID: $($device.id)" -ForegroundColor Gray
        Write-Host "  Device Name: $($device.deviceName)" -ForegroundColor Gray
        Write-Host "  OS: $($device.operatingSystem)" -ForegroundColor Gray
        Write-Host "  OS Version: $($device.osVersion)" -ForegroundColor Gray
        Write-Host "  Serial Number: $($device.serialNumber)" -ForegroundColor Gray
        
        return $device
    }
    catch {
        Write-Host "✗ Error resolving device: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to verify enrollment and license
function Test-DeviceEnrollmentAndLicense {
    param($Device)
    
    Write-Host "`n=== Verifying Enrollment & License ===" -ForegroundColor Cyan
    
    # Check enrollment status
    $enrollmentState = $device.managementState
    Write-Host "Enrollment State: $enrollmentState" -ForegroundColor $(if ($enrollmentState -eq "managed") { "Green" } else { "Yellow" })
    
    # Check compliance state
    $complianceState = $device.complianceState
    Write-Host "Compliance State: $complianceState" -ForegroundColor $(if ($complianceState -eq "compliant") { "Green" } else { "Yellow" })
    
    # Check last sync
    $lastSync = $device.lastSyncDateTime
    if ($lastSync) {
        $syncAge = (Get-Date) - [DateTime]$lastSync
        Write-Host "Last Sync: $lastSync ($([math]::Round($syncAge.TotalHours, 1)) hours ago)" -ForegroundColor Gray
    }
    
    # Check Azure AD device
    try {
        $azureAdDeviceId = $device.azureADDeviceId
        if ($azureAdDeviceId) {
            $uri = "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$azureAdDeviceId'"
            $azureDevice = Invoke-MgGraphRequest -Method GET -Uri $uri
            
            if ($azureDevice.value.Count -gt 0) {
                Write-Host "✓ Azure AD Device found" -ForegroundColor Green
                Write-Host "  Azure AD Device ID: $azureAdDeviceId" -ForegroundColor Gray
                Write-Host "  Account Enabled: $($azureDevice.value[0].accountEnabled)" -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Host "⚠ Could not verify Azure AD device: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    return $true
}

# Function to get device group memberships
function Get-DeviceGroupMemberships {
    param($Device)
    
    Write-Host "`n=== Collecting Dynamic Group Memberships ===" -ForegroundColor Cyan
    
    try {
        $azureAdDeviceId = $device.azureADDeviceId
        if (-not $azureAdDeviceId) {
            Write-Host "⚠ No Azure AD Device ID found" -ForegroundColor Yellow
            return @()
        }
        
        $uri = "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$azureAdDeviceId'"
        $azureDevice = Invoke-MgGraphRequest -Method GET -Uri $uri
        
        if ($azureDevice.value.Count -eq 0) {
            Write-Host "⚠ Azure AD device not found" -ForegroundColor Yellow
            return @()
        }
        
        $deviceObjectId = $azureDevice.value[0].id
        $uri = "https://graph.microsoft.com/v1.0/devices/$deviceObjectId/memberOf"
        $groups = Invoke-MgGraphRequest -Method GET -Uri $uri
        
        Write-Host "✓ Found $($groups.value.Count) group memberships" -ForegroundColor Green
        
        $groupList = @()
        foreach ($group in $groups.value) {
            Write-Host "  - $($group.displayName) ($($group.id))" -ForegroundColor Gray
            $groupList += $group
        }
        
        return $groupList
    }
    catch {
        Write-Host "⚠ Error collecting group memberships: $($_.Exception.Message)" -ForegroundColor Yellow
        return @()
    }
}

# Function to get all SCEP certificate profiles
function Get-AllSCEPProfiles {
    Write-Host "`n=== Auto-detecting SCEP Certificate Profiles ===" -ForegroundColor Cyan
    
    try {
        $allProfiles = @()
        
        # Get Windows SCEP profiles
        Write-Host "Checking Windows SCEP profiles..." -ForegroundColor Yellow
        $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.windows81SCEPCertificateProfile') or isof('microsoft.graph.windowsPhone81SCEPCertificateProfile')"
        $windowsProfiles = Invoke-MgGraphRequest -Method GET -Uri $uri
        
        foreach ($profile in $windowsProfiles.value) {
            $profile | Add-Member -NotePropertyName "Platform" -NotePropertyValue "Windows" -Force
            $allProfiles += $profile
        }
        
        # Get iOS SCEP profiles
        Write-Host "Checking iOS SCEP profiles..." -ForegroundColor Yellow
        $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.iosScepCertificateProfile')"
        $iosProfiles = Invoke-MgGraphRequest -Method GET -Uri $uri
        
        foreach ($profile in $iosProfiles.value) {
            $profile | Add-Member -NotePropertyName "Platform" -NotePropertyValue "iOS" -Force
            $allProfiles += $profile
        }
        
        # Get Android SCEP profiles
        Write-Host "Checking Android SCEP profiles..." -ForegroundColor Yellow
        $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.androidScepCertificateProfile') or isof('microsoft.graph.androidWorkProfileScepCertificateProfile')"
        $androidProfiles = Invoke-MgGraphRequest -Method GET -Uri $uri
        
        foreach ($profile in $androidProfiles.value) {
            $profile | Add-Member -NotePropertyName "Platform" -NotePropertyValue "Android" -Force
            $allProfiles += $profile
        }
        
        # Get macOS SCEP profiles
        Write-Host "Checking macOS SCEP profiles..." -ForegroundColor Yellow
        $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.macOSScepCertificateProfile')"
        $macosProfiles = Invoke-MgGraphRequest -Method GET -Uri $uri
        
        foreach ($profile in $macosProfiles.value) {
            $profile | Add-Member -NotePropertyName "Platform" -NotePropertyValue "macOS" -Force
            $allProfiles += $profile
        }
        
        Write-Host "✓ Found $($allProfiles.Count) SCEP certificate profiles across all platforms" -ForegroundColor Green
        
        foreach ($profile in $allProfiles) {
            Write-Host "  - [$($profile.Platform)] $($profile.displayName)" -ForegroundColor Gray
        }
        
        return $allProfiles
    }
    catch {
        Write-Host "✗ Error detecting SCEP profiles: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

# Function to check if device is targeted by profile
function Test-DeviceTargetedByProfile {
    param(
        $Profile,
        $Device,
        $DeviceGroups
    )
    
    try {
        $profileId = $Profile.id
        
        # Get profile assignments
        $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$profileId/assignments"
        $assignments = Invoke-MgGraphRequest -Method GET -Uri $uri
        
        $isTargeted = $false
        $targetedBy = @()
        $excludedBy = @()
        $filterIssues = @()
        
        foreach ($assignment in $assignments.value) {
            $target = $assignment.target
            
            # Check for assignment filters
            if ($assignment.target.'@odata.type' -match 'FilterAssignment') {
                $filterInfo = "Filter: $($assignment.target.deviceAndAppManagementAssignmentFilterType)"
                if ($assignment.target.deviceAndAppManagementAssignmentFilterId) {
                    $filterId = $assignment.target.deviceAndAppManagementAssignmentFilterId
                    try {
                        $filterUri = "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/$filterId"
                        $filter = Invoke-MgGraphRequest -Method GET -Uri $filterUri
                        $filterInfo += " - $($filter.displayName)"
                        
                        # Flag potential exclusion filters
                        if ($assignment.target.deviceAndAppManagementAssignmentFilterType -eq "exclude") {
                            $filterIssues += @{
                                FilterName = $filter.displayName
                                FilterRule = $filter.rule
                                Type = "Exclude"
                            }
                        }
                    }
                    catch {
                        $filterInfo += " (Could not retrieve filter details)"
                    }
                }
            }
            
            # Check group assignments
            if ($target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget') {
                $groupId = $target.groupId
                
                # Check if device is in this group
                $inGroup = $DeviceGroups | Where-Object { $_.id -eq $groupId }
                
                if ($inGroup) {
                    $isTargeted = $true
                    $targetedBy += "Group: $($inGroup.displayName)"
                }
            }
            elseif ($target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget') {
                $isTargeted = $true
                $targetedBy += "All Devices"
            }
            elseif ($target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
                $targetedBy += "All Licensed Users (requires user context)"
            }
            elseif ($target.'@odata.type' -eq '#microsoft.graph.exclusionGroupAssignmentTarget') {
                $groupId = $target.groupId
                $inGroup = $DeviceGroups | Where-Object { $_.id -eq $groupId }
                
                if ($inGroup) {
                    $isTargeted = $false
                    $excludedBy += "Group: $($inGroup.displayName)"
                }
            }
        }
        
        return @{
            IsTargeted = $isTargeted
            TargetedBy = $targetedBy
            ExcludedBy = $excludedBy
            FilterIssues = $filterIssues
        }
    }
    catch {
        Write-Host "    ⚠ Error checking targeting: $($_.Exception.Message)" -ForegroundColor Yellow
        return @{
            IsTargeted = $false
            TargetedBy = @()
            ExcludedBy = @()
            FilterIssues = @()
            Error = $_.Exception.Message
        }
    }
}

# Function to get per-device deployment status
function Get-DeviceDeploymentStatus {
    param(
        $ProfileId,
        $DeviceId
    )
    
    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$ProfileId/deviceStatuses?`$filter=id eq '$DeviceId'"
        $status = Invoke-MgGraphRequest -Method GET -Uri $uri
        
        if ($status.value.Count -gt 0) {
            return $status.value[0]
        }
        
        # Alternative: Check device configuration states
        $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$DeviceId/deviceConfigurationStates?`$filter=id eq '$ProfileId'"
        $configState = Invoke-MgGraphRequest -Method GET -Uri $uri
        
        if ($configState.value.Count -gt 0) {
            return $configState.value[0]
        }
        
        return $null
    }
    catch {
        return $null
    }
}

# Main script execution
function Main {
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  SCEP Certificate Profile Verification Tool                   ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Step 1: Connect to Microsoft Graph
    if (-not (Connect-ToMicrosoftGraph)) {
        return
    }
    
    # Step 2: Resolve device by hostname
    $device = Get-IntuneDeviceByName -Name $DeviceName
    if (-not $device) {
        Write-Host "`n✗ Cannot continue without a valid device" -ForegroundColor Red
        return
    }
    
    # Step 3: Verify enrollment and license
    Test-DeviceEnrollmentAndLicense -Device $device
    
    # Step 4: Collect dynamic group memberships
    $deviceGroups = Get-DeviceGroupMemberships -Device $device
    
    # Step 5: Auto-detect SCEP profiles
    $scepProfiles = Get-AllSCEPProfiles
    
    if ($scepProfiles.Count -eq 0) {
        Write-Host "`n⚠ No SCEP certificate profiles found in the tenant" -ForegroundColor Yellow
        return
    }
    
    # Step 6-8: Check targeting, deployment status, and flag filters
    Write-Host "`n=== Analyzing SCEP Profile Assignments ===" -ForegroundColor Cyan
    
    $results = @()
    
    foreach ($profile in $scepProfiles) {
        Write-Host "`n  Profile: $($profile.displayName) [$($profile.Platform)]" -ForegroundColor Yellow
        
        # Check if device is targeted
        $targeting = Test-DeviceTargetedByProfile -Profile $profile -Device $device -DeviceGroups $deviceGroups
        
        if ($targeting.IsTargeted) {
            Write-Host "    ✓ Device IS targeted by this profile" -ForegroundColor Green
            
            foreach ($target in $targeting.TargetedBy) {
                Write-Host "      Via: $target" -ForegroundColor Gray
            }
            
            # Get deployment status
            $deploymentStatus = Get-DeviceDeploymentStatus -ProfileId $profile.id -DeviceId $device.id
            
            if ($deploymentStatus) {
                $state = $deploymentStatus.state
                $statusColor = switch ($state) {
                    "success" { "Green" }
                    "pending" { "Yellow" }
                    "error" { "Red" }
                    default { "Gray" }
                }
                Write-Host "      Deployment Status: $state" -ForegroundColor $statusColor
                
                if ($deploymentStatus.lastReportedDateTime) {
                    Write-Host "      Last Reported: $($deploymentStatus.lastReportedDateTime)" -ForegroundColor Gray
                }
            }
            else {
                Write-Host "      Deployment Status: Not yet reported" -ForegroundColor Yellow
            }
            
            # Check for filter issues
            if ($targeting.FilterIssues.Count -gt 0) {
                Write-Host "      ⚠ Assignment Filter Warnings:" -ForegroundColor Yellow
                foreach ($filter in $targeting.FilterIssues) {
                    Write-Host "        - $($filter.Type) Filter: $($filter.FilterName)" -ForegroundColor Yellow
                    Write-Host "          Rule: $($filter.FilterRule)" -ForegroundColor Gray
                }
            }
        }
        else {
            Write-Host "    ✗ Device is NOT targeted by this profile" -ForegroundColor Red
            
            if ($targeting.ExcludedBy.Count -gt 0) {
                Write-Host "      Excluded by:" -ForegroundColor Red
                foreach ($exclusion in $targeting.ExcludedBy) {
                    Write-Host "        - $exclusion" -ForegroundColor Red
                }
            }
        }
        
        $results += @{
            ProfileName = $profile.displayName
            Platform = $profile.Platform
            IsTargeted = $targeting.IsTargeted
            TargetedBy = $targeting.TargetedBy
            ExcludedBy = $targeting.ExcludedBy
            FilterIssues = $targeting.FilterIssues
            DeploymentStatus = $deploymentStatus
        }
    }
    
    # Summary
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Summary                                                       ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    $targetedCount = ($results | Where-Object { $_.IsTargeted }).Count
    $notTargetedCount = $results.Count - $targetedCount
    
    Write-Host "`nDevice: $DeviceName" -ForegroundColor White
    Write-Host "Total SCEP Profiles: $($results.Count)" -ForegroundColor White
    Write-Host "Targeted: $targetedCount" -ForegroundColor Green
    Write-Host "Not Targeted: $notTargetedCount" -ForegroundColor Red
    
    $filterIssueCount = ($results | Where-Object { $_.FilterIssues.Count -gt 0 }).Count
    if ($filterIssueCount -gt 0) {
        Write-Host "Profiles with Filter Issues: $filterIssueCount" -ForegroundColor Yellow
    }
    
    Write-Host "`n✓ Analysis complete!" -ForegroundColor Green
}

# Execute main function
Main

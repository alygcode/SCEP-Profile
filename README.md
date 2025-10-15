# SCEP Certificate Profile Verification Tool

A PowerShell tool for verifying SCEP certificate profile assignments and deployment status for Intune managed devices.

## Features

This tool provides comprehensive analysis of SCEP certificate profiles for your Intune managed devices:

- **Microsoft Graph Integration**: Connects to Microsoft Graph (Intune/Entra ID) with appropriate permissions
- **Device Resolution**: Resolves your device by hostname to an Intune Managed Device
- **Enrollment Verification**: Verifies device enrollment status and license
- **Group Membership Analysis**: Collects dynamic group membership against SCEP profile assignments
- **Multi-Platform Support**: Auto-detects all SCEP certificate profiles across platforms (Windows, iOS, Android, macOS)
- **Targeting Verification**: Checks whether the device is actually targeted by each profile
- **Deployment Status**: Pulls per-device deployment status for SCEP profiles
- **Filter Detection**: Flags assignment filters that might exclude the device

## Prerequisites

### Required PowerShell Modules

Install the Microsoft Graph PowerShell modules:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
```

### Required Permissions

The script requires the following Microsoft Graph API permissions:
- `DeviceManagementManagedDevices.Read.All`
- `DeviceManagementConfiguration.Read.All`
- `Directory.Read.All`
- `Group.Read.All`

These permissions will be requested when you first run the script and connect to Microsoft Graph.

## Usage

### Basic Usage

Run the script with the device name you want to check:

```powershell
.\Check-SCEPProfiles.ps1 -DeviceName "DESKTOP-ABC123"
```

### Example Output

```
╔════════════════════════════════════════════════════════════════╗
║  SCEP Certificate Profile Verification Tool                   ║
╚════════════════════════════════════════════════════════════════╝

=== Connecting to Microsoft Graph ===
Connecting to Microsoft Graph with required permissions...
✓ Successfully connected to Microsoft Graph

=== Resolving Device ===
Searching for device: DESKTOP-ABC123
✓ Device found in Intune
  Device ID: 12345678-1234-1234-1234-123456789abc
  Device Name: DESKTOP-ABC123
  OS: Windows
  OS Version: 10.0.19045

=== Verifying Enrollment & License ===
Enrollment State: managed
Compliance State: compliant
Last Sync: 2025-10-15T10:30:00Z (2.5 hours ago)
✓ Azure AD Device found

=== Collecting Dynamic Group Memberships ===
✓ Found 3 group memberships
  - All Windows Devices (abcd-1234-...)
  - Corporate Devices (efgh-5678-...)
  - Certificate Users (ijkl-9012-...)

=== Auto-detecting SCEP Certificate Profiles ===
Checking Windows SCEP profiles...
Checking iOS SCEP profiles...
Checking Android SCEP profiles...
Checking macOS SCEP profiles...
✓ Found 5 SCEP certificate profiles across all platforms
  - [Windows] Corporate WiFi Certificate
  - [Windows] VPN Certificate
  - [iOS] Mobile Device Certificate
  - [Android] Enterprise Certificate
  - [macOS] Mac Corporate Certificate

=== Analyzing SCEP Profile Assignments ===

  Profile: Corporate WiFi Certificate [Windows]
    ✓ Device IS targeted by this profile
      Via: Group: All Windows Devices
      Deployment Status: success
      Last Reported: 2025-10-15T09:15:00Z

  Profile: VPN Certificate [Windows]
    ✗ Device is NOT targeted by this profile

  Profile: Mobile Device Certificate [iOS]
    ✗ Device is NOT targeted by this profile

╔════════════════════════════════════════════════════════════════╗
║  Summary                                                       ║
╚════════════════════════════════════════════════════════════════╝

Device: DESKTOP-ABC123
Total SCEP Profiles: 5
Targeted: 1
Not Targeted: 4

✓ Analysis complete!
```

## How It Works

1. **Authentication**: The script connects to Microsoft Graph using interactive authentication with delegated permissions.

2. **Device Resolution**: Queries the Intune managed devices endpoint to find the device by hostname.

3. **Enrollment Check**: Validates the device's enrollment state, compliance status, and Azure AD registration.

4. **Group Membership**: Retrieves all Azure AD groups the device is a member of (including dynamic groups).

5. **SCEP Profile Discovery**: Scans all device configuration profiles across all platforms to find SCEP certificate profiles.

6. **Assignment Analysis**: For each SCEP profile:
   - Retrieves assignment rules (groups, filters, etc.)
   - Checks if the device matches the targeting criteria
   - Evaluates assignment filters that might exclude the device
   - Retrieves the deployment status if targeted

7. **Reporting**: Provides a comprehensive report showing which profiles are assigned, deployment status, and any issues.

## Troubleshooting

### "Device not found in Intune"
- Verify the device name is correct and matches exactly
- Ensure the device is enrolled in Intune
- Check that you have permissions to view the device

### "Could not retrieve filter details"
- Some assignment filters may require additional permissions
- The filter may have been deleted but still referenced in assignments

### "Deployment Status: Not yet reported"
- The device hasn't checked in since the profile was assigned
- The profile is newly assigned and deployment is in progress
- Check the device's last sync time

## Support

For issues or questions, please open an issue in the GitHub repository.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
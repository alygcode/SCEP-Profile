# SCEP Profile Verification - Quick Reference

## Quick Start
```powershell
.\Check-SCEPProfiles.ps1 -DeviceName "YOUR-DEVICE-NAME"
```

## What It Does

### 1. Connect to Microsoft Graph ✓
- Authenticates with required permissions
- Uses delegated authentication

### 2. Resolve Device ✓
- Finds device by hostname in Intune
- Returns device details (ID, OS, version, serial)

### 3. Verify Enrollment & License ✓
- Checks enrollment state (managed/unmanaged)
- Validates compliance state
- Shows last sync time
- Verifies Azure AD registration

### 4. Collect Group Memberships ✓
- Retrieves all Azure AD groups
- Includes dynamic group memberships
- Essential for assignment targeting

### 5. Auto-detect SCEP Profiles ✓
Scans all platforms:
- ✓ Windows (Windows 8.1+ SCEP profiles)
- ✓ iOS (iOS SCEP profiles)
- ✓ Android (Android & Work Profile SCEP profiles)
- ✓ macOS (macOS SCEP profiles)

### 6. Check Device Targeting ✓
For each SCEP profile:
- Analyzes assignment rules
- Checks group membership
- Evaluates "All Devices" assignments
- Identifies exclusion groups

### 7. Pull Deployment Status ✓
- Gets per-device deployment state
- Shows success/pending/error status
- Displays last reported time

### 8. Flag Assignment Filters ✓
- Identifies assignment filters
- Highlights exclude filters
- Shows filter rules
- Warns about potential exclusions

## Output Indicators

| Symbol | Meaning |
|--------|---------|
| ✓ | Success / Device is targeted |
| ✗ | Failure / Device is NOT targeted |
| ⚠ | Warning / Potential issue |

## Common Scenarios

### Scenario 1: Device is targeted but certificate not deployed
**Check:**
- Deployment Status: Should show "pending" or "error"
- Last Sync: Device may need to sync
- Filter Issues: Check for exclude filters

### Scenario 2: Device should be targeted but isn't
**Check:**
- Group Memberships: Verify device is in expected groups
- Assignment Filters: Look for exclude filters
- Platform: Ensure profile matches device OS

### Scenario 3: Multiple profiles, unclear which applies
**Check:**
- Platform column in output
- Targeting information for each profile
- Deployment status for targeted profiles

## Permissions Required

```
DeviceManagementManagedDevices.Read.All
DeviceManagementConfiguration.Read.All
Directory.Read.All
Group.Read.All
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Device not found | Verify exact device name, check Intune enrollment |
| No SCEP profiles | Verify tenant has SCEP profiles configured |
| Filter details unavailable | Additional permissions may be needed |
| Status not reported | Device may not have synced since assignment |

## Tips

1. **Check recent devices first** - Last sync time matters
2. **Match OS platforms** - iOS profiles won't target Windows devices
3. **Review group memberships** - Most assignments use groups
4. **Watch for exclude filters** - They override include assignments
5. **Check last sync** - Older than 24h may need attention

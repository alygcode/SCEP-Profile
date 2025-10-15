# Technical Documentation

## Architecture

This tool uses the Microsoft Graph API to analyze SCEP certificate profile assignments for Intune managed devices.

## API Endpoints Used

### Device Management

```
GET /deviceManagement/managedDevices?$filter=deviceName eq '{name}'
```
Retrieves managed device information by hostname.

### Device Configuration Profiles

```
GET /deviceManagement/deviceConfigurations?$filter=isof('microsoft.graph.windows81SCEPCertificateProfile')
GET /deviceManagement/deviceConfigurations?$filter=isof('microsoft.graph.iosScepCertificateProfile')
GET /deviceManagement/deviceConfigurations?$filter=isof('microsoft.graph.androidScepCertificateProfile')
GET /deviceManagement/deviceConfigurations?$filter=isof('microsoft.graph.macOSScepCertificateProfile')
```
Retrieves SCEP certificate profiles for each platform.

### Profile Assignments

```
GET /deviceManagement/deviceConfigurations/{id}/assignments
```
Gets assignment rules for a specific configuration profile.

### Assignment Filters

```
GET /deviceManagement/assignmentFilters/{id}
```
Retrieves assignment filter details.

### Azure AD Devices

```
GET /devices?$filter=deviceId eq '{azureAdDeviceId}'
GET /devices/{id}/memberOf
```
Gets Azure AD device information and group memberships.

### Deployment Status

```
GET /deviceManagement/deviceConfigurations/{profileId}/deviceStatuses?$filter=id eq '{deviceId}'
GET /deviceManagement/managedDevices/{deviceId}/deviceConfigurationStates?$filter=id eq '{profileId}'
```
Retrieves per-device deployment status for configuration profiles.

## SCEP Profile Types

### Windows
- `microsoft.graph.windows81SCEPCertificateProfile`
- `microsoft.graph.windowsPhone81SCEPCertificateProfile`

### iOS
- `microsoft.graph.iosScepCertificateProfile`

### Android
- `microsoft.graph.androidScepCertificateProfile`
- `microsoft.graph.androidWorkProfileScepCertificateProfile`

### macOS
- `microsoft.graph.macOSScepCertificateProfile`

## Assignment Target Types

### Inclusion Targets
- `#microsoft.graph.groupAssignmentTarget` - Specific group
- `#microsoft.graph.allDevicesAssignmentTarget` - All devices
- `#microsoft.graph.allLicensedUsersAssignmentTarget` - All licensed users

### Exclusion Targets
- `#microsoft.graph.exclusionGroupAssignmentTarget` - Excluded group

## Assignment Filters

Assignment filters can have two types:
- **Include**: Device must match the filter rules to be targeted
- **Exclude**: Device matching the filter rules will be excluded

Filters use a rule-based syntax to evaluate device properties.

## Targeting Logic

The script determines if a device is targeted by a profile using this logic:

1. **Check All Devices assignments**: If present, device is targeted (unless excluded)
2. **Check Group assignments**: If device is in an included group, it's targeted
3. **Check Exclusion groups**: If device is in an excluded group, it's NOT targeted (overrides includes)
4. **Evaluate Assignment Filters**: Apply include/exclude filter logic
5. **All Licensed Users**: Requires user context (noted but not evaluated for devices)

## Deployment Status States

- **success**: Certificate successfully deployed
- **pending**: Deployment in progress
- **error**: Deployment failed
- **notApplicable**: Profile not applicable to device
- **conflict**: Conflicting profiles exist

## Error Handling

The script includes comprehensive error handling:
- Connection failures return early with clear messages
- Missing devices are reported with troubleshooting hints
- API errors are caught and reported per-operation
- Missing permissions cause graceful degradation with warnings

## Performance Considerations

- **API Throttling**: The script makes sequential API calls to avoid throttling
- **Pagination**: Results are paginated automatically by Invoke-MgGraphRequest
- **Beta Endpoints**: Some features require beta endpoints for full functionality

## Security

- **Authentication**: Uses interactive delegated authentication
- **Permissions**: Requests only Read permissions (least privilege)
- **Credentials**: Never stored or cached by the script
- **Tokens**: Managed by Microsoft.Graph PowerShell SDK

## Extensibility

The script is structured with functions that can be extended:

### Adding New Platform Support
Add additional SCEP profile types in `Get-AllSCEPProfiles`:
```powershell
$uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.newPlatformScepCertificateProfile')"
```

### Custom Reporting
Modify the `$results` array structure to include additional metrics.

### Export Functionality
Add export functions to save results to CSV, JSON, or HTML:
```powershell
$results | ConvertTo-Json | Out-File "report.json"
```

## Known Limitations

1. **User-based assignments**: Cannot fully evaluate "All Licensed Users" without user context
2. **Assignment filter evaluation**: Filter rules are shown but not evaluated programmatically
3. **Beta API dependency**: Some features require beta endpoints which may change
4. **Cross-platform testing**: Limited by available test devices per platform

## Future Enhancements

Potential improvements:
- Batch device checking
- HTML report generation
- Assignment filter rule evaluation
- Certificate expiration checking
- Historical deployment tracking
- Automated remediation suggestions

## Dependencies

### PowerShell Modules
- Microsoft.Graph.Authentication (>= 2.0.0)
- Microsoft.Graph.DeviceManagement (>= 2.0.0)
- Microsoft.Graph.Identity.DirectoryManagement (>= 2.0.0)

### PowerShell Version
- PowerShell 7.0 or later recommended
- PowerShell 5.1 supported with limitations

## Testing

The script should be tested against:
- Devices on different platforms (Windows, iOS, Android, macOS)
- Various assignment scenarios (groups, all devices, exclusions)
- Different deployment states (success, pending, error)
- Tenants with/without SCEP profiles
- Devices with/without group memberships

## Compliance and Auditing

This tool can be used for:
- Compliance audits of certificate deployments
- Troubleshooting certificate deployment issues
- Validating assignment configurations
- Documenting device targeting
- Identifying misconfigured assignments

## References

- [Microsoft Graph API Documentation](https://docs.microsoft.com/en-us/graph/api/overview)
- [Intune Device Configuration](https://docs.microsoft.com/en-us/graph/api/resources/intune-deviceconfig-deviceconfiguration)
- [SCEP Certificate Profiles](https://docs.microsoft.com/en-us/mem/intune/protect/certificates-scep-configure)
- [Assignment Filters](https://docs.microsoft.com/en-us/mem/intune/fundamentals/filters)

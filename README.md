#Connects to Microsoft Graph (Intune/Entra ID).
Resolves your device by hostname to an Intune Managed Device.
Verifies enrollment & license.
Collects dynamic group membership against SCEP profile assignments.
Auto-detects all SCEP certificate profiles across platforms and checks whether the device is actually targeted.
Pulls per-device deployment status for SCEP profiles.
Flags assignment filters that might exclude the device.
Runs device-side diagnostics (DM-EDP event log, IME logs if present, dsregcmd /status, mdmdiagnosticstool if Windows).

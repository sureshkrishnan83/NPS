# NPS Configuration Script

This PowerShell script automates the configuration of Network Policy Server (NPS) with Azure Multi-Factor Authentication (MFA). It performs the following tasks:

- Backs up the NPS configuration file
- Generates a new password for the RADIUS shared secret
- Adds an NPS client
- Creates a network policy
- Adds a connection request policy

## Prerequisites

- PowerShell
- Administrator privileges

## Usage

1. Download or clone the script to your local machine.
2. Open PowerShell with administrator privileges.
3. Navigate to the directory where the script is located.
4. Execute the script with the required parameters:

```powershell
.\createNPSClientV3.ps1 -IPAddress 10.0.0.1 -ClientName Server01 -SharedSecret Password1245$ -Projectname Projectname

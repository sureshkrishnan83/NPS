# NPS Configuration PowerShell Script
### Overview
This PowerShell script automates the configuration of Network Policy Server (NPS) by adding clients, network policies, and connection request policies. It is designed to streamline the setup process for NPS by allowing administrators to specify client information via command-line parameters or by importing data from a CSV file.

## Features
- 1. Add NPS Clients: Add new NPS clients with specified names and IP addresses.
- 2. Add Network Policies: Configure network policies in NPS based on client information.
- 3. Add Connection Request Policies: Set up connection request policies in NPS to manage incoming connection requests.
- 4. Backup Configuration: Automatically creates a backup of the NPS configuration file before making changes.

## Usage
Adding a Single Client
To add a single client, use the following command:

## Example 
```
New-NpsConfiguration -name "Client1" -ip "192.168.1.100"

````
Replace "Client1" with the desired client name and "192.168.1.100" with the client's IP address.

## Adding Clients from CSV
To add clients from a CSV file, use the following command:

## Example 
```
$clientinfo = Import-Csv C:\temp\nps.csv
$clientinfo | ForEach-Object { New-NpsConfiguration -name $_.ClientName -ip $_.IpAddress }

```
Ensure that the CSV file contains columns named ClientName and IpAddress with the corresponding client information.

## Requirements
PowerShell 3.0 or higher
Administrator privileges to execute the script
Network Policy Server (NPS) installed and configured

### Notes
- Author: Suresh Krishnan
- Date: 12-Feb-2024 


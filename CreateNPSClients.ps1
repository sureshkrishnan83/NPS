$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Global:logFileName = "c:\temp\NPSConfig_$timestamp.log"


function Log-Message {
    param(
        [string]$message,
        [string]$type = "INFO"
    )



    $logEntry = "[$timestamp] [$type] $message"
    Write-Output $logEntry
    
    # Append log entry to the logfile
    Add-Content -Path $logFileName -Value $logEntry
} 

function Add-NpsNetworkPolicy {
    [CmdletBinding()]
    param(
        [string]$name,
        [string]$ip
    )

    # Get the current Policy Number
    [int]$CurrentProcessingOrder = $IASConfig.root.children.Microsoft_Internet_Authentication_Service.children.NetworkPolicy.children.LastChild.Properties.msNPSequence.'#text'
    $NextProcessOrder = $CurrentProcessingOrder + 1

    $logMessage = "Adding Network Policy with name: AZURE_MFA_$name and IP: $ip"
    Log-Message -message $logMessage -type "SUCCESS"

    $arguments = @(
        "name = `"AZURE_MFA_$name`"",
        "conditionid = '0x100c'",
        "conditiondata = `"$ip`"",
        "policysource = '0'",
        "processingorder = `"$NextProcessOrder`"",
        "profileid = '0x1009'",
        "profiledata = '0x1'",
        "profiledata = '0x2'",
        "profiledata = '0x3'",
        "profiledata = '0x9'",
        "profiledata = '0x4'",
        "profiledata = '0xa'",
        "profiledata = '0x7'",
        "profileid = '0x1005'",
        "profiledata = 'TRUE'",
        "profileid = '0x100f'",
        "profiledata = 'TRUE'",
        "profileid = '0x7'",
        "profiledata = '0x1'",
        "profileid = '0x6'",
        "profiledata = '0x2'",
        "profileid = '0x1b'",
        "profiledata = '0x1a4'"
    )

    try {
        $command = "netsh nps add np " + ($arguments -join ' ')
        $output = Invoke-Expression $command
        if ($output -eq "Ok.") {
            Log-Message -message "Command executed successfully."
        } else {
            Log-Message -message "Command failed with output: $output" -type "SUCCESS"
        }
    } catch {
        Log-Message -message "Failed to execute command: $_" -type "ERROR"
    }
}

function Add-ConnectionRequestPolicy {
    [CmdletBinding()]
    param(
        [string]$name,
        [string]$ip
    )

    # Get the current Policy Number
    $IASConfig = [XML](Get-Content -Path $IASConfigFile)
    [int]$CurrentProcessingOrder = $IASConfig.root.children.Microsoft_Internet_Authentication_Service.children.Proxy_Policies.Children.LastChild.Properties.msNPSequence.'#text'
    $NextProcessOrder = $CurrentProcessingOrder + 1

    $logMessage = "Adding Connection Request Policy with name: AZURE_MFA_$name and IP: $ip"
    Log-Message -message $logMessage 

    $arguments = @(
        "name = `"AZURE_MFA_$name`"",
        "conditionid = `"0x100c`"",
        "conditiondata = `"$ip`"",
        "processingorder = $NextProcessOrder",
        "policysource = '0'",
        "profileid = '0x1025'",
        "profiledata = '0x1'"
    )

    try {
        $command = "netsh nps add crp " + ($arguments -join ' ')
        $output = Invoke-Expression $command
        if ($output -eq 'Ok.' ) {
            Log-Message -message "Command executed successfully."
        } else {
            Log-Message -message "Command failed with output: $output" -type "SUCCESS"
        }
    } catch {
        Log-Message -message "Failed to execute command: $_" -type "ERROR"
    }
}

function Generate-Password {
    param (
        [Parameter(Mandatory)]
        [int] $length,
        [int] $amountOfNonAlphanumeric = 4
    )
    Add-Type -AssemblyName 'System.Web'
    return [System.Web.Security.Membership]::GeneratePassword($length, $amountOfNonAlphanumeric)
}

function Add-NPSClient {
    [CmdletBinding()]
    param(
        [string]$name,
        [string]$ip
    )

    try {
        $client = New-NpsRadiusClient -Name $name -Address "$ip" -SharedSecret $radiusSharedSecret
        if ($client -ne $null) {
            Write-Host "NPS Client '$name' added successfully witht the $radiusSharedSecret." -ForegroundColor Green
            Log-Message -message "NPS Client '$name' added successfully." -type "SUCCESS"
        } else {
            throw "An error occurred while adding NPS client '$name'. The client object is null."
            Log-Message -message "An error occurred while adding NPS client $name." -type "ERROR"
        }
    } catch {
        Write-Host "An error occurred while adding NPS client '$name': $_.Exception.Message"
        Log-Message -message "An error occurred while adding NPS client '$name': $_.Exception.Message" -type "ERROR"
    }
}


#Main Script Starting

function New-NpsConfiguration {

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [string]$name,
        
        [Parameter(ValueFromPipeline = $true, Position = 1)]
        [string]$ip

    )
    $transcriptPath = "C:\TranscriptLogs\NPS_Configuration_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    Start-Transcript -Path $transcriptPath -Append

    #SharedSecret 
       
    # Default Location for NPS (IAS) Config File
    $IASConfigFile = "C:\windows\system32\ias\ias.xml"

    # Create a backup
    $backupFileName = "$(($IASConfigFile).TrimEnd(".xml"))_BACKUP_$(Get-Date -Format MMddyy_HHmm).xml" 
    $logMessage = "Creating backup of NPS configuration file to: $backupFileName"
    Log-Message -message $logMessage -type "INFO"

    try {
        Copy-Item $IASConfigFile $backupFileName -Force
        Log-Message -message "Backupfile of NPS configuration file succcessfully created under $backupFileName" -type "SUCCESS"
    } catch {
        Log-Message -message "Failed to create backup: $_" -type "ERROR"
        exit 1
    }

    # Load the XML
    $logMessage = "Loading NPS configuration file: $IASConfigFile"
    Log-Message -message $logMessage

    try {
        $IASConfig = [XML](Get-Content -Path $IASConfigFile)
        Log-Message -message "NPS Config file $IASConfigFile loaded in memory successfully " -type "SUCCESS"
    } catch {
        Log-Message -message "Failed to load XML: $_" -type "ERROR"
        exit 1
    }

    Add-NPSClient -name $name -ip $ip
    Add-NpsNetworkPolicy -name $name -ip $ip
    Add-ConnectionRequestPolicy -name $name -ip $ip
    
    

    # Stop transcript logging
    Stop-Transcript
}





# Call the function
# Sample usage: "name" and "ip" can be piped into the function or passed directly
# Example: "name" | New-NpsConfiguration
$radiusSharedSecret = Generate-Password -length 12
$clientinfo = Import-Csv C:\temp\nps.csv

$clientinfo | ForEach-Object { New-NpsConfiguration -name $_.CleintName -ip $_.IpAddress}


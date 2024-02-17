#Add command based help for the script

Param (
    [string]$name,
    [string]$ip
)



# Start Transcript 
$transcriptPath = "C:\TranscriptLogs\NPS_Configuration_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $transcriptPath -Append

# Get the script file name without extension
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)

# Define the log file path using the script file name and current date/time
$logFilePath = "C:\temp\$scriptName.txt"

# Function to write log messages to a file
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = ""
    )
   
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "$timestamp - [$Level] $Message"
    if (-not (Test-Path $logFilePath)) {
        New-Item -ItemType File -Path $logFilePath -Force | Out-Null
    }
    $logMessage | Out-File -FilePath $logFilePath -Append
}

$StartTime = (Get-Date)
Write-Log "Script Started at: $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')" -Level "INFO"

function Add-ConnectionRequestPolicy {
    [CmdletBinding()]
    param(
        [string]$name,
        [string]$ip
    )

    # Get the current Policy Number
    $IASConfig = [XML](Get-Content -Path C:\Windows\System32\ias\ias.xml)
    [int]$CurrentProcessingOrder = $IASConfig.root.children.Microsoft_Internet_Authentication_Service.children.Proxy_Policies.Children.LastChild.Properties.msNPSequence.'#text'
    $NextProcessOrder = $CurrentProcessingOrder + 1

    $logMessage = "Adding Connection Request Policy with name: AZURE_MFA_$name and IP: $ip"
    write-Log -message $logMessage -Level "INFO"

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
            Write-Log -message "Command executed successfully." -Level "SUCCESS"
            Write-Host "Connection request policy With Name Azure_MFA_$name with $ip has been created successfully" -ForegroundColor Green
        }
        else {
            Write-Log -message "Command failed with output: $output" -level "WARNING"
        }
    }
    catch {
        write-log -message "Failed to execute command: $_" -level "ERROR"
    }
}

function Add-NpsNetworkPolicy {
    [CmdletBinding()]
    param(
        [string]$name,
        [string]$ip
    )

    # Get the current Policy Number
    $IASConfig = [XML](Get-Content -Path C:\Windows\System32\ias\ias.xml)
    [int]$CurrentProcessingOrder = $IASConfig.root.children.Microsoft_Internet_Authentication_Service.children.NetworkPolicy.children.LastChild.Properties.msNPSequence.'#text'
    $NextProcessOrder = $CurrentProcessingOrder + 1

    $logMessage = "Adding Network Policy with name: AZURE_MFA_$name and IP: $ip"
    Write-Log -message $logMessage -level "SUCCESS"

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
            Write-Log -message "$command Command executed successfully." -Level "INFO"
            Write-Host " Network policy With Name Azure_MFA_$name with $ip has been created successfully" -ForegroundColor Green
        }
        else {
            Write-Log -message "Command failed with output: $output" -level "SUCCESS"
        }
    }
    catch {
        Write-Log -message "Failed to execute command: $_" -level "ERROR"
    }
}

function New-Password {
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
        [string]$ip,
        [string]$sharedsecret
    )

    try {
        $client = New-NpsRadiusClient -Name $name -Address "$ip" -SharedSecret $radiusSharedSecret
        if ($null -ne $client) {
            Write-Host "NPS Client '$name' $ip added successfully witht the $radiusSharedSecret." -ForegroundColor Green
            Write-Log -message "NPS Client '$name' added successfully." -level "SUCCESS"
            return $true
        }
        else {
            throw "An error occurred while adding NPS client '$name'. The client object is null."
            Write-Log -message "An error occurred while adding NPS client $name." -level "ERROR"
            return $false
        }
    }
    catch {
        Write-Host "An error occurred while adding NPS client '$name': $_.Exception.Message"
        Write-Log -message "An error occurred while adding NPS client '$name': $_.Exception.Message" -level "ERROR"
        return $false
    }
}
   
function Backup-NPSFile {
    param (
        [string]$FilePath
    )

    # Check if the file exists
    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        Write-Host "Error: File '$FilePath' not found."
        return
    }

    # Generate a timestamp to append to the backup file name
    $timestamp = Get-Date -Format "yyyy-MM-dd-HHmm"

    # Extract filename and extension from the source file path
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $fileExtension = [System.IO.Path]::GetExtension($FilePath)

    # Construct the backup file name with timestamp
    $backupFileName = "${fileName}_Backup_$timestamp$fileExtension"

    # Construct the full path for the backup file in the same directory as the source file
    $backupFilePath = Join-Path -Path (Split-Path -Path $FilePath -Parent) -ChildPath $backupFileName

    # Copy the source file to the backup location
    Copy-Item -Path $FilePath -Destination $backupFilePath -Force

    # Output the success message
    Write-Host "Backup of '$FilePath' created at '$backupFilePath'"
}





# Main Script 

# Backup the NPS configuration file
Backup-NPSFile -FilePath "C:\Windows\System32\ias\ias.xml"


# Create a new password for the RADIUS shared secret
$radiusSharedSecret = New-Password -length 12

if (Add-NPSClient -name $name -ip $ip -sharedsecret $radiusSharedSecret) {
    Add-NpsNetworkPolicy -name $name -ip $ip
    Add-ConnectionRequestPolicy -name $name -ip $ip

}
else {
    Write-Log "NPS Client creation failed. Skipping Network Policy and Connection Request Policy addition." -Level "WARNING"
    Write-Host "NPS Client creation failed. Skipping Network Policy and Connection Request Policy addition." -ForegroundColor Red
}

Get-NpsRadiusClient  | Where-Object {$_.name -eq "$name"}
& netsh nps show cp | select-string "$name" -Context 2,13 | Out-Host
& netsh nps show np | select-string "$name" -Context 2,22 | Out-Host



$EndTime = (Get-Date)
Write-Log "Script Ended at: $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')" -Level "INFO"

# Get Elapsed Time
$ElapsedTime = ($EndTime - $StartTime).Seconds
Write-Log "Script Execution Time: $ElapsedTime Seconds" -Level "INFO"

# Stop transcript logging
Stop-Transcript

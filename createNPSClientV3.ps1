param(
    [string]$CsvFilePath,
    
    [Parameter(Mandatory = $false)]
    [string]$IPAddress,
    
    [Parameter(Mandatory = $false)]
    [string]$ClientName,
    
    [Parameter(Mandatory = $false)]
    [string]$SharedSecret,

    [Parameter(Mandatory = $false)]
    [string]$Projectname

)


# Start Transcript 
$transcriptPath = "C:\buildLog\NPS_Configuration_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $transcriptPath -Append

# Get the script file name without extension
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path)

# Define the log file path using the script file name and current date/time
$logFilePath = "C:\buildLog\$scriptName.txt"


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
    Write-Host "Backup of NPS configuration '$FilePath' created at '$backupFilePath' `n" -ForegroundColor Yellow
    Write-Log "Backup of NPS configuration '$FilePath' created at '$backupFilePath" -Level "SUCCESS"
}

function Add-ConnectionRequestPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$IPAddress,
    
        [Parameter(Mandatory = $false)]
        [string]$ClientName,

        [Parameter(Mandatory = $false)]
        [string]$Projectname
    
    )

    # Get the current Policy Number
    $IASConfig = [XML](Get-Content -Path C:\Windows\System32\ias\ias.xml)
    [int]$CurrentProcessingOrder = $IASConfig.root.children.Microsoft_Internet_Authentication_Service.children.Proxy_Policies.Children.LastChild.Properties.msNPSequence.'#text'
    $NextProcessOrder = $CurrentProcessingOrder + 1

    $logMessage = "Adding Connection Request Policy with name: $Projectname_$ClientName with IP: $IPAddress `n"
    Write-Host $logMessage -ForegroundColor Green 
    write-Log -message $logMessage -Level "INFO"

    $arguments = @(
        "name = `"$Projectname`_$ClientName`"",
        "conditionid = `"0x100c`"",
        "conditiondata = `"$IPAddress`"",
        "processingorder = $NextProcessOrder",
        "policysource = '0'",
        "profileid = '0x1025'",
        "profiledata = '0x1'"
    )

    try {
        $command = "netsh nps add crp " + ($arguments -join ' ')
        $output = Invoke-Expression $command
        if ($output -eq 'Ok.' ) {
            Write-Log -message "Command executed successfully." -Level "INFO"
            Write-Host "Connection request policy With Name $Projectname_$ClientName with $IPAddress has been created successfully `n" -ForegroundColor Green
            Write-Log -Message "Connection request policy With Name $Projectname_$ClientName with $IPAddress has been created successfully" -Level "SUCCESS"
        }
        else {
            Write-Log -message "Command failed with output: $output" -level "WARNING"
            Write-Host "Command failed with output: $output `n"
        }
    }
    catch {
        write-log -message "Failed to execute command: $_" -level "ERROR"
        Write-Host "Failed to execute command: $_ `n"
    }
}

function Add-NpsNetworkPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$IPAddress,
        
        [Parameter(Mandatory = $false)]
        [string]$ClientName,
    
        [Parameter(Mandatory = $false)]
        [string]$Projectname
        
    )

    # Get the current Policy Number
    $IASConfig = [XML](Get-Content -Path C:\Windows\System32\ias\ias.xml)
    [int]$CurrentProcessingOrder = $IASConfig.root.children.Microsoft_Internet_Authentication_Service.children.NetworkPolicy.children.LastChild.Properties.msNPSequence.'#text'
    $NextProcessOrder = $CurrentProcessingOrder + 1

    $logMessage = "Adding Network Policy with name: $ProjectName_$ClientName and IP: $ip `n"
    Write-Log -message $logMessage -level "INFO"
    Write-Host $logMessage -ForegroundColor Green

    $arguments = @(
        "name = `"$Projectname`_$ClientName`"",
        "conditionid = '0x100c'",
        "conditiondata = `"$IPAddress`"",
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
            Write-Host "Network policy With Name $Projectname`_$ClientName with $IPAddress has been created successfully `n" -ForegroundColor Green
            Write-Log -Message "Network policy With Name $Projectname`_$ClientName with $IPAddress has been created successfully" -Level "SUCCESS"
        }
        else {
            Write-Log -message "Command failed with output: $output" -level "ERROR"
            Write-Host "Command failed with output: $output `n" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Log -message "Failed to execute command: $_" -level "ERROR"
        Write-Host "$_ `n" -ForegroundColor Yellow
    }
}


$StartTime = (Get-Date)
Write-Log "Script Started at: $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')" -Level "INFO"
Write-Host "############ Script Started at: $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')############## `n" -ForegroundColor Yellow

#################################################

# Main Script 

#############################################3

#Backup NPS Configuration File 

Backup-NPSFile -FilePath "C:\Windows\System32\ias\ias.xml"


# Creatin New NPS Clients and its corresponding Conection Request Policies and Network Policies. 
# Check if CSV file path is provided

if ($CsvFilePath) {
    # Check if CSV file exists
    if (-not (Test-Path $CsvFilePath -PathType Leaf)) {
        Write-Host "CSV file not found at the specified path."
        exit
    }
    
    # Read CSV file
    $CsvData = Import-Csv -Path $CsvFilePath

    # Iterate through each entry in the CSV file
    foreach ($Entry in $CsvData) {
        $IPAddress = $Entry.IPAddress
        $ClientName = $Entry.ClientName
        $SharedSecret = $Entry.SharedSecret
        $Projectname = $Entry.Projectname
        
        # Create NPS client
        try {
            $NpsClient = New-NpsRadiusClient -Name $ClientName -Address $IPAddress -SharedSecret $SharedSecret -VendorName "RADIUS Standard"

            if ($null -ne $NpsClient) {
                Write-Log -Message "NPS client '$ClientName' with IP address '$IPAddress' has been created successfully." -Level "SUCCESS"
                Write-Host "NPS client '$ClientName' with IP address '$IPAddress' has been created successfully . `n"
                Add-ConnectionRequestPolicy -IPAddress $IPAddress -ClientName $ClientName -Projectname $Projectname
                Add-NpsNetworkPolicy -IPAddress $IPAddress -ClientName $ClientName -Projectname $Projectname
                Get-NpsRadiusClient  | Where-Object { $_.name -eq "$ClientName" }
                & netsh nps show cp | select-string "$ClientName" -Context 2, 13 | Out-Host
                & netsh nps show np | select-string "$ClientName" -Context 2, 22 | Out-Host
                
            }
            else {
                throw "An error occurred while adding NPS client '$ClientName'. The client object is null."
                Write-Log -message "An error occurred while adding NPS client $ClientName." -level "ERROR"
                Write-Host "Failed to create NPS client for '$ClientName' with IP address '$IPAddress'. `n"
                
            }
        } 
        catch {
            Write-Host "An error occurred while adding NPS client '$ClientName': $_.Exception.Message `n"
            Write-Log -message "An error occurred while adding NPS client '$ClientName': $_.Exception.Message" -level "ERROR"
                 

        }
    }
}
elseif ($IPAddress -and $ClientName -and $SharedSecret) {
    # Check if NPS role is installed
    if (-not (Get-WindowsFeature -Name NPAS)) {
        Write-Host "NPS role is not installed. Please install the NPS role first."
        exit
    }
    
    # Create NPS client
    try {
        $NpsClient = New-NpsRadiusClient -Name $ClientName -Address $IPAddress -SharedSecret $SharedSecret -VendorName "RADIUS Standard"

        if ($null -ne $NpsClient) {
            Write-Log -Message "NPS client '$ClientName' with IP address '$IPAddress' has been created successfully." -Level "SUCCESS"
            Write-Host "NPS client '$ClientName' with IP address '$IPAddress' has been created successfully.`n"
            Add-ConnectionRequestPolicy -IPAddress $IPAddress -ClientName $ClientName -Projectname $Projectname
            Add-NpsNetworkPolicy -IPAddress $IPAddress -ClientName $ClientName -Projectname $Projectname
            Get-NpsRadiusClient  | Where-Object { $_.name -eq "$ClientName" }
            & netsh nps show cp | select-string "$ClientName" -Context 2, 13 | Out-Host
            & netsh nps show np | select-string "$ClientName" -Context 2, 22 | Out-Host
            
        }
        else {
            throw "An error occurred while adding NPS client '$ClientName'. The client object is null."
            Write-Log -message "An error occurred while adding NPS client $ClientName." -level "ERROR"
            Write-Host "Failed to create NPS client for '$ClientName' with IP address '$IPAddress'.`n"
            
        }
    } 
    catch {
        Write-Host "An error occurred while adding NPS client '$ClientName': $_.Exception.Message `n"
        Write-Log -message "An error occurred while adding NPS client '$ClientName': $_.Exception.Message" -level "ERROR"
            

    }
}





$EndTime = (Get-Date)
Write-Log "Script Ended at: $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')" -Level "INFO"
Write-Host "############Script Ended at: $(Get-date -format 'dd/MM/yyy hh:mm:ss tt')############ `n" -ForegroundColor Green
# Get Elapsed Time
$ElapsedTime = ($EndTime - $StartTime).Seconds
Write-Log "Script Execution Time: $ElapsedTime Seconds" -Level "INFO"
Write-Host " Script Execution Time: $ElapsedTime Seconds `n" -ForegroundColor Green
Write-Host "You can check the script logs at $logFilePath "
# Stop transcript logging
Stop-Transcript

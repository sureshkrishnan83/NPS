function Say-Hello {
    param(
        [string]$Name
    )
    
    Write-Output "Hello, $Name!"
}

function Say-Greeting {
    param(
        [string]$Name,
        [string]$Greeting
    )
    
    Write-Output "$Greeting, $Name!"
}
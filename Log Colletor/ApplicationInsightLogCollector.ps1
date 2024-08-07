# Declare the parameters required to collect the Error logs.
param ( 
    [string]$SubscriptionId,
    [string]$ResourceGroupName,
    [string]$applicationName,
    [string]$query,
    [string]$senderEmail,
    [string]$recipientEmail
)

#Import the required modules
Import-Module Az.ApplicationInsights
Import-Module AzureCli 
Invoke-AzCli 
az extension add --name application-insights --allow-preview false


# Get current date and time
$dateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Initialize the parameters that were declared 
$SubscriptionId = $SubscriptionId
$ResourceGroupName = $ResourceGroupName
$applicationName = $applicationName
$query = $query
$senderEmail = $senderEmail

# Connect to Azure
try {
  az login --identity 
  Connect-AzAccount -Identity -SubscriptionId $SubscriptionId
  Write-Output " Connected to azure acoount"
}
catch {
  Write-Error "Error connecting to Azure: $_"
  exit
}

# Set the context to the specified resource group
Set-AzContext -Subscription $SubscriptionId 

# Run the query against the Application Insights resource
$results = az monitor app-insights query --subscription $SubscriptionId --apps $applicationName --resource-group $ResourceGroupName --analytics-query $query --offset 24h

# Convert JSON to PowerShell object
$data = $results | ConvertFrom-Json

# Check the number of rows in the data
Write-Output "Error count: $($data.tables[0].rows.Count)"

# Extract column names
$columns = $data.tables[0].columns.name

# Create an array to store rows
$rows = @()

# Iterate through all tables and rows
foreach ($table in $data.tables) {
    foreach ($row in $table.rows) {
        $rowHash = @{}
        for ($i = 0; $i -lt $columns.Count; $i++) {
            $rowHash[$columns[$i]] = $row[$i]
        }
        $rows += $rowHash
    }
}

# Convert to CSV
$rows | Export-Csv -Path "C:\app\output.csv" -NoTypeInformation -Encoding UTF8

# SendGrid API Endpoint
$sendGridEndpoint = "https://api.sendgrid.com/v3/mail/send"

# Email details
$subject = "Error logs for the $applicationName in the past 24 hours."
$body = @"
Resource : Production RDE Consumer Websites. `n
Subscription Id : $SubscriptionId `n
Resource Group name : $ResourceGroupName `n
Application Insights name : $applicationName `n
Duration: 24 Hours.`n
500 Error count : $($data.tables[0].rows.Count)
`n`
"@


# Convert text file to base64 for attachment
$csvAttachmentPath = "C:\app\output.csv"
$csvAttachmentContent = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($csvAttachmentPath))

# SendGrid API Key
$sendGridAPIKey = Get-AutomationVariable -Name AzEu2Reziai-SendGridAPIkey

# Create headers with authorization
$headers = @{}
$headers.Add("Authorization","Bearer $sendGridAPIKey")
$headers.Add("Content-Type", "application/json")

## Check for multiple addresses in the recipientEmail
if($recipientEmail.Contains(“,”) -eq $true){
[array]$emails = $recipientEmail.Split(“,”) }
else{
[array]$emails = $recipientEmail
}

# Email payload
$emailPayload = @{
    personalizations = @(
        @{
            to =@($emails | %{ @{email = “$_”} })
        }
    )
    from = @{
        email = $senderEmail
    }
    subject = $subject
    content = @(
        @{
            type = "text/plain"
            value = $body
        }
    )
    attachments = @(
        @{
            content = $csvAttachmentContent
            filename = "ErrorLogs-$dateTime.csv"
            type = "text/csv"
        }
    )
}

# Convert payload to JSON
$emailPayloadJson = $emailPayload | ConvertTo-Json -Depth 100

# Send the email using Invoke-RestMethod
try {
    Invoke-RestMethod -Uri $sendGridEndpoint -Headers $headers -Method Post -Body $emailPayloadJson -ContentType "application/json"
    Write-Output "Mail is sent with the Errorlogs file on $dateTime"
} catch {
    Write-Host "Error: $_"
}

# Remove the file that is saved. 
Remove-Item -Path "C:\app\output.csv"
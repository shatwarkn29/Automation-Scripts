# Declare parameters required for the collection of the top 5 IP attack trace list.
param ( 
    [string]$SubscriptionId,
    [string]$ResourceGroupName,
    [string]$Resource,
    [string]$WorkspaceName,
    [string]$WorkspaceId,
    [string]$senderEmail,
    [string]$recipientEmail
)

# Import the required modules
Import-Module AzureCli 
Invoke-AzCli
az extension add --name log-analytics --allow-preview true

# Get current date and time
$dateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Initializing variables which are given as parameters 
$SubscriptionId = $SubscriptionId
$ResourceGroupName = $ResourceGroupName
$Resource = $Resource
$WorkspaceName = $WorkspaceName
$WorkspaceId = $WorkspaceId
$senderEmail = $senderEmail
$recipientEmail = $recipientEmail

# Connect to Azure
try {
  az login --identity
  Connect-AzAccount -Identity -SubscriptionId $subscriptionId
  Write-Output " Connected to azure acoount"
}
catch {
  Write-Error "Error connecting to Azure: $_"
  exit
}

# Set the context to the specified resource group
Set-AzContext -Subscription $subscriptionId 

# Set the Primary query to collect the ClientIP_s , Count_
$primaryquery = "AzureDiagnostics | where Category == 'FrontDoorWebApplicationFirewallLog' or Category == 'FrontdoorWebApplicationFirewallLog' | where action_s == 'Block' | where TimeGenerated between(datetime('2024-07-15T09:00:00.000Z') .. datetime('2024-07-16T09:00:00.000Z')) | project TimeGenerated, requestUri_s, clientIP_s, action_s, host_s | summarize count() by requestUri_s, host_s ,clientIP_s | order by count_ desc"

# Run the query against the Log Alalytics resource
$results =az monitor log-analytics query -w $WorkspaceId --analytics-query $primaryquery
$queryresults1 = $results | ConvertFrom-Json 
$queryresults1 | Select-Object TimeGenerated, ruleName_s, requestUri_s, action_s, clientIP_s | Export-Csv -Path "C:\app\output1.csv" -NoTypeInformation 

$csvAttachmentPath = "C:\app\output1.csv"
$csvAttachmentContent = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($csvAttachmentPath))


# SendGrid API Endpoint
$sendGridEndpoint = "https://api.sendgrid.com/v3/mail/send"

# SendGrid API Key
$sendGridAPIKey = Get-AutomationVariable -Name AzEu2Reziai-SendGridAPIkey

# Email details
$subject = "IP Attack trace for $WorkspaceName in the past 24 hours."
$body = @"
Last 24 Hours Request count.
---------------------------------
Resource : FrontDoor 
Subscription Id : $SubscriptionId 
Resource Group name : $ResourceGroupName 
Log Analytics name : $WorkspaceName 
Duration: 24 Hours
`n`
"@

# Create headers with authorization
$headers = @{}
$headers.Add("Authorization","Bearer $sendGridAPIKey")
$headers.Add("Content-Type", "application/json")

## Check for multiple addresses in the TO:
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

# Email payload for catch block
$emailPayloadEC = @{
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
}

# Convert payload to JSON
$emailPayloadJson = $emailPayload | ConvertTo-Json -Depth 100
$emailPayloadJsonEC = $emailPayloadEC | ConvertTo-Json -Depth 100

# Send the email using Invoke-RestMethod
try {
    Invoke-RestMethod -Uri $sendGridEndpoint -Headers $headers -Method Post -Body $emailPayloadJson -ContentType "application/json"
    Write-Output "Mail is sent with the Errorlogs file on $dateTime"
} catch {
    try {
        Invoke-RestMethod -Uri $sendGridEndpoint -Headers $headers -Method Post -Body $emailPayloadJsonEC -ContentType "application/json"
    }
    catch {
        Write-Output "Error: $_"
    }
    Write-Output "Error: $_"
}
$count =0
foreach ($ip in $ClientIPs){
    $count +=1
     Remove-Item -Path "C:\app\output1.csv"
}
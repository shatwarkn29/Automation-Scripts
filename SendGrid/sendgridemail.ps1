# Your SendGrid API key
$apiKey = ""

# API URL
$sendGridApiUrl = "https://api.sendgrid.com/v3/mail/send"

# Email headers
$headers = @{
    "Authorization" = "Bearer $apiKey"
    "Content-Type"  = "application/json"
}

# Email body data
$emailBody = @{
    from = @{
        email = "" # Mail id of the sender 
    }
    personalizations = @(
        @{
            to = @(
                @{
                     email = "" # Mail id of the reciepient 
                }
            )
            dynamic_template_data = @{
                
            }
        }
    )
    template_id = ""  # Replace with your actual template ID
}

# Convert body to JSON
$jsonBody = $emailBody | ConvertTo-Json -Depth 10

# Send the email via SendGrid API
$response = Invoke-RestMethod -Uri $sendGridApiUrl -Method Post -Headers $headers -Body $jsonBody

# Output the response
$response

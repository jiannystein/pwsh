<#
    .SYNOPSIS
        Import user details and send tailored emails to them using the details in the mail body.
    .DESCRIPTION
        The script will take a list of users and details where the disablement was a success, get the relevant details loaded and form a email body, then send the email.
    .EXAMPLE
        .\emailtemplate.ps1
    .NOTES
        Date	Ver		Author	Notes
        ------------------------------------------------------------------------------------------------------
        21JUNE2022 1.0     WJ Khor - Initial release.
#>

#region Init
#Import Data from Csv File where Device Disabled equal Success
$UsersList = Import-Csv 'C:\Temp\Result_20220610183155.csv' | Where-Object { $_.'Device Disabled' -eq 'Success' }

#Transcript
Start-Transcript -Path 'C:\temp\emailrunlogs.txt' -Append

# Progress Count
$Count = 0
#endregion Init

#region Work
foreach ($User in $UsersList) {
    $Count ++
    $Percent = [math]::Round(($Count / $Total) * 100, 2)
    Write-Progress -Activity 'Running emails...' -Status "$Count of $Total ($Percent %)" -PercentComplete $Percent

    $FirstName    = $User.OwnerGivenName
    $LastName     = $User.OwnerSurname
    $EmailAddress = $User.OwnerEmail
    $DeviceName   = $User.DisplayName

    try {
        $MailParam = @{
            From       = '<From Who?>'
            To         = $EmailAddress
            SMTPServer = 'corimc04.corp.Jabil.org'
            Subject    = '[Notice] Your device has been disabled due to inactivity'
            BodyASHtml = $true
            Body       = @"
    <H2>Device Disablement Notification</h2>
    <p>Dear $FirstName $LastName,</p>
    <p>Given your account has been not been logged in for over 100 days, we have disabled your device [$DeviceName]</p>
    <p>Regards,</br>
    Support
    </p>
"@
        }
        Send-MailMessage @MailParam -ErrorAction Stop
    } catch {
        throw $_
    }
}
Stop-Transcript
#endregion Work

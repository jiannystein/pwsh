<#

.SYNOPSIS
import user details and send tailored emails to them using the details in the mail body

.DESCRIPTION
The script will take a list of users and details where the disablement was a success, get the relevant details loaded and form a email body, then send the email.

.INSTRUCTIONS
- Specify the path to the results file from the previous script
- Fill in the username and password of the account that has access to send on behalf of the mailbox you specify
- Specify the mailbox email address you wish to send from
- Specify the smtp relay server address which has been whitelisted to the server/pc running the script
- Add any additional details to the "prep user details" section for the email body
- Edit the email body until you are happy with it

.NOTES
Wenjian

#>

#import collected data where they were successfully disabled
$UsersList = import-csv "C:\Temp\Result_20220610183155.csv" | ? {$_."Device Disabled" -eq "Success"}

#Mailbox Access credentials (with 'send as' permission)
$username = '<username here>'
$password = '<password here>'
$secureStringPWD = $password | ConvertTo-SecureString -AsPlainText -Force 
$creds = New-Object System.Management.Automation.PSCredential -ArgumentList ($username,$secureStringPWD) 

#SMTP Relay server (the pc/account running this script must be whitelisted on the relay)
$smtpserver = "smtpserver.domain.com" 

#mailbox account email address
$from = '<emailaddress of sending mailbox>' 

#log script output
Start-Transcript -Path C:\temp\emailrunlogs.txt -Append

$count = 0

#begin sending emails
foreach($user in $UsersList){ 
        
        #track progress of script processing
        $count ++ 
        $percent = [math]::Round(($count / $total) * 100,2) 
        Write-Progress -Activity "running emails..." -Status "$count of $total ($percent %)" -PercentComplete $percent 

        #prep user details - add any further properties from the imported csv file that may be useful in the body content below:
        $FirstName = $user.OwnerGivenName
        $Lastname = $user.OwnerSurname
        $emailaddress = $user.OwnerEmail
        $devicename = $user.DisplayName

        #clean email addresses
        if($emailaddress -like "*'*"){ 
            $emailaddresssearch = $emailaddress -replace "'","''" 
        }else{ 
            $emailaddresssearch = $emailaddress 
        } 

        
        #Email Details
        $to = $emailAddress 
        $subject = "[Notice] Your device has been disabled due to inactivity"
        

        #the body of the email in HTML
        $bodycontent = "

        <H2>Device Disablement notification</h2>
        
        <p>Dear $firstname $Lastname,</p>
        
        <p>given your account has been not been logged in for over 100 days, we have disabled your device $devicename</p>

        <p>regards,</br>
        Support
        </p> 

        "
        

        #SEND VIA SMTP Relay 
        try{ 
            Send-MailMessage -to $to -from $from -Body $bodycontent -Subject $subject -BodyAsHtml -SmtpServer $smtpserver -Credential $creds -ErrorAction Stop
            write-host "Email Sent to $emailaddress"
        }Catch{ 
            Write-Host $_.exception.message
        } 

} 

Stop-Transcript
#Read external users from CSV file
$GuestUsers = Import-CSV "C:\GuestUsers.csv"
$i = 0;
$TotolUsers = $GuestUsers.Count
#Iterate users and send guest invite one by one
Foreach($GuestUser in $GuestUsers)
{
$GuestUserName = $GuestUser.'UserName'
$GuestUserEmail = $GuestUser.'EmailAddress'
 
$i++;
Write-Progress -activity "Processing $GuestUserName - $GuestUserEmail" -status "$i out of $TotolUsers completed"
Try
{
#Send invite
$InviteResult = New-AzureADMSInvitation -InvitedUserDisplayName $GuestUserName -InvitedUserEmailAddress $GuestUserEmail -InviteRedirectURL https://myapps.microsoft.com -SendInvitationMessage $true
Write-Host "Invitation sent to $GuestUserName ($GuestUserEmail)" -f Green
}
catch
{
Write-Host "Error occurred for $GuestUserName ($GuestUserEmail)" -f Yellow
Write-Host $_ -f Red
}
}
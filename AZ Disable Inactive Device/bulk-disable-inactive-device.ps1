<#
.SYNOPSIS
connect to azure ad, collect device data, disable devices and output the results to csv
.DESCRIPTION
the script will connect to azure ad tenent, import the list of devices where the user ahs not logged on in over 100 days
then look up the owner of the device, collect the matching ad user's details, disable the device and output the results to csv.
it also outputs errors to the csv under the message column if anything goes wrong with the disablement.
.INSTRUCTIONS
- Fill in the tenent id below and enter your credentials to log into Azure AD.
.NOTES
https://t.me/wenjian 
#>
#script log start
Start-Transcript -Path C:\temp\DataCollectionscriptRunLog.txt
Connect-AzureAD -TenantId "tenent.com" #fill this in
$dt = (Get-Date).AddDays(-100)
#this may take some time depending on size of tenent
write-host "Getting all devices and processing the ApproximateLastLogonTimestamp..."
Get-AzureADDevice -All:$true | select-object -Property AccountEnabled, objectid, DeviceOSType, DeviceOSVersion, DisplayName, DeviceTrustType, ApproximateLastLogonTimestamp | Where {$_.ApproximateLastLogonTimeStamp -le $dt} | export-csv -Path c:\temp\DisableDevice.csv -NoTypeInformation
$today = Get-Date
$devices = import-csv C:\temp\DisableDevice.csv
$log = "C:\temp\Result_$(Get-Date -f "yyyyMMddHHmmss").csv"
$count = 0
foreach ($device in $devices){
    #track progress of script processing
    $count ++
    $percent = [math]::Round(($count / $total) * 100,2)
    Write-Progress -Activity "Running data collection processing and device disablement..." -Status "$count of $total ($percent %)" -PercentComplete $percent
    #create object with relevant details
    $obj = New-Object psobject
    $obj | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $Device.ObjectId
    $obj | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $Device.DisplayName
    $obj | Add-Member -MemberType NoteProperty -Name "DeviceOSType" -Value $Device.DeviceOSType
    $obj | Add-Member -MemberType NoteProperty -Name "DeviceOSVersion" -Value $Device.DeviceOSVersion
    $obj | Add-Member -MemberType NoteProperty -Name "DeviceTrustType" -Value $Device.DeviceTrustType
    $obj | Add-Member -MemberType NoteProperty -Name "ApproximateLastLogonTimeStamp" -Value $Device.ApproximateLastLogonTimeStamp
    #Get Owner Details using device ID
    $owner = Get-AzureADDeviceRegisteredOwner -ObjectId $device.ObjectId
    #check if there is an owner assigned, if not, blank values, if so then populate with owner details
    if($owner.ObjectId -ne $null){
        #get user details based on owner ID
        $userdetails = get-azureADuser -ObjectId $owner.ObjectId | Select *
        #add details to the ps object
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerObjectId" -Value $userdetails.ObjectId
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerName" -Value $userdetails.DisplayName
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerGivenName" -Value $userdetails.GivenName
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerSurname" -Value $userdetails.Surname
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerEmail" -Value $userdetails.Mail
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerMobile" -Value $userdetails.Mobile
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerDepartment" -Value $userdetails.Department
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerJobTitle" -Value $userdetails.JobTitle
        $obj | Add-Member -MemberType NoteProperty -Name "AccountEnabled" -Value $userdetails.AccountEnabled
    }else{
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerObjectId" -Value 'No Owner Assigned'
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerName" -Value ''
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerGivenName" -Value ''
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerSurname" -Value ''
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerEmail" -Value ''
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerMobile" -Value ''
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerDepartment" -Value ''
        $obj | Add-Member -MemberType NoteProperty -Name "OwnerJobTitle" -Value ''
        $obj | Add-Member -MemberType NoteProperty -Name "AccountEnabled" -Value ''
    }
    #run device disablement and log the result
    try{
        Set-AzureADDevice -ObjectId $($Device.ObjectId) -AccountEnabled $false
        $obj | Add-Member -MemberType NoteProperty -Name "Device Disabled" -Value "Success"
        $obj | Add-Member -MemberType NoteProperty -Name "Message" -Value ""
        $obj | export-csv $log -Append -NoTypeInformation
    }catch{
        $obj | Add-Member -MemberType NoteProperty -Name "Device Disabled" -Value "Failed"
        $obj | Add-Member -MemberType NoteProperty -Name "Message" -Value $_.exception -replace ",",''
        $obj | export-csv $log -Append -NoTypeInformation
    }
}
Stop-Transcript
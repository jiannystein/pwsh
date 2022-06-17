<#
.SYNOPSIS
Saves a list of user data to a results file using an input list of userID's (samaccountname)
.DESCRIPTION
The script will create a csv log file called "processeditems" which keeps track of the processed files in the source folder (downloads).
It then gets all the available csv files and begins to process the IDs in them and export the results data (per source file) to a results subfolder of source (.\results\<originalfilename>_Results_<datetime>.csv)
Once exported, it then renames the original file (date on the end to avoid same name files) an moves the file to an archive folder so you have a clean source folder at the end.
The ProcessedItems log will show:
- Item count
- Duplicates found count
- Items not found in AD
- Processing date and time
- the user who processed it (ran the script)
- the results output file path
- the archived source file path
This way, all you have to do is bulk download the files to a source folder and run the script 
and you'll not just have all the results from all the files but also a history of processed files 
and things are kept organised.
.INSTRUCTIONS
- fill in your downloads folder where all your service now csv's are downloaded to
- Run the script and the following will happen:
    1. The source csv files should be moved to the archive folder when complete
    2. A results file will be created in the Results folder
    3. A log entry will be written to the processeditems log
    4. the script console will display a table with the log entry
.ASSUMPTIONS
- all csvs in the source folder have a column called 'Employee Number'
.NOTES
https://t.me/wenjian
#>
#Import AD module
try{
    Import-Module ActiveDirectory
}catch{
    throw "AD module wont load or is not installed"
    break
}
#downloads folder
$downloadsfolder = "C:\Users\1022801\downloads" #common path for web downloads but you can change it to wherever
#set csv log path
$processeditemspath = $downloadsfolder+"\ProcessedItems.csv"
#create working folders
New-Item -itemtype Directory -path "$downloadsfolder\Archive\" -Force
New-Item -ItemType Directory -Path "$downloadsfolder\Results\" -Force
New-Item -ItemType Directory -Path "$downloadsfolder\NotProcessed\" -Force
#date to make the run unique.
$processingdate = get-date -format "yyyy-MM-dd-HH-mm-ss"
#get list of csvs that have not yet been processed according to the processeditems log file
$itemstoprocess = Get-ChildItem -Path $downloadsfolder | ? {$_.FullName -like "*.csv" -and $_.FullName -ne $processeditemspath} | Select -Property *
#begin processing csv's
foreach($item in $itemstoprocess){
    $data = Import-Csv -Path $item.fullname
    if("Employee Number" -notin ($data | Get-Member).Name){
        #csv doesnt contain relevant columns, moving to new folder
        Move-Item $item.fullname -Destination ($downloadsfolder + '\NotProcessed\')
        write-host ($item.fullname+" was not processed, it does not contain a Employee Number column") -ForegroundColor Yellow
    }else{
        #initialise
        $itemcount = ($Data | Measure-object | Select Count).count
        $duplicates = 0
        $ItemsNotFound = 0
        $results = @()
        $resultsPath = $item.DirectoryName + '\Results\' + $item.basename + "_Results_$processingdate.csv"
        #begin processing csv items
        Foreach ($person in $data) {
             #re-initialise
             $result = $null
             #set EID
             $EID = $person.'Employee Number'
             #run the AD search
             $result = Get-ADUser -filter {"Surname -eq $EID -or Givenname -eq $EID -or SamAccountName -eq $EID"} -Properties * |
             Select-Object @{N='EmployeeNumber';E={$EID}}, @{N='UserID';E={$_.SamAccountName}}, Name, EmailAddress, physicalDeliveryOfficeName, Enabled -ErrorAction Ignore
             #Check to make sure user found
             if($result -ne $null){
                #check if duplicate
                if($result.UserID -notin $results.EmployeeNumber){
                    $results += $result
                }else{
                    #duplicate - add to count
                    $duplicates++
                }
             }else{
                #not found in AD - add to count and record not found
                $ItemsNotFound++
                $result = New-Object psobject
                $result | Add-Member -MemberType NoteProperty -Name "EmployeeNumber" -Value $EID
                $result | Add-Member -MemberType NoteProperty -Name "UserID" -Value "Not Found in AD"
                $result | Add-Member -MemberType NoteProperty -Name "Name" -Value "Not Found in AD"
                $result | Add-Member -MemberType NoteProperty -Name "EmailAddress" -Value "Not Found in AD"
                $result | Add-Member -MemberType NoteProperty -Name "physicalDeliveryOfficeName" -Value "Not Found in AD"
                $result | Add-Member -MemberType NoteProperty -Name "Enabled" -Value "Not Found in AD"
                $results += $result
             }
         }
         #export results
         $results | Export-Csv -Path $resultsPath -NoTypeInformation
         #Append date to filename
         $newname = ($item.basename + "_$processingdate.csv")
         #rename the source file
         Rename-Item -Path $item.FullName -NewName $newname
         #move processed item to archive folder
         Move-Item -Path ($item.DirectoryName+"\$newname") -Destination "$downloadsfolder\archive\$newname" -Force
         #create log record
         $log = New-Object psobject
         $log | Add-Member -MemberType NoteProperty -Name "FilePath" -Value "$downloadsfolder\archive\$newname"
         $log | Add-Member -MemberType NoteProperty -Name "FileName" -Value $newname
         $log | Add-Member -MemberType NoteProperty -Name "ItemCount" -Value $itemcount
         $log | Add-Member -MemberType NoteProperty -Name "Duplicates" -Value $duplicates
         $log | Add-Member -MemberType NoteProperty -Name "ItemsNotFound" -Value $ItemsNotFound
         $log | Add-Member -MemberType NoteProperty -Name "ProcessingDate" -Value $processingdate
         $log | Add-Member -MemberType NoteProperty -Name "ProcessedBy" -Value $env:USERNAME
         $log | Add-Member -MemberType NoteProperty -Name "OutputFile" -Value $resultsPath
         #export log record
         $log | Export-Csv -Path $processeditemspath -Append -NoTypeInformation
     }
 }
#output log 
$log | Select FileName, ItemCount, Duplicates, ItemsNotFound, ProcessingDate, ProcessedBy, OutputFile | FT
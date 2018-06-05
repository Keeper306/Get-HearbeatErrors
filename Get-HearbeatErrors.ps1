
Workflow Get-HearbeatErrors
{
 Param
    (
        [Parameter(Mandatory=$false)]    
        [System.Int32]$NumberOfDays=7
    )

    $csv=Import-Csv .\DBServer.csv|sort servers
     
    $StartTime=(Get-Date).AddDays(-$NumberOfDays)
    $CheckResults= @()
    $FinalResults= @()
       

    foreach -parallel  ($server in $csv.servers)
    
    {
         Sequence
         {
         
             
             #$Server
             $cluster= $server -Split 'db'
             $cluster=$cluster[0] 
             #$Cluster               
             $events=Get-WinEvent -ErrorAction Ignore -FilterHashtable @{LogName='Microsoft-Windows-FailoverClustering/Operational';StartTime=$StartTime} -PSComputerName $server|where {$_.id -eq '1650' -and $_.message -like 'Cluster has missed two consecutive heartbeats for the local endpoint*' }
             #$events
         
         
            if ($events)

            {
                
                #if ($server -like 'D01EASCL9DB*'){$events}
                $eventsCount=$events.Count
                if (!$eventsCount) {$eventscount='1'}
                
                $BadEventObj=New-Object psobject -Property @{
                     ComputerName=$server             
                     Message="Server $server has $eventscount errors"
                     Cluster=$cluster 
                     ErrorsCount=$eventscount
                     Category='Stats'
                               
                     }
                    $Workflow:CheckResults+=$BadEventObj
             }
             else
             {
                $GoodEventObj=New-Object psobject -Property @{
                 ComputerName=$server             
                 Message="Server $server has 0 errors"
                 cluster=$cluster
                 ErrorsCount='0'
                 Category='Stats'             
             }
             $Workflow:CheckResults+=$GoodEventObj  
          }
         
             foreach ($event in $events)
             {
             
                 $EventObj=New-Object psobject -Property @{
                 ComputerName=$server
                 DateTime=$event.TimeCreated
                 Hour=$event.TimeCreated.hour
                 DayOfWeek=$event.TimeCreated.DayOfWeek
                 DayofWeekValue=$event.TimeCreated.DayOfWeek.value__
                 Message=$event.message
                 Cluster=$cluster
                 Category='Errors'             
                 }
             #$EventObj|Add-Member -MemberType NoteProperty -Name 'ComputerName' -Value $server
             #$EventObj|Add-Member -MemberType NoteProperty -Name 'DateTime' -Value $event.TimeCreated
             $Workflow:FinalResults += $EventObj
             
             }         
          }
    }

    Return $CheckResults,$FinalResults
}


Function Get-HearbeatStats
{
     Param
    (
        [Parameter(Mandatory=$true)]
        $Stats,
        [Parameter(Mandatory=$true)]
        $Errors
    )
    
    "`nTotal Stats for last $NumberOfDays days"
    $stats|sort Computername|ft Cluster,Computername,Message,errorscount
    $ErrorsCount=$Errors.Count
    "`nNumber of total errors for last Week is $ErrorsCount"
    "`nHeartbeat errors of clusters for last $NumberOfDays days"
    $Errors|Group-Object Cluster|select name,count|sort name
    "`nHearbeat errors of servers for last $NumberOfDays days"
    $Errors|Group-Object Computername|select name,count|sort name
}

Function Get-HeatbeatHourlyStats
{
    Param
    (
        [Parameter(Mandatory=$true)]
        $Errors,
        [Parameter(Mandatory=$true)]
        $NumberOfDays,
        [switch]$DetailedServerErrors,
        [switch]$ServerErrors
        
    )

    $i=0
    Do 
    {
        $DateOfStats=Get-Date -Date (get-date).Date.AddDays(-$i)  -format D
        $StartTime=0
        $Increment=2
        "Stats of errors for $DateOfStats`n"
        Do
        {
            $IncTime=$StartTime+$Increment
            $TimeA=get-date -Date (get-date).Date.AddDays(-$i).AddHours($StartTime)
            $TimeB=get-date -Date (get-date).Date.AddDays(-$i).AddHours($IncTime)           
            $IntervalErrors=$Errors|Where {$_.datetime -gt $TimeA -and $_.datetime -le $TimeB}
            if($IntervalErrors)
            {
                "Errors discovered from $StartTime`:00 to $IncTime`:00"        
                "`nCluster Stats"
                $IntervalErrors|Group-Object cluster|select name,count|sort name|ft                
                If ($ServerErrors){"`nServer Stats";$IntervalErrors |Group-Object computername|select name,count|sort name|ft}              
                if ($DetailedServerErrors){"`log Error";$IntervalErrors |sort datetime|ft}
            }
           <# Else
            {
             # "`nThere is no errors from $StartTime`:00 to $IncTime`:00" 
            }#>
            $StartTime=$StartTime+$Increment
        }
        While ($StartTime -lt 24)
        $i++ 
    }
    While ($i -le $NumberOfDays)
}

    $NumberOfDays=Read-Host "Specify number of days for statistic collection. Recommended count is 7 (Depend on log size of servers)."
    $log=Get-HearbeatErrors -NumberOfDays $NumberOfDays
    $Stats=$log[0]
    $Errors=$log[1]
    #Menu1             
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        "Yes."
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "no."
        $Detailed =New-Object System.Management.Automation.Host.ChoiceDescription "&VeryDetailedInfo", `
        "Detailed info"
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
        $title='Choice'
        $message="Do you want to get total statistics for last $NumberOfDays Days ?"  
        $result =$host.ui.PromptForChoice($title, $message, $options, 0)         
        switch ($result)
            {
                0 {"You selected Yes.";Get-HearbeatStats -Stats $Stats -Errors $Errors}
                1 {"You selected No."}
            } 
    #Menu2
        $message="Do you want to get hourly statistics for last $NumberOfDays Days ?"  
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$Detailed, $no ) 
        $result =$host.ui.PromptForChoice($title, $message, $options, 0)      
        switch ($result)
            {
                0 {"You selected Yes.";Get-HeatbeatHourlyStats -Errors $Errors -NumberOfDays $NumberOfDays}
                1 {"You selected Detailed.";Get-HeatbeatHourlyStats -Errors $Errors -NumberOfDays $NumberOfDays -DetailedServerErrors}
                2 {"You selected No.";}
            }

        Pause

    
    







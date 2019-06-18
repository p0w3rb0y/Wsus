#Variables per Datacenter

$useproxy = $False #set to false if it's a replica server
$proxyname = "proxy.contoso.eu"
$proxyserverport = "3128"
$IsReplicaServer = $True #to change to $true if its a replica wsus server
$GetContentfromMU = $False #to change to $false if its a replica wsus server
$UpstreamWsusServerName = "server.contoso.eu" # Hostname of upstream server fully qualified name
$UpstreamWsusServerPortNumber = "8530" #Port of upstream server
#

#Cloud.EU and .com sites to create in target computers
$eusites = "wo3","am3","muc"
$comsites = "all","am2","aus","fra","infrastructure","lit","syd","tor","wok"


##############   start   ######################
Write-Verbose "Installing Windows Feature WSUS" -Verbose
Install-WindowsFeature -Name UpdateServices -IncludeManagementTools
New-Item -Path D: -Name WSUS -ItemType Directory
CD "C:\Program Files\Update Services\Tools"
.\wsusutil.exe postinstall CONTENT_DIR=D:\WSUS
 
Write-Verbose "Get WSUS Server Object" -Verbose
$wsus = Get-WSUSServer
Write-Verbose "Connect to WSUS server configuration" -Verbose
$wsusConfig = $wsus.GetConfiguration()
 
Write-Verbose " Creating Target Groups" -Verbose
$wsusConfig.IsReplicaServer = $False #Replica Mode needs to be false to create the groups, it will be overwritten late in the script for the right value
$wsusConfig.Save()
if($env:USERDNSDOMAIN -match "contoso.eu") {
    $eusites | foreach {
                    $wsus.CreateComputerTargetGroup($_)            
               }
}
else {
    $comsites | foreach {
                    $wsus.CreateComputerTargetGroup($_)
                }
}

if ($IsReplicaServer -like $False){
    Write-Verbose "Set to download updates from Microsoft Updates" -Verbose
    Set-WsusServerSynchronization -SyncFromMU
} 
Write-Verbose "Set Update Languages to English and save configuration settings" -Verbose
$wsusConfig.AllUpdateLanguagesEnabled = $false           
$wsusConfig.SetEnabledUpdateLanguages("en")
$wsusConfig.UseProxy = $useproxy
if ($useproxy -like $True){
    Write-Verbose "Configuring Proxy server options"
    $wsusConfig.ProxyName = $proxyname
    $wsusConfig.ProxyServerPort = $proxyserverport
}

if ($IsReplicaServer -like $true){
    Write-Verbose "Configuring Replica server options"
    $wsusConfig.UpstreamWsusServerName = $UpstreamWsusServerName
    $wsusConfig.UpstreamWsusServerPortNumber = $UpstreamWsusServerPortNumber
    $wsusConfig.SyncFromMicrosoftUpdate = $false
    $wsusConfig.GetContentFromMU = $GetContentfromMU
    } 
$wsusConfig.IsReplicaServer = $IsReplicaServer
$wsusConfig.TargetingMode = "Client"
$wsusConfig.Save()
 
Write-Verbose "Get WSUS Subscription and perform initial synchronization to get latest categories" -Verbose
$subscription = $wsus.GetSubscription()
$subscription.StartSynchronizationForCategoryOnly()
 
 While ($subscription.GetSynchronizationStatus() -ne 'NotProcessing') {
 Write-Host "." -NoNewline
 Start-Sleep -Seconds 5
 }
 
Write-Verbose "Sync is Done" -Verbose
 
Write-Verbose "Disable Products" -Verbose
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Office" } | Set-WsusProduct -Disable
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows" } | Set-WsusProduct -Disable
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Azure" } | Set-WsusProduct -Disable
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Driver"} | Set-WsusProduct -Disable

 
Write-Verbose "Enable Products" -Verbose
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Server 2016" } | Set-WsusProduct
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Server 2012" } | Set-WsusProduct
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -like "Windows Server 2012 R2" } | Set-WsusProduct
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -like "Windows Server 2008 R2" } | Set-WsusProduct
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows server manager" } | Set-WsusProduct
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -like "Office 2013" } | Set-WsusProduct
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -like "Office 2016" } | Set-WsusProduct
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "ASP.NET" } | Set-WsusProduct
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Developer Tools"} | Set-WsusProduct

Write-Verbose "Disable more Products" -Verbose
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Azure" } | Set-WsusProduct -Disable

if($env:USERDNSDOMAIN -match "contoso.com") {
    Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -like "Windows Server 2008" } | Set-WsusProduct
    Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -like "Office 2010" } | Set-WsusProduct
    Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -like "Capicom" } | Set-WsusProduct
    Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Server 2003" } | Set-WsusProduct
    }


Write-Verbose "Disable Language Packs" -Verbose
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Language Packs" } | Set-WsusProduct -Disable
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Server 2012 R2 and later drivers" } | Set-WsusProduct -Disable
Get-WsusServer | Get-WsusProduct | Where-Object -FilterScript { $_.product.title -match "Windows Server 2016 and Later Servicing Drivers" } | Set-WsusProduct -Disable

 
Write-Verbose "Configure the Classifications" -Verbose
 
 Get-WsusClassification | Where-Object {
 $_.Classification.Title -in (
 'Critical Updates',
 'Definition Updates',
 'Security Updates',
 'Service Packs',
 'Tools',
 'Update Rollups',
 'Updates')
 } | Set-WsusClassification
 

if ($IsReplicaServer -like $False){
    Write-Verbose "Configure Default Approval Rule" -Verbose
    [void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
    $rule = $wsus.GetInstallApprovalRules() | Where {
        $_.Name -eq "Default Automatic Approval Rule"}
    $class = $wsus.GetUpdateClassifications() | ? {$_.Title -In (
        'Critical Updates',
        'Definition Updates',
        'Feature Packs',
        'Security Updates',
        'Service Packs',
        'Tools',
        'Update Rollups',
        'Updates',
        'Upgrades')}
    $class_coll = New-Object Microsoft.UpdateServices.Administration.UpdateClassificationCollection
    $class_coll.AddRange($class)
    $rule.SetUpdateClassifications($class_coll)
    $rule.Enabled = $True
    $rule.Save()
    Write-Verbose "Run Default Approval Rule" -Verbose
    $rule.ApplyRule()
}

Write-Verbose "Configure Synchronizations" -Verbose
$subscription.SynchronizeAutomatically=$true
 
Write-Verbose "Set synchronization scheduled for midnight each night" -Verbose
$subscription.SynchronizeAutomaticallyTimeOfDay= (New-TimeSpan -Hours 0)
$subscription.NumberOfSynchronizationsPerDay=1
$subscription.Save()

Write-Verbose "Configuring IIS WsusPool" -Verbose
Import-Module WebAdministration
Set-ItemProperty -Path "IIS:\AppPools\WsusPool" -name failure.loadBalancerCapabilities -value TcpLevel -Verbose
Set-ItemProperty -Path "IIS:\AppPools\WsusPool" -Name queueLength -Value 25000 -Verbose
Set-ItemProperty -Path "IIS:\AppPools\WsusPool" -name cpu.limit -value 15 -Verbose
Set-ItemProperty -Path "IIS:\AppPools\WsusPool" -name Recycling.periodicRestart.privateMemory -Value 0 -Verbose
 
Write-Verbose "Kick Off Synchronization" -Verbose
$subscription.StartSynchronization()
 
Write-Verbose "Monitor Progress of Synchronisation" -Verbose
 
Start-Sleep -Seconds 60 # Wait for sync to start before monitoring
 while ($subscription.GetSynchronizationProgress().ProcessedItems -ne $subscription.GetSynchronizationProgress().TotalItems) {
 $subscription.GetSynchronizationProgress().ProcessedItems * 100/($subscription.GetSynchronizationProgress().TotalItems)
 Start-Sleep -Seconds 5
 }


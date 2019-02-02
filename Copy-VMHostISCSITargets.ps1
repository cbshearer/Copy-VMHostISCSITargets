## Add Snap-in and connect to your vCenter Server
    Add-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue
    Connect-VIServer vCenterServer.your.local

## Initialize variables
    $SourceVMHost = get-vmhost your-esxi01.your.local
    $TargetVMHost = get-vmhost your-esxi02.your.local
    $TargetVMhbas = $TargetVMHost | Get-VMHostHba -type IScsi # -Device vmhba64 ## Uncomment the device parameter and specify which device if you want to only add targets to one device
        ## List your HBAS with these commands if you only want to target a specific HBA and not all of your HBAs: 
            ## $TargetEsxCli = $TargetVMHost | Get-EsxCli
            ## $targetesxcli.iscsi.adapter.list()
    $Result       = $null
    $TargetsToAdd = @()

## Limit yourself here if you are just testing and dont want to make the same mistake more than this number of times.
    $Max = 2
    $n   = 0

## Get ESXCLI for the source and target hosts
    $SourceEsxCli = $SourceVMHost | Get-EsxCli
    $TargetEsxCli = $TargetVMHost | Get-EsxCli

## Get targets from the source host
    $iSCSITargets = $SourceEsxCli.iscsi.adapter.discovery.statictarget.list()

## Get all targets and only add the target address (ip) and target name (iscsi name) into an array ($TargetsToAdd).
    foreach ($iSCSITarget in $iSCSITargets) { $TargetsToAdd += $iSCSITarget.TargetAddress + "," + $iSCSITarget.TargetName }

## Remove duplicates now that additional parameters are gone
    $TargetsToAdd = $TargetsToAdd | Select-Object -Unique 
        
## For each VMHBA on the target VMhost, add all of the iSCSITargets
foreach ($TargetVMHba in $TargetVMhbas) ## For each Target HBA
    {
        foreach ($iSCSITargetToAdd in $TargetsToAdd) ## For each iSCSI Target
            {   
                if ($n -lt $max) ## if we are within the bounds of our max counter limit
                    {   
                        ## Pull the values out of the array one at a time.
                        $iSCSITarget_Addy = $iSCSITargetToAdd.split(",")[0]
                        $iSCSITarget_Name = $iSCSITargetToAdd.split(",")[1]

                        ## Write to screen what we are about to do.
                        Write-Host "============="
                        Write-Host "Adding target : " -nonewline; write-host -f Cyan $iSCSITarget_Name
                        write-host "At address    : " -nonewline; write-host -f Cyan $iSCSITarget_Addy
                        Write-Host "To host       : " -NoNewline; write-host -f Yellow $TargetVMHost.Name
                        Write-Host "To HBA        : " -NoNewline; write-host -f Yellow $TargetVMHba.Name
                        
                        ## This adds the current target address / name ( $iSCSTargetAddy / $iSCSITarget_Name) and adds them to the current HBA on our target host ($TargetVMHba).
                        ## The result is stored in a variable, will be $true or $false
                        $Result = $TargetEsxCli.iscsi.adapter.discovery.statictarget.add($TargetVMHba, $iSCSITarget_Addy, $iSCSITarget_Name) 

                        if ($Result -eq $true) ## If it succeeded, then say so in happy green.
                            {
                                Write-Host "Result        : " -nonewline; write-host -f green "Success"
                                $n = $n +1
                            }
                        else {Write-Host -f Red "Something went wrong."} ## If it failed, just note that something went wrong.
                    }
            }
    }

## Display the number of iscsi targets added, keep in mind this is the grand total across all HBAs.
    Write-Host "============="
    Write-Host "Successfully added iSCSI targets : " -nonewline; Write-Host -f Green $n 
    Write-Host "iSCSI targets read from host     : " -nonewline; Write-Host -f Cyan $SourceVMHost.Name
    Write-Host "iSCSI targets added  to host     : " -NoNewline; Write-Host -f Yellow $TargetVMHost.Name

if (!($n)) {exit} ## exit if we didn't add anything

Function Invoke-ScanAndRefresh 
    {
        Write-Host "Rescanning all HBAs."
            $TargetVMHost | Get-VMHostStorage -RescanAllHba | Out-Null

        Write-Host "Rescanning VMFS volumes."
            $TargetVMHost | Get-VMHostStorage -RescanVmfs   | Out-Null

        Write-Host "Refreshing storage."
            $TargetVMHost | Get-VMHostStorage -Refresh      | Out-Null
    }

Function Invoke-Menu
    {
    write-host "============="
    write-host -f cyan "Please make a selection."
    $value = read-host "
        S: Scan HBAs & Volumes and Refresh host storage`
        X: Exit`

Choose wisely (S/X)"
            Switch ($value)
                {
                'S' {Invoke-ScanAndRefresh
                     exit}
                'X' {exit}
                default {Invoke-Menu}
                }
    }

## Run the menu to give the option to scan HBAs & Volumes and Refresh host storage 
    Invoke-Menu

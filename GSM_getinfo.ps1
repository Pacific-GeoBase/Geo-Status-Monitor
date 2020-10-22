if ($args.count -ge 2 -and $args[0] -eq "-f") {
	$configFile = $args[1]
} else {
	$configFile = ".\GSM_config.ps1"
}
#$PrevComputer = '-'

. $configFile

$htmlOut = @()
#$css = "<style>th {border-bottom: 2px solid black;} tr:nth-child(even) {background-color: #CCCCCC;} td {padding-left: 10px; padding-right: 20px;} h1{color:DodgerBlue; background-color: #lightblue; vertical-align: middle}</style>"
#$header = "<h1><img src='images/PACAF_GeoBase.png' width='100'/>GeoBase Systems Monitor (beta version)<br/></h1><br/><br/><br/>"
$curTime = Get-Date -Format "MM/dd/yyyy HH:mm"
$statusColor = "Black"

$htmlOut += "<div style='margin-left:20px'>Last updated: {0} HST</div>" -f $curTime
$htmlOut += "<table>"
$htmlOut += "<tr><th>Hostname</th><th>Uptime</th><th>LogicalDisks <i>( < 25% )</i></th><th>Memory</th><th>ArcGIS</th><th>Oracle</th><th>HyperV</th></tr>"
	
foreach ($Computer in $Computers.GetEnumerator())
{
	$uptimeColor = "Black"
	$diskColor = "Black"
	$Disklist = ""

    try 
    {
        $session = New-CimSession -ComputerName $Computer[0] 2> $null
        $OS = Get-CimInstance -Class Win32_OperatingSystem -CimSession $session
		$procs = Get-CimInstance -Class Win32_Process -CimSession $session
#        $Processor = Get-CimInstance -Class Win32_Processor -CimSession $session
        $Network = Get-CimInstance -Class Win32_NetworkAdapterConfiguration -CimSession $session
#        $Network2 = Get-CimInstance -Class Win32_NetworkAdapter -CimSession $session
        $Disks = Get-CimInstance -Class Win32_LogicalDisk -CimSession $session
#        $Pagefile = Get-CimInstance -Class Win32_PageFileSetting -CimSession $session
		Remove-CimSession -CimSession $session -ErrorAction SilentlyContinue
	}
    catch 
    {
		$uptimeColor = "DarkRed"
		$statusColor = "DarkRed"
    }

#    if ($PrevComputer -ne '-' -and ($Computer[1] -eq 'V')) {
#		$VMstatus = Get-VM -Computername $PrevComputer -Name $Computer[0]
#		$Updays = ($VMstatus.Uptime).Days
#		$Uphours = ($VMstatus.Uptime).Hours
#		$PrevComputer = '-'
#	} else {
		$Uptime = New-TimeSpan $OS.LastBootUpTime $OS.LocalDateTime -ErrorAction SilentlyContinue
		$Updays = $Uptime.Days
		$Uphours = $Uptime.Hours
		$PrevComputer = $Computer[0]
#	}
	
	if ($uptimeColor -ne "DarkRed" -and $Uptime.Days -eq 0 -and $Uptime.Hours -lt 4) {
		if ($statusColor -ne "DarkRed") {
			$statusColor = "DarkOrange"
		}
		$uptimeColor = "DarkOrange"
	}


	foreach ($Disk in $Disks) {
		if ($Disk.DriveType -eq 3 -and $Disk.Size -notlike $null) {
			$freePct = ($Disk.FreeSpace / $Disk.Size) * 100;
			if ($freePct -lt 25) {
				$Disklist += "{0}\ ({1}) = {2:N2} / {3:N2} GB ({4:N1}% Free)<br/>" -f $Disk.DeviceID, $Disk.VolumeName, ($Disk.FreeSpace / 1GB), ($Disk.Size / 1GB), $freePct

				if ($freePct -lt 5) {
				    $diskColor = "DarkRed"
				    $statusColor = "DarkRed"
				}
			}
		}
	}

#	$IPAddress = ($Network | ? IPEnabled -eq $true | % { "{0}" -f ($_.IPAddress) }  | Out-String).trim()
	$IPAddress = ($Network | ? IPEnabled -eq $true | % { $_.IPAddress[0] })

	if ($uptimeColor -eq "DarkRed") {
 		$row = "<tr><td style='color:DarkRed'>{0}</td><td style='color:DarkRed'>DOWN</td><td></td><td></td><td><img src='images/down.ico'/></td><td><img src='images/down.ico'/></td><td><img src='images/down.ico'/></td>" -f $Computer[0]
	} else {
		$row = "<tr><td><b>{0}</b><br/><i>    {1}</i></td><td style='color:{2}'>{3}d {4}h</td><td style='color:{5}'>{6}</td><td>{7:N2} / {8:N2} GB ({9:N1}% Free)</td>" -f $Computer[0], $IPAddress, $uptimeColor, $Updays, $Uphours, $diskColor, $Disklist, ($OS.FreePhysicalMemory / 1MB), ($OS.TotalVisibleMemorySize / 1MB), (($OS.FreePhysicalMemory / $OS.TotalVisibleMemorySize) * 100)

		if ($Computer[1] -eq 'V') {
			$row += "<td>    -</td><td>    -</td><td>    -</td>"
		} else {
			$result = $procs | where Name -match 'arcgis.exe'
			if ($result -eq $null) {
				$row += "<td><img src='images/down.ico'/></td>"
				$statusColor = "DarkRed"
			} else {
				$row += "<td><img src='images/up.ico'/></td>"
			}
			$result = $procs | where Name -match 'oracle.exe'
			if ($result -eq $null) {
				$row += "<td><img src='images/down.ico'/></td>"
				$statusColor = "DarkRed"
			} else {
				$row += "<td><img src='images/up.ico'/></td>"
			}
			$result = $procs | where Name -match 'vmcompute.exe'
			if ($result -eq $null) {
				$row += "<td><img src='images/down.ico'/></td>"
				$statusColor = "DarkRed"
			} else {
				$row += "<td><img src='images/up.ico'/></td>"
			}
		}
	}

    $htmlOut += $row + "</tr>"
}


$htmlOut += "</table>"


try {
    $htmlOut | out-file $outputFile
}
catch {
    "Unable to update html " + $outputFile
}

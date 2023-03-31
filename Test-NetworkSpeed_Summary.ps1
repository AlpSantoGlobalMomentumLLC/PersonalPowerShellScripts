# Axel Christian Lenz 
# https://www.linkedin.com/in/axellenz/
# Read the computer list with names from the file
$computers = Get-Content "computers.txt"

# Set the intervals for the main loop and summary loop
$interval = 15 * 60 * 1000 # 15 minutes in milliseconds
$summaryInterval = 3 * 60 * 60 * 1000 # 3 hours in milliseconds

function Test-NetworkSpeed {
    param (
        [string]$Computer,
        [string]$Name
    )

    $result = Test-Connection -ComputerName $Computer -Count 1 -ErrorAction SilentlyContinue

    $speed = if ($result) { $result.ResponseTime } else { 0 }
    $status = if ($result) { "Online" } else { "Offline" }

    return @{
        Computer = $Computer
        Name = $Name
        Speed = $speed
        Status = $status
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

function Write-Summary {
    $allResults = Import-Csv -Path "results.csv"
    $summaryData = @()

    foreach ($computerLine in $computers) {
        $computerData = $computerLine.Split(',')
        $computer = $computerData[0]
        $name = $computerData[1]

        $computerResults = $allResults | Where-Object {$_.Computer -eq $computer}
        $onlineResults = $computerResults | Where-Object {$_.Status -eq "Online"}
        $best = $onlineResults | Measure-Object -Property Speed -Minimum | Select-Object -ExpandProperty Minimum
        $worst = $onlineResults | Measure-Object -Property Speed -Maximum | Select-Object -ExpandProperty Maximum
        $average = $onlineResults | Measure-Object -Property Speed -Average | Select-Object -ExpandProperty Average

        $summaryData += [PSCustomObject]@{
            Computer = $computer
            Name = $name
            Best = $best
            Worst = $worst
            Average = $average
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }

    $summaryData | Export-Csv -Path "summary.csv" -NoTypeInformation -Append
}

$csvHeader = "Computer,Name,Speed,Status,Timestamp`n"
Add-Content -Path "results.csv" -Value $csvHeader
$lastSummaryTime = Get-Date

while ($true) {
    foreach ($computerLine in $computers) {
        $computerData = $computerLine.Split(',')
        $computer = $computerData[0]
        $name = $computerData[1]

        $testResult = Test-NetworkSpeed -Computer $computer -Name $name
        $testResultString = "$($testResult.Computer),$($testResult.Name),$($testResult.Speed),$($testResult.Status),$($testResult.Timestamp)"
        Add-Content -Path "results.csv" -Value $testResultString
    }

    $currentTime = Get-Date
    if (($currentTime - $lastSummaryTime).TotalMilliseconds -ge $summaryInterval) {
        Write-Summary
        $lastSummaryTime = $currentTime
    }

    Start-Sleep -Milliseconds $interval
}

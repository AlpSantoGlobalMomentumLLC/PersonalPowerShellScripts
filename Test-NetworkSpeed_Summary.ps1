# Axel Christian Lenz 
# https://www.linkedin.com/in/axellenz/
# Read the computer list with names from the file
$basePath = "C:\TEMP"

# Here in every line an IP or a HOST name
$computers = Get-Content -Path (Join-Path $basePath "computers.txt")

# Set the intervals for the main loop and summary loop
$interval = 1 * 60 * 1000 # 1 minute in milliseconds
$summaryInterval = 3 * 60 * 1000 # 10 minutes in milliseconds

function Test-NetworkSpeed {
    param ($Computer, $Name)
    $result = Test-Connection -ComputerName $Computer -Count 1 -ErrorAction SilentlyContinue
    @{
        Computer = $Computer
        Name = $Name
        Speed = if ($result) { $result.ResponseTime } else { 0 }
        Status = if ($result) { "Online" } else { "Offline" }
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

function Write-Summary {
    $allResults = Import-Csv -Path (Join-Path $basePath "results.txt")
    $summaryData = $computers | ForEach-Object {
        $computerData = $_.Split(',')
        $computer = $computerData[0]
        $name = $computerData[1]
        $onlineResults = $allResults | Where-Object {$_.Computer -eq $computer -and $_.Status -eq "Online"}
        if ($onlineResults) {
            $best = ($onlineResults | Measure-Object -Property Speed_ms -Minimum).Minimum
            $worst = ($onlineResults | Measure-Object -Property Speed_ms -Maximum).Maximum
            $average = ($onlineResults | Measure-Object -Property Speed_ms -Average).Average
        } else {
            $best = $null
            $worst = $null
            $average = $null
        }
        [PSCustomObject]@{
            Computer = $computer
            Name = $name
            Best = $best
            Worst = $worst
            Average = $average
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    $summaryData | Export-Csv -Path (Join-Path $basePath "summary.txt") -NoTypeInformation -Append
}

$header = "Computer,Name,Speed_ms,Status,Timestamp"
if (-not (Get-Content -Path (Join-Path $basePath "results.txt") -First 1) -eq $header) {
    Add-Content -Path (Join-Path $basePath "results.txt") -Value $header
}
$lastSummaryTime = Get-Date

while ($true) {
    foreach ($computerLine in $computers) {
        $computerData = $computerLine.Split(',')
        $testResult = Test-NetworkSpeed -Computer $computerData[0] -Name $computerData[1]
        Add-Content -Path (Join-Path $basePath "results.txt") -Value "$($testResult.Computer),$($testResult.Name),$($testResult.Speed),$($testResult.Status),$($testResult.Timestamp)"
    }

    if (((Get-Date) - $lastSummaryTime).TotalMilliseconds -ge $summaryInterval) {
        Write-Summary
        $lastSummaryTime = Get-Date
    }

    Start-Sleep -Milliseconds $interval
}

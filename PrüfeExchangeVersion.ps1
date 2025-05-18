# Set the lowest priority for the current process
$process = Get-Process -Id $PID
$process.PriorityClass = "Idle"

# Funktion zur Überprüfung, ob das Skript auf einem Exchange-Server ausgeführt wird
function Test-IsExchangeServer {
    try {
        $exchangeInstallPath = (Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ExchangeServer\v15\Setup -ErrorAction Stop).MsiInstallPath
        return $true
    } catch {
        return $false
    }
}

# Setze TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Definiere die Anzahl der Tage für den Updatezeitraum
$updatePeriodDays = $env:xTageSeitUpdate


# Funktion zum Abrufen der Exchange-Versionsinformationen
function Get-ExchangeVersionInfo {
    param (
        [string]$Url,
        [string]$StartMarker,
        [string]$EndMarker
    )

    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing
    $html = $response.Content
    $tableStartIndex = $html.IndexOf($StartMarker)
    $tableEndIndex = $html.IndexOf($EndMarker)
    $tableHtml = $html.Substring($tableStartIndex, $tableEndIndex - $tableStartIndex)
    $rows = $tableHtml -split '</tr>' | Select-Object -Skip 1

    $versions = @{}
    foreach ($row in $rows) {
        $cells = $row -split '</td>' | Select-Object -SkipLast 1
        if ($cells.Count -ge 4) {
            $version = $cells[0] -replace '<.*?>'
            $cu = $cells[3] -replace '<.*?>' | ForEach-Object { $_.Trim() }
            $releaseDate = $cells[1] -replace '<.*?>' | ForEach-Object { $_.Trim() }
            if ($cu -ne "") {
                $name = $version.Substring($version.IndexOf("Exchange"))
                $versions[$version] = [pscustomobject]@{
                    "Name" = $name.Trim()
                    "Buildnummer" = $cu
                    "Veröffentlichungsdatum" = [DateTime]::ParseExact($releaseDate, "MMMM d, yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
                }
            }
        }
    }

    return $versions.Values | Sort-Object Veröffentlichungsdatum -Descending
}

# Hauptskript
if (-not (Test-IsExchangeServer)) {
    Write-Host "Abgebrochen, weil die kein Exchange ist." -ForegroundColor Yellow
    exit 0
}

$url = "https://docs.microsoft.com/en-us/exchange/new-features/build-numbers-and-release-dates?view=exchserver-2019"

$exchangeServer2019Versions = Get-ExchangeVersionInfo -Url $url -StartMarker '<h2 id="exchange-server-2019">' -EndMarker '<h2 id="exchange-server-2016">'
$exchangeServer2016Versions = Get-ExchangeVersionInfo -Url $url -StartMarker '<h2 id="exchange-server-2016">' -EndMarker '<h2 id="exchange-server-2013">'
$exchangeServer2013Versions = Get-ExchangeVersionInfo -Url $url -StartMarker '<h2 id="exchange-server-2013">' -EndMarker '<h2 id="exchange-server-2010">'

$myBuildNumber = (Get-Command Exsetup.exe | ForEach-Object { $_.FileVersionInfo }).ProductVersion

if ([string]::IsNullOrEmpty($myBuildNumber)) {
    Write-Host "Die Produktversion konnte nicht abgerufen werden." -ForegroundColor Red
    exit 1
}

$exchangeServer = switch -Wildcard ($myBuildNumber) {
    "15.00*" { "Exchange Server 2013"; $exchangeServer2013Versions[0] }
    "15.01*" { "Exchange Server 2016"; $exchangeServer2016Versions[0] }
    "15.02*" { "Exchange Server 2019"; $exchangeServer2019Versions[0] }
    default { 
        Write-Host "Es konnte keine passende Exchange Server-Version gefunden werden." -ForegroundColor Red
        exit 1
    }
}

$latestVersion = $exchangeServer[1]
$minUpdatePeriod = [TimeSpan]::FromDays($updatePeriodDays)
$currentDate = Get-Date

if ($myBuildNumber -eq $latestVersion.Buildnummer) {
    Write-Host "$($exchangeServer[0]): Die Version ist aktuell." -ForegroundColor Green
} elseif (($currentDate - $latestVersion.Veröffentlichungsdatum) -ge $minUpdatePeriod) {
    $daysSinceRelease = ($currentDate - $latestVersion.Veröffentlichungsdatum).Days
    Write-Host "Ihr $($exchangeServer[0]) Version: $myBuildNumber ist veraltet. Die neueste Buildnummer ist $($latestVersion.Buildnummer) vom $($latestVersion.Veröffentlichungsdatum.ToString('d. MMMM yyyy'))" -ForegroundColor Red
    Write-Host "ALERT: Das Update ist seit $daysSinceRelease Tagen verfügbar und überschreitet den definierten Zeitraum von $updatePeriodDays Tagen." -ForegroundColor Yellow
    exit 1
} else {
    $daysSinceRelease = ($currentDate - $latestVersion.Veröffentlichungsdatum).Days
    $daysRemaining = $updatePeriodDays - $daysSinceRelease
    Write-Host "$($exchangeServer[0]): Ein Update ist verfügbar, aber noch nicht länger als $updatePeriodDays Tage. Aktuelle Version: $myBuildNumber, Neueste Version: $($latestVersion.Buildnummer) vom $($latestVersion.Veröffentlichungsdatum.ToString('d. MMMM yyyy'))" -ForegroundColor Yellow
    Write-Host "Das Update ist seit $daysSinceRelease Tagen verfügbar. Noch $daysRemaining Tage bis zum empfohlenen Update-Zeitpunkt." -ForegroundColor Yellow
    exit 0
}

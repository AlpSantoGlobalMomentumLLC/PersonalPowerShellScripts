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
    if ($tableStartIndex -lt 0 -or $tableEndIndex -lt 0) { # Fehlerbehandlung für Marker
        Write-Warning "Einer der Marker ('$StartMarker' oder '$EndMarker') wurde nicht in der URL '$Url' gefunden."
        return @() # Leeres Array zurückgeben
    }
    $tableHtml = $html.Substring($tableStartIndex, $tableEndIndex - $tableStartIndex)
    $rows = $tableHtml -split '</tr>' | Select-Object -Skip 1

    $versions = @{}
    foreach ($row in $rows) {
        $cells = $row -split '</td>' | Select-Object -SkipLast 1
        if ($cells.Count -ge 4) {
            $version = $cells[0] -replace '<.*?>'
            # Spalte 4 (Index 3) für das Langformat der Buildnummer verwenden
            $cu = $cells[3] -replace '<.*?>' | ForEach-Object { $_.Trim() } 
            $releaseDate = $cells[1] -replace '<.*?>' | ForEach-Object { $_.Trim() }
            if ($cu -ne "" -and $releaseDate -match "\w+ \d{1,2}, \d{4}") { # Zusätzliche Prüfung für gültiges Datumsformat
                $name = $version.Substring($version.IndexOf("Exchange"))
                try {
                    $versions[$version] = [pscustomobject]@{
                        "Name" = $name.Trim()
                        "Buildnummer" = $cu
                        "Veröffentlichungsdatum" = [DateTime]::ParseExact($releaseDate, "MMMM d, yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
                    }
                } catch {
                    Write-Warning "Fehler beim Parsen des Datums '$releaseDate' für Version '$version'. Eintrag wird übersprungen."
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
# --- ANFANG ÄNDERUNG ---
# Array für zu ignorierende Buildnummern (Langformat)
$ignoreBuildNumbers = @(
    "15.02.1748.024",
    "15.02.1544.025" 
)
# --- ENDE ÄNDERUNG ---

$exchangeServer2019Versions = Get-ExchangeVersionInfo -Url $url -StartMarker '<h2 id="exchange-server-2019">' -EndMarker '<h2 id="exchange-server-2016">'
# --- ANFANG ÄNDERUNG ---
# Filtere alle ignorierten Buildnummern heraus
$exchangeServer2019Versions = $exchangeServer2019Versions | Where-Object {$_.Buildnummer -notin $ignoreBuildNumbers}
# --- ENDE ÄNDERUNG ---
$exchangeServer2016Versions = Get-ExchangeVersionInfo -Url $url -StartMarker '<h2 id="exchange-server-2016">' -EndMarker '<h2 id="exchange-server-2013">'
# Optional: Filtern auch für 2016, falls nötig
# $exchangeServer2016Versions = $exchangeServer2016Versions | Where-Object {$_.Buildnummer -notin $ignoreBuildNumbersFor2016} 
$exchangeServer2013Versions = Get-ExchangeVersionInfo -Url $url -StartMarker '<h2 id="exchange-server-2013">' -EndMarker '<h2 id="exchange-server-2010">'
# Optional: Filtern auch für 2013, falls nötig
# $exchangeServer2013Versions = $exchangeServer2013Versions | Where-Object {$_.Buildnummer -notin $ignoreBuildNumbersFor2013}

$myBuildNumber = (Get-Command Exsetup.exe | ForEach-Object { $_.FileVersionInfo }).ProductVersion

if ([string]::IsNullOrEmpty($myBuildNumber)) {
    Write-Host "Die Produktversion konnte nicht abgerufen werden." -ForegroundColor Red
    exit 1
}

$exchangeServer = switch -Wildcard ($myBuildNumber) {
    "15.00*" { "Exchange Server 2013"; if ($exchangeServer2013Versions.Count -gt 0) { $exchangeServer2013Versions[0] } else { $null } }
    "15.01*" { "Exchange Server 2016"; if ($exchangeServer2016Versions.Count -gt 0) { $exchangeServer2016Versions[0] } else { $null } }
    "15.02*" { "Exchange Server 2019"; if ($exchangeServer2019Versions.Count -gt 0) { $exchangeServer2019Versions[0] } else { $null } }
    default { 
        Write-Host "Es konnte keine passende Exchange Server-Version gefunden werden." -ForegroundColor Red
        exit 1
    }
}

$latestVersion = $exchangeServer[1]

# Beibehaltung der einfachen Null-Prüfung aus der ursprünglichen korrigierten Version
if ($null -eq $latestVersion) {
    # Diese Meldung erscheint, wenn nach dem Filtern keine gültige "neueste Version" für den erkannten Exchange-Typ übrig bleibt.
    # Das kann bedeuten, dass alle neueren Versionen ignoriert wurden und keine andere passende gefunden wurde,
    # oder die Liste von Microsoft für diesen Exchange-Typ leer war (unwahrscheinlich).
    Write-Host "$($exchangeServer[0]): Konnte keine passende neueste Version finden (möglicherweise wurden alle relevanten Updates ignoriert oder die Liste ist leer)." -ForegroundColor Red
    exit 1 
}

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

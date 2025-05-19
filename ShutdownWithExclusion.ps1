<#
.SYNOPSIS
    Faehrt den Computer herunter, sofern der aktuelle Rechner nicht auf einer vordefinierten Ignorierliste steht.
.DESCRIPTION
    Dieses Skript enthaelt intern eine komma-separierte Liste von Rechnernamen, die vom Herunterfahren ausgeschlossen sind. Vor dem Ausfuehren des Shutdowns wird die Liste auf Syntaxfehler geprueft. Ist die Liste fehlerhaft oder enthaelt sie den lokalen Rechnernamen (Groß-/Kleinschreibung wird ignoriert), wird kein Shutdown durchgefuehrt.
#>

[CmdletBinding()]
param ()

Set-StrictMode -Version Latest
$global:ExitCode = 0

# --- Konfiguration ---
$IgnoredComputersRawString = "CLIENT01, SERVER02,   DESKTOP05, client99, workstationX"

# --- Validierung der Ignorierliste ---
$IgnoredComputerNamesList = @()
$isListSyntaxValid = $true

Write-Verbose "Analysiere die Ignorierliste: '$IgnoredComputersRawString'"

if ([string]::IsNullOrWhiteSpace($IgnoredComputersRawString)) {
    Write-Verbose "Die Ignorierliste ist leer oder besteht nur aus Leerzeichen. Es werden keine Computer ignoriert."
} else {
    $splitItems = $IgnoredComputersRawString -split '\s*,\s*'
    foreach ($item in $splitItems) {
        $trimmedItem = $item.Trim()
        if ([string]::IsNullOrEmpty($trimmedItem)) {
            Write-Error "Syntaxfehler in der Ignorierliste: Ein Eintrag ist nach der Bereinigung leer."
            $isListSyntaxValid = $false
            $global:ExitCode = 1
            break
        }
        $IgnoredComputerNamesList += $trimmedItem
    }
}

# --- Hauptlogik ---
if (-not $isListSyntaxValid) {
    Write-Warning "Der Computer wird aufgrund von Fehlern in der Ignorierliste NICHT heruntergefahren."
} else {
    $CurrentComputerName = $env:COMPUTERNAME
    Write-Verbose "Aktueller Computername: $CurrentComputerName"
    if ($IgnoredComputerNamesList.Count -gt 0) {
        Write-Verbose "Bereinigte und validierte Ignorierliste: $($IgnoredComputerNamesList -join ', ')"
    } else {
        Write-Verbose "Die Ignorierliste ist leer. Es werden keine Computer aktiv ignoriert."
    }

    if ($IgnoredComputerNamesList -icontains $CurrentComputerName) {
        Write-Host "Der Computer '$CurrentComputerName' steht auf der Ignorierliste. Kein Shutdown."
    } else {
        Write-Host "Der Computer '$CurrentComputerName' wird heruntergefahren."
        try {
            Stop-Computer -Force -ErrorAction Stop
        } catch {
            Write-Error "Fehler beim Herunterfahren: $_"
            $global:ExitCode = 2
        }
    }
}

Write-Verbose "Skriptausfuehrung beendet. Exit-Code: $global:ExitCode"
exit $global:ExitCode

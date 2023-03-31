# Axel Christian Lenz 
# https://www.linkedin.com/in/axellenz/

# Compare the installed software on two Windows machines.
# Compare based on DisplayName and DisplayVersion only. 
# Run PS as admin

$RemoteComputerName1 = "Server1"
$RemoteComputerName2 = "Server2"

Remove-Item -Path "InstalledSoftware_PC1.csv" -ErrorAction SilentlyContinue
Remove-Item -Path "InstalledSoftware_PC2.csv" -ErrorAction SilentlyContinue
Remove-Item -Path "SoftwareDifferences.csv" -ErrorAction SilentlyContinue


$Session1 = New-PSSession -ComputerName $RemoteComputerName1
$Session2 = New-PSSession -ComputerName $RemoteComputerName2

$InstalledSoftware1 = Invoke-Command -Session $Session1 -ScriptBlock {
    Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Sort-Object DisplayName
}
$InstalledSoftware2 = Invoke-Command -Session $Session2 -ScriptBlock {
    Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Sort-Object DisplayName
}

$InstalledSoftware1 | Export-Csv -Path InstalledSoftware_PC1.csv -NoTypeInformation -Encoding UTF8
$InstalledSoftware2 | Export-Csv -Path InstalledSoftware_PC2.csv -NoTypeInformation -Encoding UTF8



$PC1 = Import-Csv -Path InstalledSoftware_PC1.csv
$PC2 = Import-Csv -Path InstalledSoftware_PC2.csv

$PC1Unique = $PC1 | ForEach-Object { "{0}|{1}" -f $_.DisplayName, $_.DisplayVersion }
$PC2Unique = $PC2 | ForEach-Object { "{0}|{1}" -f $_.DisplayName, $_.DisplayVersion }

$Differences = Compare-Object -ReferenceObject $PC1Unique -DifferenceObject $PC2Unique

$DifferencesDetails = $Differences | ForEach-Object {
    $displayName, $displayVersion = $_.InputObject.Split('|')
    $missingOn = if ($_.SideIndicator -eq "<=") { $RemoteComputerName2 } else { $RemoteComputerName1 }
    [PSCustomObject]@{
        DisplayName = $displayName
        DisplayVersion = $displayVersion
        MissingAuf = $missingOn
    }
}

$DifferencesDetails | Export-Csv -Path SoftwareDifferences.csv -NoTypeInformation -Encoding UTF8

Invoke-Item -Path SoftwareDifferences.csv

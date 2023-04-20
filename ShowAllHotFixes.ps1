# Get all installed updates
$Updates = Get-Hotfix

# Filter for security updates
$SecurityUpdates = $Updates | Where-Object { $_.Description -eq "Security Update" }

# Display the security updates
$SecurityUpdates | Format-Table -AutoSize

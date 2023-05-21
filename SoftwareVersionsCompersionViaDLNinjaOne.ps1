# Das Skript lädt die Jabra-Setup-Datei herunter, berechnet ihren Hash und vergleicht diesen mit dem Hash der bereits vorhandenen Datei. Sind die Hashes gleich, wird die heruntergeladene Datei gelöscht und das Skript beendet. Sind sie unterschiedlich, wird die vorhandene Datei mit der neuen ersetzt.
# The script downloads the Jabra setup file, calculates its hash and compares it with the hash of the existing file. If the hashes are the same, the downloaded file is deleted and the script terminates. If they are different, the existing file is replaced with the new one.
# Next action, make it to a client server Version. That it produces less NW Traffic

# Axel Christian Lenz 
# https://www.linkedin.com/in/axellenz/
# https://github.com/AlpSantoGlobalMomentumLLC/PersonalPowerShellScripts/blob/main/SoftwareVersionsCompersionViaDLNinjaOne.ps1
# For NinjaOne you have to run it in the User Context.

# Definiert die URL der Setup-Datei
# Define the URL of the setup file 
$url = "https://jabraxpressonlineprdstor.blob.core.windows.net/jdo/JabraDirectSetup.exe"

# Definiert den Pfad, wo die Setup-Datei gespeichert wird
# Define the path where the setup file will be saved
$outfile = "C:\alixon1\JabraDirectSetup.exe"

# Definiert den Pfad für die Hash-Datei
# Define the path for the hash file
$hashFile = "C:\alixon1\hash.txt"

# Überprüft, ob das Verzeichnis existiert, wenn nicht, erstelle es
# Check if the directory exists, if not, create it
if (!(Test-Path -Path "C:\alixon1")) {
    New-Item -ItemType directory -Path "C:\alixon1"
}

# Lädt die Setup-Datei in einen temporären Ort herunter
# Download the setup file to a temporary location
$tempfile = "C:\alixon1\tempJabraDirectSetup.exe"
Invoke-WebRequest -Uri $url -OutFile $tempfile

# NUR ZUM TESTEN: Entkommentieren Sie die folgende Zeile, um eine lokale Datei für den Hash-Vergleich zu kopieren
# FOR TESTING ONLY: Uncomment the following line to copy a local file for hash comparison
# Copy-Item -Path "C:\alixon1\JabraDirectSetupOLD.exe" -Destination $tempfile -Force

# Berechnt den Hash der heruntergeladenen Datei
# Calculate the hash of the downloaded file
$downloadedHash = Get-FileHash -Path $tempfile -Algorithm SHA256

# Initialisiert eine Variable, um den Hash der vorhandenen Datei zu speichern
# Initialize a variable to hold the hash of the existing file
$existingHash = $null

# Wenn die Hash-Datei existiert, lese den vorhandenen Hash
# If the hash file exists, read the existing hash
if (Test-Path -Path $hashFile) {
    $existingHash = Get-Content -Path $hashFile
}

# Vergleiche die Hashes
# Compare the hashes
if ($downloadedHash.Hash -eq $existingHash) {
    # Wenn die Hashes gleich sind, lösche die heruntergeladene Datei und beende mit Code 0
    # If the hashes are the same, delete the downloaded file and exit with code 0
    Remove-Item -Path $tempfile
    Write-Output "noupdate"
    exit 0
} else {
    # Wenn die Hashes unterschiedlich sind, überschreibe die vorhandene Datei, speichere den neuen Hash und beende mit Code 1
    # If the hashes are different, overwrite the existing file, save the new hash, and exit with code 1
    Move-Item -Path $tempfile -Destination $outfile -Force
    $downloadedHash.Hash | Out-File -FilePath $hashFile
    Write-Output "update"
    exit 1
}

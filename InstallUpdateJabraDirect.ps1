# Axel Christian Lenz 
# https://www.linkedin.com/in/axellenz/
# Das PowerShell-Skript dient der automatisierten Installation von Software, in diesem Fall von Jabra Direct. Zunächst überprüft es, ob die angegebene URL existiert. Ist dies der Fall, wird geprüft, ob ein spezifischer Ordner auf der Festplatte vorhanden ist und erstellt diesen bei Bedarf. Anschließend lädt es die Installationsdatei von der URL herunter und installiert das Programm. Nach erfolgreicher Installation wird die Installationsdatei wieder gelöscht. Schließlich sendet das Skript eine Nachricht an Microsoft Teams, die Informationen über den Erfolg der Installation sowie eine Liste mit gängigen Exit-Codes enthält.

# Define the URL of your Microsoft Teams webhook
$webhookUrl = "YOURWEBHOOK"

# Define the URL of the setup file
$url = "https://jabraxpressonlineprdstor.blob.core.windows.net/jdo/JabraDirectSetup.exe"

# Define the path where the setup file will be saved
$outfile = "C:\alixon1\JabraDirectSetup.exe"

# Check if the directory exists, if not, create it
if (!(Test-Path -Path "C:\alixon1")) {
    New-Item -ItemType directory -Path "C:\alixon1"
}

# Download the setup file
$downloadResult = Invoke-WebRequest -Uri $url -OutFile $outfile

# Run the installer
$installResult = Start-Process -FilePath $outfile -Wait -PassThru -ArgumentList '/install /quiet /norestart'

# Delete the setup file
Remove-Item -Path $outfile

# Get the hostname
$hostname = $env:computername

# Define the message you want to send
$message = @{
    text = "Jabra Direct Setup has been processed on host: $hostname
    
    Install result: $($installResult.ExitCode).
    
    Some common exit codes include:
    - : Error 
    - 0: Successful execution.
    - 1: General errors or unspecified failure.
    - 2: Misuse of shell commands.
    - 126: Command cannot execute due to permissions or command is not an executable.
    - 127: 'Command not found', possible problem with `$PATH` or a typo.
    - 128: Invalid exit argument.
    - 130: Script terminated by Control-C.

    Please note, these are just examples and actual meanings can vary depending on the specific software."
}

# Convert the message to JSON
$messageJson = ConvertTo-Json -Compress -InputObject $message

# Send the message to Microsoft Teams
Invoke-RestMethod -Method Post -Uri $webhookUrl -Body $messageJson -ContentType 'application/json'

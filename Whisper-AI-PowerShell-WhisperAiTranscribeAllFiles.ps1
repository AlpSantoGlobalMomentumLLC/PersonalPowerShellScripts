# Setze den gewünschten Text für den initial_prompt Parameter
#$initialPromptText = "Welcome to the Mush Facilitator training. During this course, you will learn valuable skills and techniques to effectively guide and support group sessions."

# Setze die gewünschte Dateiendung
$fileExtension = "*.mp4"

# Setze die gewünschte Endung für die zu prüfende Datei
$checkExtension = "*.txt"

# Setze das Verzeichnis, in dem die Dateien gesucht werden sollen
$directory = "C:\temp\Test"

# Erstelle das "done" Unterverzeichnis, falls es noch nicht existiert
$doneDirectory = Join-Path -Path $directory -ChildPath "done"
if (-not (Test-Path -Path $doneDirectory)) {
    New-Item -Path $doneDirectory -ItemType Directory | Out-Null
}

# Setze das Output-Verzeichnis
$outputDirectory = "C:\temp\Test\Output Dir"

# Gehe durch alle Dateien im Verzeichnis mit der angegebenen Dateiendung
Get-ChildItem -Path $directory -File -Filter $fileExtension | ForEach-Object {

    # Erstelle den Befehl mit der aktuellen Datei und dem Parameter
    $command = "whisper `"$($_.FullName)`" --model small --output_dir '$outputDirectory' --patience 2"
    #$command = "whisper `"$($_.FullName)`" --model small --output_dir '$outputDirectory' --patience 2 --initial_prompt '$initialPromptText'"

    # Zeige den Befehl an, der gestartet wird
    Write-Host "Starting command: $command"

    # Führe den Befehl aus
    Invoke-Expression $command

    # Zeige den ausgeführten Befehl an
    Write-Host "Executed command: $command"

    # Prüfe, ob eine Datei mit demselben Namen und der festgelegten Endung im outputDirectory vorhanden ist
    $checkFile = Join-Path -Path $outputDirectory -ChildPath ($_.BaseName + $checkExtension.Replace("*", ""))
    if (Test-Path -Path $checkFile) {
        # Verschiebe die Datei in das "done" Unterverzeichnis
        $destination = Join-Path -Path $doneDirectory -ChildPath $_.Name
        Move-Item -Path $_.FullName -Destination $destination
    }
}

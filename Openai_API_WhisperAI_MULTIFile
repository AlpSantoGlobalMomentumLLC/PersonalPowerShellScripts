# This PowerShell script provides a user interface for processing audio files through the OpenAI's audio translation API. The script first prompts the user to select between file mode or folder mode. In file mode, it allows the user to select a specific audio file, process it through the API, and saves the response as a .txt file in the same directory. In folder mode, it allows the user to select a directory, and then processes all audio files within that directory and its subdirectories, ignoring those that already have a corresponding .txt file. The output in this case is saved in the same directory as each original audio file. Upon completion, the script provides a summary pop-up listing all the files that were processed.

# You need MS PowerShell 7 https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.3
# You have to replace "YOURKEY" - https://platform.openai.com/account/api-keys

# Axel Christian Lenz 
# https://www.linkedin.com/in/axellenz/

Add-Type -AssemblyName System.Windows.Forms

# API endpoint, model and headers
$apiEndpoint = "https://api.openai.com/v1/audio/translations"
$model = "whisper-1"
$apiKey = "YOURKEY" # Replace with your OpenAI API Key
$headers = @{
    "Authorization" = "Bearer $($apiKey)"
    "Content-Type" = "multipart/form-data"
}

$processedFiles = @()

# Choose mode
$modeResult = [System.Windows.Forms.MessageBox]::Show("Please choose the mode:`nYes for File Mode`nNo for Folder Mode", "Select Mode", [System.Windows.Forms.MessageBoxButtons]::YesNo)

if ($modeResult -eq "Yes") {
    # File Mode
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.ShowDialog() | Out-Null
    $filePath = $openFileDialog.FileName
    $outputFolder = [System.IO.Path]::GetDirectoryName($filePath)
    Process-File $filePath
}
else {
    # Folder Mode
    $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowserDialog.ShowDialog() | Out-Null
    $outputFolder = $folderBrowserDialog.SelectedPath
    $files = Get-ChildItem -Path $outputFolder -File -Recurse | Where-Object { $_.Extension -in @(".m4a", ".mp3", ".webm", ".mp4", ".mpga", ".wav", ".mpeg") -and !(Test-Path ('{0}\{1}.txt' -f $_.Directory, $_.BaseName)) }
    $warningResult = [System.Windows.Forms.MessageBox]::Show("This will process " + $files.Count + " files from the selected folder and all its subfolders. This operation cost money. Continue?", "Warning", [System.Windows.Forms.MessageBoxButtons]::YesNo)

    if ($warningResult -eq "Yes") {
        foreach ($file in $files) {
            # Process each file
            Process-File $file.FullName
        }
    }
}

function Process-File($filePath) {
    # Create a name for the response file
    $responseFileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath) + ".txt"
    $responseFile = Join-Path -Path ([System.IO.Path]::GetDirectoryName($filePath)) -ChildPath $responseFileName

    # Create a MultiPartFormDataContent object and add the file and model to it
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $byteArray = [System.IO.File]::ReadAllBytes($filePath)
    $memStream = New-Object System.IO.MemoryStream( $byteArray, 0, $byteArray.Length )
    $streamContent = New-Object System.Net.Http.StreamContent($memStream)
    $content.Add($streamContent, "file", [System.IO.Path]::GetFileName($filePath))
    $content.Add((New-Object System.Net.Http.StringContent($model)), "model")

    # Send the POST request
    $response = Invoke-RestMethod -Uri $apiEndpoint -Headers $headers -Method Post -Body $content

    # Save the response to a text file
    $response.text | Out-File $responseFile

    $global:processedFiles += $filePath
}

# Show summary popup with processed files
[System.Windows.Forms.MessageBox]::Show("The following files were processed: `n" + ($processedFiles -join "`n"), "Summary")

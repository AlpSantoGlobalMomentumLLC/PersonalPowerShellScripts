# Axel Christian Lenz 
# https://www.linkedin.com/in/axellenz/
# The script renames all files in a specified directory and its subdirectories from the source extension .md to the target extension .txt. Additionally, it adds the specified text, "#ChatGPT Conversation", to the end of each file in a new line. The source and target file extensions, the directory path, and the text to add are configurable at the beginning of the script via variables. The script outputs details of the renaming operation and the files to which the text is added on the console.

# Define variables
$sourceDir = "D:\Downloads\Test" # Specify the directory path here
$targetExt = ".txt" # Specify the target file extension here
$sourceExt = ".md" # Specify the source file extension here
$addText = $true # Specify whether to add text or not here
$textToAdd = "#ChatGPT Conversation" # Specify the text to add here

# Rename files in the directory and subdirectories
Get-ChildItem -Path $sourceDir -Recurse -Filter *$sourceExt | 
ForEach-Object {
    $newName = $_.Name -replace $_.Extension, $targetExt
    $oldPath = $_.FullName
    $newPath = Join-Path $_.Directory $newName
    Rename-Item $oldPath -NewName $newName -Verbose
}

# Add text to the end of each file
if ($addText) {
    Get-ChildItem -Path $sourceDir -Recurse -Filter *$targetExt | 
    ForEach-Object {
        $filePath = $_.FullName
        Write-Host "Adding text to $filePath"
        $content = Get-Content $filePath
        $content += "`n" + $textToAdd
        Set-Content -Path $filePath -Value $content
    }
}

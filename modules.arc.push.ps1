param (
    [string]$arcUrl
)

Write-Host $arcUrl

$items = Get-ChildItem './src' -Recurse -Include '*.bicep'
$items | ForEach-Object {
   
    $paths = $_.DirectoryName.Split('/')
    $version = $paths[$paths.Length - 1]

    if ($version -match "[a-zA-Z]{1}\d{1,2}\.\d{1,2}") {

        $moduleName = $_.BaseName
        $modulePath = "br:$arcUrl/modules/$moduleName" + ":" + $version
        
        Write-Host "Uploading $modulePath"
        Publish-AzBicepModule -FilePath $_.FullName -Target $modulePath
    }   
}
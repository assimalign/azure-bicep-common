$arcurl = "$(azure-arc-fqd)"
$items = Get-ChildItem './src' -Recurse -Include '*.bicep'
$items | ForEach-Object {
   
    $paths = $_.DirectoryName.Split('/')
    $version = $paths[$paths.Length - 1]

    if ($version -match "^v(/d*/./d)") {

        $moduleName = $_.BaseName
        $modulePath = "br:$arcurl/modules/$moduleName" + ":" + $version
        
        Write-Host "Uploading $modulePath"
        Publish-AzBicepModule -FilePath $_.FullName -Target $modulePath
    }   
}


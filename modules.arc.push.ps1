param (    
    [Parameter(Mandatory = $true)]
    [string]$containerRegistryName,

    [Parameter(Mandatory = $true)]
    [string]$containerRegistryResourceGroup
)

# Get the existing Azure Container Registry
$registry = Get-AzContainerRegistry -Name $containerRegistryName -ResourceGroupName $containerRegistryResourceGroup -ErrorAction SilentlyContinue

# Validate the Container Registry exist
Write-Host "- Validating Azure Container Registry Exists." -ForegroundColor Blue
if ($null -eq $registry) {
    Write-Error -Message "The Container Registry '$containerRegistryName' in Resource Group '$containerRegistryResourceGroup' was not found."
}

$registryUrl = $registry.LoginServer
$items = Get-ChildItem './src' -Recurse -Include '*.bicep'
Write-Host "- " + $items.Length + "Bicep modules were found." -ForegroundColor Blue

$context = Get-AzContext
$items | ForEach-Object {
    $paths = $_.DirectoryName.Split('\')
    $version = $paths[$paths.Length - 1]
    if ($version -match "[a-zA-Z]{1}\d{1,2}\.\d{1,2}") {

        $filePath = $_.FullName
        $moduleName = $_.BaseName
        $modulePath = "br:$registryUrl/modules/$moduleName" + ":" + $version
        
        Write-Host "Pushing $modulePath" -ForegroundColor Green
        Publish-AzBicepModule -FilePath $filePath -Target $modulePath -DefaultProfile $context -Force
    }   
}
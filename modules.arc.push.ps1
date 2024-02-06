param (    
    [Parameter(Mandatory = $true)]
    [string]$containerRegistryName,

    [Parameter(Mandatory = $true)]
    [string]$containerRegistryResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$module
)

# Get the existing Azure Container Registry
$registry = Get-AzContainerRegistry -Name $containerRegistryName -ResourceGroupName $containerRegistryResourceGroup -ErrorAction SilentlyContinue

# Validate the Container Registry exist
Write-Host "- Validating Azure Container Registry Exists." -ForegroundColor Blue
if ($null -eq $registry) {
    Write-Error -Message "The Container Registry '$containerRegistryName' in Resource Group '$containerRegistryResourceGroup' was not found."
}

$directory = [string]::Join('/', './src/modules', $module)

$registryUrl = $registry.LoginServer
$items = Get-ChildItem $directory -Recurse -Include '*.bicep'
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


#Publish-AzBicepModule -FilePath 'C:\Source\repos\assimalign\github\azure-bicep-common\src\modules\az.app.service\v1.0\az.app.service.bicep' -Target 'br:aecbicep.azurecr.io/modules/az.app.service:v1.0' -Force
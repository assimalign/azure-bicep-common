param (
    [Parameter(Mandatory = $false)]
    [string]$moduleName,

    [Parameter(Mandatory = $true)]
    [string]$containerRegistryName,

    [Parameter(Mandatory = $true)]
    [string]$containerRegistryResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$storageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$storageAccountResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$storageAccountContainerName
)

# Push Bicep Module to ACR
$azureContext = Get-AzContext
$azureContainerRegistry = Get-AzContainerRegistry `
    -Name $containerRegistryName `
    -ResourceGroupName $containerRegistryResourceGroup `
    -ErrorAction SilentlyContinue
$azureContainerRegistryUrl = $azureContainerRegistry.LoginServer

#region 1. ACR Push
Get-ChildItem "./modules/$moduleName" -Recurse -Include '*.bicep' | ForEach-Object {
    $moduleFilePath = $_.FullName
    $name = $_.BaseName
    $modulePath = "br:$azureContainerRegistryUrl/modules/$name" + ":" + "v1.0"

    Write-Host "Pushing $modulePath" -ForegroundColor Green
    Publish-AzBicepModule -FilePath $moduleFilePath -Target $modulePath -DefaultProfile $azureContext -Force
}
#endregion


#region 2. Schema Push
# Push/Update JSON Parameter Schemas
$storageAccount = Get-AzStorageAccount `
    -ResourceGroupName $storageAccountResourceGroup `
    -Name $storageAccountName `
    -ErrorAction SilentlyContinue

# Get the Module Schema
$schema = Get-Item "./modules/$moduleName/parameters.json"
$index = $schema.FullName.IndexOf('modules') + 'modules'.Length + 1
$path = 'bicep' + '\' + $schema.FullName.Substring($index , $schema.FullName.Length - $index)
    
Set-AzStorageBlobContent `
    -Container $storageAccountContainerName `
    -Context $storageAccount.Context `
    -Blob $path `
    -File $schema.FullName `
    -Force `
    -Verbose `
    -ErrorAction SilentlyContinue

# Get the Root Schema
$schema = Get-Item "./modules/schema.json"
$index = $schema.FullName.IndexOf('modules') + 'modules'.Length + 1
$path = 'bicep' + '\' + $schema.FullName.Substring($index , $schema.FullName.Length - $index)

Set-AzStorageBlobContent `
    -Container $storageAccountContainerName `
    -Context $storageAccount.Context `
    -Blob $path `
    -File $schema.FullName `
    -Force `
    -Verbose `
    -ErrorAction SilentlyContinue

#endregion
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

Get-ChildItem "./modules/$moduleName" -Recurse -Include '*.bicep' | ForEach-Object {

        $moduleFilePath = $_.FullName
        $moduleName = $_.BaseName
        $modulePath = "br:$azureContainerRegistryUrl/modules/$moduleName" + ":" + "v1.0"

        Write-Host "Pushing $modulePath" -ForegroundColor Green
        Publish-AzBicepModule -FilePath $moduleFilePath -Target $modulePath -DefaultProfile $azureContext -Force
}


# Push/Update JSON Parameter Schemas
$storageAccount = Get-AzStorageAccount `
    -ResourceGroupName $storageAccountResourceGroup `
    -Name $storageAccountName 

Get-ChildItem './modules' -Include '*.json' -Recurse | ForEach-Object {
    $index = $_.FullName.IndexOf('modules') + 'modules'.Length + 1
    $path = 'bicep' + '\' + $_.FullName.Substring($index , $_.FullName.Length - $index)
    
    Set-AzStorageBlobContent `
        -Container $storageAccountContainerName `
        -Context $storageAccount.Context `
        -Blob $path `
        -File $_.FullName `
        -Force `
        -Verbose
}
param (
    # [Parameter(Mandatory = $true)]
    # [string]$azureContextName,
    
    [Parameter(Mandatory = $true)]
    [string]$containerRegistryName,

    [Parameter(Mandatory = $true)]
    [string]$containerRegistryResourceGroup
)

# Get the existing Azure Container Registry
$containerRegistry = Get-AzContainerRegistry `
    -Name $containerRegistryName `
    -ResourceGroupName $containerRegistryResourceGroup `
    -ErrorAction SilentlyContinue


# Validate the Container Registry exist
if ($null -eq $containerRegistry) {
    Write-Error -Message "The Container Registry '$containerRegistryName' in Resource Group '$containerRegistryResourceGroup' was not found."
}

$containerRegistryUrl = $containerRegistry.LoginServer

$items = Get-ChildItem './src' -Recurse -Include '*.bicep'
Write-Host $items.Length + "Bicep modules were found." -ForegroundColor Blue

$context = Get-AzContext
#Connect-AzAccount -ContextName $context.Name
$items | ForEach-Object {
   
    $paths = $_.DirectoryName.Split('\')
    $version = $paths[$paths.Length - 1]

    if ($version -match "[a-zA-Z]{1}\d{1,2}\.\d{1,2}") {

        $moduleName = $_.BaseName
        $modulePath = "br:$containerRegistryUrl/modules/$moduleName" + ":" + $version
        
        Write-Host "Pushing $modulePath" -ForegroundColor Green

        Publish-AzBicepModule $_.FullName -Target $modulePath -Force
    }   
}


#Publish-AzBicepModule './src\modules\az.sql.server\v1.0\az.sql.server.bicep'  -Target 'br:aecbicep.azurecr.io:modules/az.sql.server:v1.0'
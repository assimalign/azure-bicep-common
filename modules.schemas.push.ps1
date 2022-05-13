
$storageAccountName = 'asalschemastore'
$storageAccountContainerName = 'json'
$storageAccountResourceGroup = 'asal-main-rg-est-us-01'



Connect-AzAccount -Subscription '3c1b7889-444a-48a3-b2b4-275e2ff15584'

$account = Get-AzStorageAccount -ResourceGroupName $storageAccountResourceGroup -Name $storageAccountName 
$items = Get-ChildItem './src' -Recurse -Include '*.json'
$items | ForEach-Object {
   
    $paths = $_.DirectoryName.Split('\')
    $version = $paths[$paths.Length - 1]

    if ($version -match "^v(\d*\.\d)") {

        $index = $_.FullName.IndexOf('schemas') + 'schemas'.Length + 1
        $path =  $_.FullName.Substring($index , $_.FullName.Length - $index)
        $response = Set-AzStorageBlobContent `
            -Container $storageAccountContainerName `
            -Context $account.Context `
            -Blob "bicep\$path" `
            -File $_.FullName `
            -Force
    }   
}

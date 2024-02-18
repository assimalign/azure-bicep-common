$prefix = '{pipeline prefix name}'
$organization = '{org name}'
$project = '{project name}'
$pat = '{personal access token}'
$root = 'https://dev.azure.com/'
$connectionId = "1b8c1371-0faa-4808-b363-0c09f9aecbfb"
$url = $root + $organization + '/' + $project + '/_apis/pipelines?api-version=7.1-preview.1'

$bytes = [System.Text.Encoding]::UTF8.GetBytes($pat)
$token = [System.Convert]::ToBase64String($bytes)

Get-ChildItem '.\modules\*azure-pipelines.yml' -Recurse | ForEach-Object {

    $moduleName = ($_.DirectoryName -split '\\') | Select-Object -Last 1
    $response = Invoke-RestMethod `
        -Uri $url `
        -Method Post `
        -Headers @{
            'Authorization' = "Basic $token"
            'Content-Type' = 'application/json'
        } `
        -Body (@{
            name = $name
            folder = "\$prefix-external-github"
            configuration = @{
                type = "yaml"
                path = "modules/$moduleName/azure-pipelines.yml"
                repository = @{
                    fullName = "assimalign/azure-bicep-common"
                    type = "gitHub"
                    connection = @{
                        id = $connectionId
                    }
                }
            }
        } | ConvertTo-Json -Depth 10) `
        -SkipCertificateCheck

    $response
}
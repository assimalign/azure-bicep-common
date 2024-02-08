$root = 'https://dev.azure.com/'
$organization = '{org name}'
$project = '{project name}'
$pat = '{personal access token}'
$url = $root + $organization + '/' + $project + '/_apis/pipelines?api-version=7.1-preview.1'

$bytes = [System.Text.Encoding]::UTF8.GetBytes($pat)
$token = [System.Convert]::ToBase64String($bytes)


Get-ChildItem '.\.azure\*.yml' | ForEach-Object {

    $path = $_.Name
    $name = 'aec-iac-bicep-' + $_.Name -replace 'az.', '' -replace '.yml', '' -replace '\.', '-'
    $response = Invoke-RestMethod `
        -Uri $url `
        -Method Post `
        -Headers @{
            'Authorization' = "Basic $token"
            'Content-Type' = 'application/json'
        } `
        -Body (@{
            name = $name
            folder = "\aec-external-github"
            configuration = @{
                type = "yaml"
                path = ".azure/$path"
                repository = @{
                    fullName = "assimalign/azure-bicep-common"
                    type = "gitHub"
                    connection = @{
                        id = "1b8c1371-0faa-4808-b363-0c09f9aecbfb"
                    }
                }
            }
        } | ConvertTo-Json -Depth 10) `
        -SkipCertificateCheck

    $response
}
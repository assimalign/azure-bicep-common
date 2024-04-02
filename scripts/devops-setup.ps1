$prefix = '{a prefix to add to all names}'
$organization = '{org name}'
$project = '{project name}'
$pat = '{personal access token}'
$connectionId = '{the github connection Id}'



$projectUrl = 'https://dev.azure.com/' + $organization + '/_apis/projects/' + $project + '?api-version=7.2-preview.1'
$pipelineUrl = 'https://dev.azure.com/' + $organization + '/' + $project + '/_apis/pipelines?api-version=7.1-preview.1'
$variableGroupUrl = 'https://dev.azure.com/' + $organization + '/' + $project + '/_apis/distributedtask/variablegroups?api-version=7.2-preview.2'
$bytes = [System.Text.Encoding]::UTF8.GetBytes(":$pat")
$token = [System.Convert]::ToBase64String($bytes)


# GET - Project Info 
$projectInfo = Invoke-RestMethod `
    -Uri $projectUrl `
    -Method Get `
    -Headers @{
        'Authorization' = "Basic $token"
        'Content-Type'  = 'application/json'
    } `
    -SkipCertificateCheck

# POST - Create Variable Group
Invoke-RestMethod `
    -Uri $variableGroupUrl `
    -Method Post `
    -Headers @{
        'Authorization' = "Basic $token"
        'Content-Type'  = 'application/json'
    } `
    -Body (@{
        name                           = "bicep-module-configs"
        description                    = ""
        type                           = "Vsts"
        variables                      = @{
            'storage-account' = @{
                value = ''
            }
            'storage-account-container' = @{
                value = ''
            }
            "storage-account-resource-group" = @{
                value = ''
            }
            'container-registry' = @{
                value = ''
            }
            'container-registry-resource-group' = @{
                value = ''
            }
            'service-principal' = @{
                value = ''
            }
        }
        variableGroupProjectReferences = @(
            @{
                name             = "bicep-module-variables"
                description      = ""
                projectReference = @{
                    id   = $projectInfo.id
                    name = $projectInfo.name
                }
            }
        )
    } | ConvertTo-Json -Depth 10) `
    -SkipCertificateCheck

# Create Pipelines
Get-ChildItem '.\modules\*azure-pipelines.yml' -Recurse | ForEach-Object {
    $moduleName = ($_.DirectoryName -split '\\') | Select-Object -Last 1
    $moduleFolderName = [string]::Join('-', $prefix, 'external-github')
    $name = [string]::Join('-', $prefix, $moduleName)
    Invoke-RestMethod `
        -Uri $pipelineUrl `
        -Method Post `
        -Headers @{
            'Authorization' = "Basic $token"
            'Content-Type'  = 'application/json'
        } `
        -Body (@{
            name          = $name
            folder        = $moduleFolderName
            configuration = @{
                type       = "yaml"
                path       = "modules/$moduleName/azure-pipelines.yml"
                repository = @{
                    fullName   = "assimalign/azure-bicep-common"
                    type       = "gitHub"
                    connection = @{
                        id = $connectionId
                    }
                }
            }
        } | ConvertTo-Json -Depth 10 -Verbose) `
        -SkipCertificateCheck
}
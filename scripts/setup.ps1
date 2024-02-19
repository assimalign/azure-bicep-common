$prefix = 'tst'
$organization = 'assimalign' #'{org name}'
$project = 'PoliSight' #'{project name}'
$pat = 'vcce6tay2zecyf6eponklrq5rh4r3v3f6ipbw3bqbprfe2zej3yq' #'{personal access token}'
$root = 'https://dev.azure.com/'
$connectionId = '1b8c1371-0faa-4808-b363-0c09f9aecbfb'



$projectUrl = $root + $organization + '/_apis/projects/' + $project + '?api-version=7.2-preview.1'
$pipelineUrl = $root + $organization + '/' + $project + '/_apis/pipelines?api-version=7.1-preview.1'
$variableGroupUrl = $root + $organization + '/' + $project + '/_apis/distributedtask/variablegroups?api-version=7.2-preview.2'
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
        name                           = "bicep-module-variables"
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

# # Create Pipelines
# Get-ChildItem '.\modules\*azure-pipelines.yml' -Recurse | ForEach-Object {
#     $moduleName = ($_.DirectoryName -split '\\') | Select-Object -Last 1
#     Invoke-RestMethod `
#         -Uri $pipelineUrl `
#         -Method Post `
#         -Headers @{
#         'Authorization' = "Basic $token"
#         'Content-Type'  = 'application/json'
#     } `
#         -Body (@{
#             name          = $name
#             folder        = "\$prefix-external-github"
#             configuration = @{
#                 type       = "yaml"
#                 path       = "modules/$moduleName/azure-pipelines.yml"
#                 repository = @{
#                     fullName   = "assimalign/azure-bicep-common"
#                     type       = "gitHub"
#                     connection = @{
#                         id = $connectionId
#                     }
#                 }
#             }
#         } | ConvertTo-Json -Depth 10) `
#         -SkipCertificateCheck
# }
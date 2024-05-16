$subscription = '5422bd82-186b-461e-ada5-db37cebf414f'
$prefix = 'DSB'


$groups = @(
    @{
        name = 'Admins'
        description = 'A security group for administrators.'
        entra_roles = @(

        )
        subscription_roles = @(
            'User Access Administrator',
            'Key Vault Administrator'
        )
    },
    @{
        name = 'AppDev'
        description = 'A security group that gives access to app development resources.'
        entra_roles = @(
            
        )
        subscription_roles = @(
            'AcrPull',
            'Key Vault Reader',
            'Key Vault Secrets User',
            'Azure Service Bus Data Receiver',
            'Azure Service Bus Data Sender',
            'Storage Blob Data Contributor',
            'Storage Queue Data Contributor',
            'Storage Table Data Contributor',
            'Storage File Data SMB Share Contributor',
            'Storage File Data Privileged Contributor',
            'App Configuration Data Owner'
        )
    },
    @{
        name = 'DevOps'
        description = 'A security group for DevOps'
        entra_roles = @(
            
        )
        subscription_roles = @(
            'AcrPush',
            'AcrPull',
            'AcrDelete',
            'Key Vault Reader',
            'Key Vault Contributor',
            'Azure Service Bus Data Owner',
            'App Configuration Data Owner'
        )
    },
    @{
        name = 'Security'
        description = 'A security Group for the security Team'
        entra_roles = @(
            'Key Vault Administrator'
        )
        subscription_roles = @(

        )
    },
    #region MSI Security Groups
    @{
        name = 'MSI Service Bus'
        description = 'A security group for MSI (Managed System Identity) Serivce Principals to allow Receiving and Sending Data to a Service Bus namespace.'
        entra_roles = @()
        subscription_roles = @(
            'Azure Service Bus Data Receiver',
            'Azure Service Bus Data Sender'
        )
    },
    @{
        name = 'MSI Storage Account'
        description = 'A security group for MSI (Managed System Identity) Serivce Principals to allow read, write and edit operations on Blob, Queue, File Share, and Table storage within a storage account.'
        entra_roles = @()
        subscription_roles = @(
            'Storage Blob Data Contributor',
            'Storage Queue Data Contributor',
            'Storage Table Data Contributor',
            'Storage File Data SMB Share Contributor',
            'Storage File Data Privileged Contributor'
        )
    },
    @{
        name = 'MSI SQL Server'
        description = 'A group that allows all'
        entra_roles = @(
            
        )
        subscription_roles = @(

        )
    },
    @{
        name = 'MSI App Configuration'
        description = 'A security group for MSI (Managed System Identity) Serivce Principals to allow reading configurations from Azure App Configuration.'
        entra_roles = @(
            
        )
        subscription_roles = @(
            'App Configuration Data Reader'
        )
    },
    @{
        name = 'MSI Key Vault'
        description = 'A security group for MSI (Managed System Identity) Serivce Principals to allow Receiving and Sending Data to a Service Bus namespace.'
        entra_roles = @(
            
        )
        subscription_roles = @(
            'Key Vault Secrets User'
        )
    },
    @{
        name = 'MSI Cosmos'
        description = 'A security group for MSI (Managed System Identity) Serivce Principals to allow Receiving and Sending Data to a Service Bus namespace.'
        entra_roles = @(
            
        )
        subscription_roles = @(

        )
    }
    #endregion
)
$roles = Get-AzRoleDefinition

function Find-AzRole {
    param ([string]$Name )
    $items = $roles | Where-Object Name -EQ $Name
    return $items[0]
}

$groups | ForEach-Object {
    $group_name = [string]::Join(' ', $prefix, $_.name)
    $group_mail_nickname = ($group_name -replace ' ', '-').ToLower()
    $group_description = $_.description

    # Try to get existing Group
    $group = Get-AzADGroup -DisplayName $group_name

    # Create Group if doesn't exist
    if ($null -eq $group) {
        $group = New-AzADGroup `
            -DisplayName $group_name `
            -Description $group_description `
            -MailNickname $group_mail_nickname
    } else {
        #$group = 
    }

    # Get All Azure Role Assignments for the Group, if any
    $assignents = Get-AzRoleAssignment -ObjectId $group.Id
    
    $_.subscription_roles | ForEach-Object {
        $role = Find-AzRole -Name $_
        
        if ($null -eq $role) {
            Write-Host 'Role Not Found' + $_
        }

        
        $assignment = New-AzRoleAssignment `
            -ObjectId $group.Id `
            -Scope "/subscriptions/$subscription" `
            -RoleDefinitionId $role.Id
    }
}
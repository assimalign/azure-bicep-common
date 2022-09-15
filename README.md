# Assimalign Bicep
The repository is meant to be a starting convention for any organization trying to setup CI/CD via IaC (Infrastructure as Code) which targets that Azure platform. Out of the box there are various modules and corresponding JSON schemas which can help get environments setup within a day.

The setup within this repository

Assimalign LLC has a current setup 


**NOTE: This repository does not contain all azure resource and should be used as a solution which can be iterated and improved upon. As mentioned, it is a starting convention.**

- [Assimalign Bicep](#assimalign-bicep)
- [Conventions](#conventions)
  - [Folder Structure](#folder-structure)
  - [JSON Schemas](#json-schemas)
  - [Token Replacements](#token-replacements)
- [Setup](#setup)
  - [Prerequisite](#prerequisite)
  - [Steps](#steps)

# Conventions


1. All modules are referenced by folder and **NOT by container registry path**. This is so that each module has it's own life cycle. Meaning if one module in a repository changes it doesn't effect the module referencing it in another repository.
2. All modules **SHOULD** be created per ARM API Route (Azure Resource Management APIs). For example, if d

## Folder Structure
Every Bicep module should be placed in a folder with the name of the Resource Provider in azure as well as a version folder for the module. The version folder will be parsed and used as the tag to be attached to the container registry repository when deployed.

## JSON Schemas
When a bicep module is created there should be a corresponding JSON Schema that helps with validation. This will help guid the user to input the correct parameters.


## Token Replacements
Use tokens built into all modules to dynamically replace variables in JSON parameter files at deployment. This will allow for a consistent naming convention when deploying up environments.

- **'@environment'**: An environment agnostic token that is replaced with the environment name at deployment.
  - ***Available Environments***: dev, qa, uat, prd
- **'@region'**: A variable to be used as a suffix or prefix replacement in a resource name. In many cases organization need to have a DR (Disaster Recovery) site which can be switch for any app. The '@region' can be a useful naming convention to have resources deployed to different regions in Azure.
- **'@subscription'**


# Setup
Below is a quick setup guid to get the repository imported and deployed into your organization.


## Prerequisite
- **Azure DevOps Account and Project**
- **Azure Container Registry**
- **Service Principal** (Azure AD App Registration). This service principal will need to be connected to the Azure DevOps account in which the pipeline will run under. **NOTE: Make sure to give it a friendly name to reference in the pipeline**
  - Make sure to assign the Service Principal the following Azure Container Registry RBAC Roles: 'ArcPull' and 'ArcPush'. If these roles are not assigned then the deployment will fail.


## Steps 
1. In Azure DevOps create a Variable Group called: `bicep.release.variables`
2. In `bicep.release.variables` variable group add the following variables: 
   |Variable Name                       | Description                |
   |------------------------------------|----------------------------|
   | **azure-arc**                      | The name of the Azure Container Registry |
   | **azure-arc-rg**                   | The name of the Resource Group in which the Azure Container Registry lives in |
   | **azure-devops-service-principal** | The friendly name of the Service Connection linked to the service principal in Azure DevOps |
   | **azure-schema-stgact**            | The name of the Azure Storage account in which the Parameter Files Schema will be put. |
   | **azure-schema-stgact-rg**         | The name of the Resource Group in which the Storage account lives in |

3. Import the Github Repository into an Azure DevOps repository
4. Using the existing `azure-pipeline.yml` create a new build pipeline and run it
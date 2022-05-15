# Assimalign Bicep
A collection of read


**NOTE: This repository is not meant to be a full-proof**
A repository for common bicep modules made for deploying resources to azure.





1. Create a DevOps Project (is not already created)
2. Within the DevOps Project go to Pipelines --> Library then select '+ Variable Group'
3. Add the following variables to the group to be referenced for deployment.
   1. ARC (Azure Registry Container) Name (*This will be used to create a Container Registry for shared modules*) 

4. Create a Service Principal in Azure AD




## Token Replacements
Use tokens built into all modules to dynamically replace variables in JSON parameter files. 

- **'@environment'**: An environment agnostic variable that adds the environment 
- **'@region'**
- **'@subscription'**


# Setup
If you are an organization that would like to 


# Prerequisite
- **Azure DevOps Account and Project**
- **Service Principal** (Azure AD App Registration). This service principal will need to be connected to the Azure DevOps account in which the pipeline will run under. **NOTE: Make sure to give it a friendly name to reference in the pipeline**
- 

1. In Azure DevOps create a Variable Group called: `bicep.release.variables`
2. In `bicep.release.variables` variable group add the following variables: 
   - azure-arc: 
   - azure-arc-rg: 
   - azure-devops-service-principal: The name of the Service Principal 
   - azure-schema-stgact: 
   - azure-schema-stgact-rg: 
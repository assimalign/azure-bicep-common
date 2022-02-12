# Assimalign Bicep Modules
A repository for common bicep modules made for deploying resources to azure.





1. Create a DevOps Project (is not already created)
2. Within the DevOps Project go to Pipelines --> Library then select '+ Variable Group'
3. Add the following variables to the group to be referenced for deployment.
   1. ARC (Azure Registry Container) Name (*This will be used to create a Container Registry for shared modules*) 

4. Create a Service Principal in Azure AD
# https://learn.microsoft.com/en-us/azure/app-service/tutorial-custom-container?tabs=azure-cli&pivots=container-linux

git clone https://github.com/Azure-Samples/docker-django-webapp-linux.git --config core.autocrlf=input
cd docker-django-webapp-linux
docker build --tag appsvc-tutorial-custom-image .
docker run -it -p 8000:8000 appsvc-tutorial-custom-image

az group create --name msdocs-custom-container-tutorial --location westeurope

az identity create --name myID --resource-group msdocs-custom-container-tutorial

az acr create --name <registry-name> --resource-group msdocs-custom-container-tutorial --sku Basic --admin-enabled true

az acr credential show --resource-group msdocs-custom-container-tutorial --name <registry-name>

docker login <registry-name>.azurecr.io --username <registry-username>

docker tag appsvc-tutorial-custom-image <registry-name>.azurecr.io/appsvc-tutorial-custom-image:latest

docker push <registry-name>.azurecr.io/appsvc-tutorial-custom-image:latest

principalId=$(az identity show --resource-group msdocs-custom-container-tutorial --name myID --query principalId --output tsv)
registryId=$(az acr show --resource-group msdocs-custom-container-tutorial --name <registry-name> --query id --output tsv)
az role assignment create --assignee $principalId --scope $registryId --role "AcrPull"

az appservice plan create --name myAppServicePlan --resource-group msdocs-custom-container-tutorial --is-linux

az webapp create --resource-group msdocs-custom-container-tutorial --plan myAppServicePlan --name <app-name> --deployment-container-image-name <registry-name>.azurecr.io/appsvc-tutorial-custom-image:latest

az webapp config appsettings set --resource-group msdocs-custom-container-tutorial --name <app-name> --settings WEBSITES_PORT=8000

id=$(az identity show --resource-group msdocs-custom-container-tutorial --name myID --query id --output tsv)
az webapp identity assign --resource-group msdocs-custom-container-tutorial --name <app-name> --identities $id

appConfig=$(az webapp config show --resource-group msdocs-custom-container-tutorial --name <app-name> --query id --output tsv)
az resource update --ids $appConfig --set properties.acrUseManagedIdentityCreds=True

clientId=$(az identity show --resource-group msdocs-custom-container-tutorial --name myID --query clientId --output tsv)
az resource update --ids $appConfig --set properties.AcrUserManagedIdentityID=$clientId

cicdUrl=$(az webapp deployment container config --enable-cd true --name <app-name> --resource-group msdocs-custom-container-tutorial --query CI_CD_URL --output tsv)

az acr webhook create --name appserviceCD --registry <registry-name> --uri $cicdUrl --actions push --scope appsvc-tutorial-custom-image:latest

eventId=$(az acr webhook ping --name appserviceCD --registry <registry-name> --query id --output tsv)
az acr webhook list-events --name appserviceCD --registry <registry-name> --query "[?id=='$eventId'].eventResponseMessage"

# Get logs

az webapp log config --name <app-name> --resource-group msdocs-custom-container-tutorial --docker-container-logging filesystem

az webapp log tail --name <app-name> --resource-group msdocs-custom-container-tutorial


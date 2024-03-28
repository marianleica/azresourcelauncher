# Setting variables
aopa="myopa"
rg="oparg"
loc="westeurope"

# Create resource group
az group create -n $rg -l $loc

# Create OPA resource
az cognitiveservices account create \
-n $aopa \
-g $rg \
-l $loc \
--kind OpenAI \
--sku s0

# Open AI Studio at https://oai.azure.com/




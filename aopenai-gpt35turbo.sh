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

# Create a deplpoyment
depl="var1"

az cognitiveservices account deployment create \
   -g $rg \
   -n $aopa \
   --deployment-name $depl \
   --model-name gpt-35-turbo \
   --model-version "0301"  \
   --model-format OpenAI \
   --sku-name "Standard" \
   --sku-capacity 1


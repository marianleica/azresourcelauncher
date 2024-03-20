# Setting Variables for ACR
acrname="myacr234235234"
acrurl="${acrname}.azurecr.io"
rg="acrRG"
loc='northeurope'

# Setting Variables for AKS
aksClusterGroupName="myAks" # Name of resource group for the AKS cluster
resourceLocation="westeurope" # Name of the location 
aksName="${aksClusterGroupName}-cluster" # Name of the AKS cluster

# Add the existing ACR to AKS

# Attach using acr-name
az aks update -n $aksName -g $aksClusterGroupName --attach-acr $acrname

# Attach using acr-resource-id
# az aks update -n myAKSCluster -g myResourceGroup --attach-acr <acr-resource-id>

# Import an image from Docker Hub into your ACR using the az acr import command:
az acr import  -n $acrurl --source docker.io/library/nginx:latest --image nginx:v1

# Configure "kubectl" to connect to the Kubernetes cluster
az aks get-credentials --resource-group $aksClusterGroupName --name $aksName --admin --overwrite-existing

# Apply the nginx deployment from the ACR

cat <<EOF > acr-nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx0-deployment
  labels:
    app: nginx0-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx0
  template:
    metadata:
      labels:
        app: nginx0
    spec:
      containers:
      - name: nginx
        image: $acrname.azurecr.io/nginx:v1
        ports:
        - containerPort: 80
EOF
kubectl apply -f acr-nginx.yaml

kubectl get pods
# Setting variables
aksClusterGroupName="myAks" # Name of resource group for the AKS cluster
resourceLocation="westeurope" # Name of the location 
aksName="${aksClusterGroupName}-cluster" # Name of the AKS cluster

# Configure "kubectl" to connect to the Kubernetes cluster
az aks get-credentials --resource-group $aksClusterGroupName --name $aksName --admin --overwrite-existing

cat <<EOF > aks-adminaccess-crb.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: contoso-cluster-admins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: marianleica@lesformidables.club
EOF

kubectl apply -f aks-adminaccess-crb.yaml
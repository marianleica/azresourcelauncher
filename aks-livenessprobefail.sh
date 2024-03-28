cat <<EOF > aks-livenessprobefail.yaml
apiVersion: v1
kind: Pod
metadata:
  name: goproxy
  labels:
    app: goproxy
spec:
  containers:
  - name: goproxy
    image: registry.k8s.io/goproxy:0.1
    ports:
    - containerPort: 8080
    readinessProbe:
      tcpSocket:
        port: 8081
      initialDelaySeconds: 5
      periodSeconds: 1
    livenessProbe:
      tcpSocket:
        port: 8081
      initialDelaySeconds: 1
      periodSeconds: 5
EOF

kubectl apply -f aks-livenessprobefail.yaml
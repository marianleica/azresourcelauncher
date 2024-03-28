az containerapp create --name testContainerApp --resource-group containerAppRG  --environment <ENVIRONMENT_NAME> --image <CONTAINER_IMAGE_LOCATION>
  --min-replicas 0 --max-replicas 5 --scale-rule-name azure-tcp-rule --scale-rule-type tcp --scale-rule-tcp-concurrency 100

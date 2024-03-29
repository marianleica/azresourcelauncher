# Azure Resource Launcher
I've made this project a series of deployment scripts out of a need for having an Azure configuration environment ready to test with.
Considering that we also need to keep Azure credit costs low, the environment resource groups are meant for deletion after each use.

## Before you use
The scripts can be run from a terminal console with the built-in `sh` command for MacOS or Linux.
For Windows Client, the .sh scripts can be opened directly if you have Git installed for Windows Client.

Here's how you should get it ready to use:

### For Linux users

### For MacOS users

### For Windows users

(!) Once the repository has been cloned, this is meant to be opened in your IDE and it's up to the user to customize it to your preference. In future versions of the code in this repository, there will be less and less need for that, though this is how it should be used at the moment

## Covered ccenarios and how to run them

`sh aksbasic.sh` -> this creates a basic AKS cluster with kubenet CNI and 3 nodes in a system mode node pool, after which it connects you to the cluster API

## Automated troubleshooting scenarios
Some of the scripts in this repository are automating troubleshooting scenarios.

For example, you might have a basic AKS cluster configuration and when you view the workload in the Azure Portal, you click on 'Pods' and you get error '403 Forbidden', because your cluster was created with the Kubernetes RBAC identity model 
In this situation you may run the `aks-adminaccess-crb.sh` script example which showcases the required clusterRoleBinding which allows the required access. \
(*) Don't forget to add your own Azure account address instead the one currently in the script.

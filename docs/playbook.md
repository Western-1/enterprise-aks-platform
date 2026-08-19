# Playbook — every command explained

[Українська версія](playbook.ua.md)

Commands are run from PowerShell on Windows. Everything below is verified.

## 1. Login and subscription

```powershell
az login --use-device-code   # if the WAM browser dialog does not open, this forces device-code flow
az account show              # confirm which subscription you are on
az account set --subscription "<name>"   # switch if you have several
```

> **Troubleshooting**: if `az login` hangs with `Broker enabled? True` in `--debug`,
> disable the WAM broker once: `az config set core.broker=off`.

## 2. Provision infrastructure (Terraform)

```powershell
cd terraform/environments/dev

# one-time: download providers
terraform init

# create local secrets file (never commit it)
# terraform.tfvars with subscription_id — already in .gitignore
terraform fmt -recursive    # formatting
terraform validate          # static checks
terraform plan              # see the diff
terraform apply             # apply (add -auto-approve to skip confirmation)
```

Expected result of `apply`: resources created in resource group `rg-dev-aks-ne`
(VNet, subnets, ACR, Key Vault, PostgreSQL, AKS, Log Analytics).

## 3. Connect kubectl

```powershell
az aks get-credentials --name aks-dev-cluster-ne --resource-group rg-dev-aks-ne --overwrite-existing
kubectl get nodes
kubectl get pods -A
```

Expected: two `system` nodes `Ready`, and system pods (cilium, gatekeeper,
`aks-secrets-store-csi-driver`, `ama-logs`) all `Running`.

## 4. Work with the Key Vault

```powershell
# list secret names (values are never printed to the repo)
az keyvault secret list --vault-name kv-dev-media-ne --query "[].name" --output table
```

The PostgreSQL password and connection string are written automatically by
Terraform (`db-password`, `db-url`) — never put them in files that reach git.

## 5. Scale / stop / start the cluster (saving money)

```powershell
# scale the whole user pool to 0 (it already does this by itself)
kubectl scale --replicas=0 deployment/<name>

# scale system pool nodes (saves ~$92/mo per node)
az aks scale --name aks-dev-cluster-ne --resource-group rg-dev-aks-ne --node-pool system --node-count 1

# complete teardown of everything
cd terraform/environments/dev
terraform destroy
```

> The cluster costs ~$210/month running 24/7. Stop it when you finish working.
> `terraform destroy` removes all resources and the state — the next `terraform apply`
> rebuilds the exact same platform.

## 6. Common checks

```powershell
az aks show --name aks-dev-cluster-ne --resource-group rg-dev-aks-ne --query "{state:provisioningState, version:kubernetesVersion}"
az postgres flexible-server show --name psql-dev-media-ne --resource-group rg-dev-aks-ne --query "{state:state, version:version}"
az acr show --name acrdevmedia --query "{loginServer:loginServer, sku:sku.name}"
```

## 7. Cost check

```powershell
# in the portal: Cost Management + Billing → Cost analysis → filter rg-dev-aks-ne
# update docs/costs.md and docs/costs.ua.md afterwards
```
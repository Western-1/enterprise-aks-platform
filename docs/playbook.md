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

## 8. Argo CD (GitOps)

Argo CD UI is public via an Azure Load Balancer (Standard, frontend IP from the cluster
outbound LB):

```powershell
# open in the browser (admin / initial password from the secret below)
# URL: http://<frontend-ip>/ — get it with:
kubectl get svc argocd-server -n argocd -o jsonpath="{.status.loadBalancer.ingress[0].ip}"

# initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# CLI (argocd.exe)
argocd login <frontend-ip>:80 --username admin --password <password> --insecure
argocd app list                     # applications and their sync status
argocd app sync <app-name>          # force sync
argocd app get cluster-config       # details and resources
```

> Note: the server runs with `server.insecure: true` (plain HTTP) for the demo — Argo CD
> serves TLS itself in production setups, usually behind an ingress with SSO.
>
> Note: `kubectl port-forward` to Argo CD does not work on this cluster — the Cilium
> datapath refuses traffic to the service port on node IPs (LB backend port = service port
> with floating IP; only nodePort is intercepted). The LoadBalancer service is the
> supported way in. The NSG `nsg-aks` allows 80/443 from the Internet for LB frontends —
> extend `lb_ingress_ports` in Terraform for other ports.

### How to add a new app to the cluster

1. Push manifests to `enterprise-aks-gitops` (e.g. `apps/media-api/`).
2. Add an `Application` manifest to `enterprise-aks-gitops/infrastructure/argocd/`.
3. Push. Argo CD syncs the new Application within a minute — **no kubectl apply needed**.

## 9. Demo app end-to-end (media-api)

```powershell
# pods and the db-init job
kubectl get pods -n media
kubectl logs -n media job/db-init        # "database 'media' created"

# in-cluster health (port-forward does not work on this cluster)
kubectl exec deploy/media-api -n media -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/healthz').read().decode())"
# {"status":"ok","db":true,"redis":true,"http":200}

# public load balancer (port 8080, see terraform lb_ingress_ports)
curl.exe http://4.245.138.35:8080/healthz
curl.exe -X POST http://4.245.138.35:8080/media/items -H "Content-Type: application/json" -d "@item.json"
curl.exe http://4.245.138.35:8080/media/items   # view_count grows — the worker processed the queue
```

Expected: `/healthz` is `ok` with `db` and `redis` true; POST returns 201 with an `id`;
GET lists the item.

### Troubleshooting the demo (lessons learned)

| Symptom | Root cause | Fix |
|---|---|---|
| `ImagePullBackOff`, `Failed to authorize ... acr-credential-provider` | `AcrPull` was granted to the cluster system identity, but images are pulled by the agent-pool **kubelet identity** | `principal_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id` (modules/aks) |
| `no pg_hba.conf entry ... no encryption` from asyncpg | Password URL was malformed (`@`, `&`, `#` unescaped) or the pod missed the `app: media` label for `allow-db-egress` | Alphanumeric password + `%40`-encoded username; label every DB-speaking pod |
| Terraform/CLI change "succeeds" but server ignores it | Wrong REST property name (`authentication` instead of `authConfig`); password ops are async — poll the operation | Use `properties.authConfig`; poll `Azure-AsyncOperation` until `Succeeded` |
| `AADSTS500011` for `https://ossrdbms.database.windows.net` | Flexible Server expects the **ossrdbms-aad** audience | Scope `https://ossrdbms-aad.database.windows.net/.default` |
| Token exchange hangs in the pod | `default-deny` blocks egress to `login.microsoftonline.com:443` | `allow-aad-egress` NetworkPolicy (TCP 443); the Cilium FQDN variant did not take effect here |
| Argo CD sync stuck on `Job ... field is immutable` | Job pod template changed | `kubectl delete job <name> -n media`, let Argo recreate it, then sync |
# Recovery runbook — stopped cluster

[Українська версія](recovery.ua.md)

## Status (September 10, 2026)

- The subscription is read-only (`ReadOnlyDisabledSubscription`, trial credits
  likely exhausted). All writes are blocked: `az aks start`, `terraform apply`,
  and Terraform state access (`403 AccountIsDisabled`).
- AKS `aks-dev-cluster-ne` is `Deallocated` / `Failed`; the API FQDN does not
  resolve; both public HTTPS endpoints time out.
- Nothing accrues while the subscription is disabled. Last known spend:
  **$71.33 MTD (September 8)**.
- Code is safe: platform code and both open PRs are on GitHub. The Terraform
  state blob is unreachable until the subscription is re-enabled (the code can
  rebuild everything if the worst happens).

## Parked work

- **PR #18** — quota-safe upgrades (user pool `max_unavailable = 1`; system
  pool zero-surge via CLI, because azurerm supports only `max_surge` there).
- **GitOps `main`** — self-signed demo TLS for `media-api` and the Argo CD
  HTTPS ingress (committed; Argo CD syncs them on restart).

## Resume (after re-enabling the subscription)

```powershell
az aks start --resource-group rg-dev-aks-ne --name aks-dev-cluster-ne
az aks nodepool update --resource-group rg-dev-aks-ne --cluster-name aks-dev-cluster-ne --nodepool-name system --max-surge 0 --max-unavailable 1
az aks get-credentials --name aks-dev-cluster-ne --resource-group rg-dev-aks-ne --overwrite-existing
kubectl get nodes
kubectl get ingress,certificate -A
curl.exe -sk https://media.4-210-50-215.nip.io/healthz
curl.exe -sk -o NUL -w "%{http_code}" https://argocd.4-210-50-215.nip.io/
cd terraform/environments/dev
terraform plan    # state reachable again
terraform apply
```

- If a pool stays `Failed`, reconcile it with a no-change update:
  `az aks nodepool update --resource-group rg-dev-aks-ne --cluster-name aks-dev-cluster-ne --nodepool-name <pool>`.
- Then merge PR #18 (squash), delete the branch, and update `docs/costs.md`.

## Costs on resume

Idle ≈ **$218/mo**; the two system nodes (≈ $184/mo) resume billing immediately
on `az aks start`. Keep the user pool at 0 and stop the cluster after work.

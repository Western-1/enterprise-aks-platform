# Azure costs — Enterprise AKS Platform

All amounts are approximate and based on [Azure pricing](https://azure.microsoft.com/en-us/pricing/)
for **northeurope**, dev environment. Actual numbers are taken from
Azure Cost Management (`Cost analysis`) and updated here.

Prices marked `approx` are estimates; final bills may differ by a few dollars.
The subscription currently runs on **$200 free credits** — no card is charged
unless the spending limit is explicitly removed.

## Current infrastructure (dev)

| Resource | Configuration | Estimated cost | Actual cost | Notes |
|---|---|---|---|---|
| Resource group | `rg-dev-aks-ne` | $0 | | Free |
| VNet + subnets + NSG | `vnet-dev-aks-ne` | $0 | | Free |
| Private DNS zones | `privatelink.*` | $0 | | Free |
| Private endpoints | Key Vault | $0 | | Free |
| Container Registry | `acrdevmedia` (Basic) | ~$3 / mo | | Storage + pushes may add cents |
| Key Vault | `kv-dev-media-ne` (standard) | ~$0–1 / mo | | Free tier 10k transactions |
| Log Analytics | `la-dev-aks-ne`, 30 days retention | ~$3 / mo | | Per-GB ingest |
| AKS control plane | Free tier | $0 | | |
| AKS system pool | 2× `Standard_EC2as_v5` | ~$184 / mo | | Confidential compute — the only VM family allowed by the trial subscription |
| AKS user pool | `Standard_EC2as_v5`, 0–1 nodes (autoscaled) | $0–92 / mo | | $0 while idle |
| PostgreSQL | `psql-dev-media-ne` (B1ms, 32 GB, PG16) | ~$20 / mo | | Private endpoint only; passwordless Entra ID auth (KV secrets kept as legacy) |
| Public IP (Argo CD LB) | Standard static IP `kubernetes-*` in MC_ RG | ~$3.5 / mo | | Live until deletion: `20.54.22.159` (HTTP, `server.insecure: true`) |
| Public IP (ingress-nginx LB) | Standard static IP `kubernetes-*` in MC_ RG | ~$3.5 / mo | | Live until deletion: `4.210.50.215` for nip.io HTTPS (media + Argo); replaced the earlier per-app `media-api-lb` on `:8080` |
| Redis | In-cluster `Deployment` in `media` | $0 | | Queue between API and worker; Azure Cache for Redis was never created (verified) |
| Storage (Terraform state) | `sttfaksdevne02` (Standard_LRS) | ~$1 / mo | | Tiny state blob; bootstrapped outside Terraform |
| **Total, idle** | | **~$218 / mo** | | |
| **Total, under load** | | **~$310 / mo** | | |

## Planned resources (not yet created)

| Resource | Configuration | Estimated cost | Notes |
|---|---|---|---|
| Prometheus + Grafana | In-cluster | $0 | Runs on existing nodes |

## How costs are measured

1. Azure portal → **Cost Management + Billing** → *Cost analysis* → filter by resource group `rg-dev-aks-ne`.
2. Export monthly totals and update the "Actual cost" column.
3. Before creating anything new: add a row to *Planned resources* first.

### Actuals, September 2026 (month-to-date, Sep 8)

| Scope | Actual cost | Notes |
|---|---|---|
| `mc_rg-dev-aks-ne_aks-dev-cluster-ne_northeurope` (nodes, disks, LB) | $56.94 | 8 days of VM runtime |
| `rg-dev-aks-ne` (PostgreSQL, IPs, ACR, Key Vault, storage, logs) | $14.39 | |
| **Total MTD** | **$71.33** | Pace ≈ $267/mo — above the ~$218 idle estimate (user node was up at times) |

### Status, September 10, 2026

- Subscription is read-only (`ReadOnlyDisabledSubscription`, trial credits
  likely exhausted): AKS is `Deallocated`, all writes (start, apply, state
  access) are blocked, and **nothing accrues** while disabled.
- Resume plan and exact commands: [docs/recovery.md](recovery.md). Pending:
  PR #18 (quota-safe upgrades) and the post-start verification.

### Final, September 10, 2026 — cluster deleted

- Per owner decision (no billing actions): `az aks delete` was accepted and
  `aks-dev-cluster-ne` is gone (`ResourceNotFound`; node resource group
  `MC_rg-dev-aks-ne_aks-dev-cluster-ne_northeurope` is removed with it).
  Remaining resources (VNet, ACR, Key Vault, PostgreSQL, IPs, Log Analytics,
  state storage) stay in place but accrue **$0** while the subscription is
  disabled.
- Last known spend: **$71.33 MTD (September 8)**. Rebuild is possible from
  code at any time after re-enabling: `terraform apply` in
  `terraform/environments/dev`, then Argo CD syncs the GitOps repo.
- Residue (verified Sep 10, after delete): the node resource group
  `MC_rg-dev-aks-ne_aks-dev-cluster-ne_northeurope` still lists the VMSSs,
  3 public IPs, disks and identities — Azure-side cleanup is pending (likely
  blocked by the disabled subscription). $0 while disabled; on re-enable,
  confirm the group is gone, otherwise delete it manually.

## Cleanup

- After the task is done: `terraform destroy` in `terraform/environments/dev`, then update this file.
- The user pool scales to **0** when idle — the cluster itself keeps running.
- See `docs/playbook.md` for the full lifecycle commands.

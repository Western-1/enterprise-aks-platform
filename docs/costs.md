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
| **Total, idle** | | **~$190 / mo** | | |
| **Total, under load** | | **~$282 / mo** | | |

## Planned resources (not yet created)

| Resource | Configuration | Estimated cost | Notes |
|---|---|---|---|
| PostgreSQL Flexible Server | Basic `B1ms`, 32 GB | ~$16 / mo | Only if the app needs it in dev |

## How costs are measured

1. Azure portal → **Cost Management + Billing** → *Cost analysis* → filter by resource group `rg-dev-aks-ne`.
2. Export monthly totals and update the "Actual cost" column.
3. Before creating anything new: add a row to *Planned resources* first.

## Cleanup

- After the task is done: `terraform destroy` in `terraform/environments/dev`, then update this file.
- The user pool scales to **0** when idle — the cluster itself keeps running.
- See `docs/playbook.md` for the full lifecycle commands.

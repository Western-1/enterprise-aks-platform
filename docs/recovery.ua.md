# Runbook відновлення — зупинений кластер

[English version](recovery.md)

## Статус (10 вересня 2026)

- Підписка read-only (`ReadOnlyDisabledSubscription`, імовірно вичерпано
  trial-кредити). Усі записи заблоковано: `az aks start`, `terraform apply`
  і доступ до Terraform state (`403 AccountIsDisabled`).
- AKS `aks-dev-cluster-ne` — `Deallocated` / `Failed`; API FQDN не резолвиться;
  обидва публічні HTTPS-ендпоїнти не відповідають.
- Поки підписка вимкнена, нарахувань немає. Останні відомі витрати:
  **$71.33 MTD (8 вересня)**.
- Код у безпеці: код платформи й обидва відкриті PR на GitHub. State-блоб
  Terraform недоступний до повторного ввімкнення підписки (у гіршому разі
  код усе перебудує).

## Відкладена робота

- **PR #18** — безпечні для квоти оновлення (user pool `max_unavailable = 1`;
  system pool zero-surge через CLI, бо azurerm підтримує там лише `max_surge`).
- **GitOps `main`** — self-signed demo TLS для `media-api` та HTTPS ingress
  Argo CD (закомічено; Argo CD синхронізує їх після рестарту).

## Повернення (після повторного ввімкнення підписки)

```powershell
az aks start --resource-group rg-dev-aks-ne --name aks-dev-cluster-ne
az aks nodepool update --resource-group rg-dev-aks-ne --cluster-name aks-dev-cluster-ne --nodepool-name system --max-surge 0 --max-unavailable 1
az aks get-credentials --name aks-dev-cluster-ne --resource-group rg-dev-aks-ne --overwrite-existing
kubectl get nodes
kubectl get ingress,certificate -A
curl.exe -sk https://media.4-210-50-215.nip.io/healthz
curl.exe -sk -o NUL -w "%{http_code}" https://argocd.4-210-50-215.nip.io/
cd terraform/environments/dev
terraform plan    # state знову доступний
terraform apply
```

- Якщо pool завис у `Failed`, реконсилюй no-change оновленням:
  `az aks nodepool update --resource-group rg-dev-aks-ne --cluster-name aks-dev-cluster-ne --nodepool-name <pool>`.
- Потім merge PR #18 (squash), видали гілку й онови `docs/costs.ua.md`.

## Витрати після повернення

Простій ≈ **$218/міс**; дві system-ноди (≈ $184/міс) починають біллятися одразу
після `az aks start`. Тримай user pool на 0 і зупиняй кластер після роботи.

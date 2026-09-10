# Витрати Azure — Enterprise AKS Platform

Усі суми приблизні, взяті з [тарифів Azure](https://azure.microsoft.com/en-us/pricing/)
для регіону **northeurope**, dev-середовище. Фактичні суми беруться з
Azure Cost Management (`Cost analysis`) і оновлюються тут.

Ціни з позначкою `approx` — оціночні; остаточний рахунок може відрізнятися на кілька доларів.
Підписка зараз працює на **безкоштовних кредитах $200** — картка не списується,
поки ліміт витрат (spending limit) не знято явно.

## Поточна інфраструктура (dev)

| Ресурс | Конфігурація | Орієнтовна вартість | Фактична вартість | Нотатки |
|---|---|---|---|---|
| Resource group | `rg-dev-aks-ne` | $0 | | Безкоштовно |
| VNet + підмережі + NSG | `vnet-dev-aks-ne` | $0 | | Безкоштовно |
| Private DNS зони | `privatelink.*` | $0 | | Безкоштовно |
| Private endpoints | Key Vault | $0 | | Безкоштовно |
| Container Registry | `acrdevmedia` (Basic) | ~$3 / міс | | Сховище та пуши — копійки |
| Key Vault | `kv-dev-media-ne` (standard) | ~$0–1 / міс | | Безкоштовний тариф 10k транзакцій |
| Log Analytics | `la-dev-aks-ne`, збереження 30 днів | ~$3 / міс | | Оплата за ГБ |
| AKS control plane | Free tier | $0 | | |
| AKS system pool | 2× `Standard_EC2as_v5` | ~$184 / міс | | Confidential compute — єдина родина VM, яку дозволяє trial-підписка |
| AKS user pool | `Standard_EC2as_v5`, 0–1 ноди (автоскейлінг) | $0–92 / міс | | $0 у простої |
| PostgreSQL | `psql-dev-media-ne` (B1ms, 32 ГБ, PG16) | ~$20 / міс | | Тільки private endpoint; вхід без пароля через Entra ID (секрети KV — legacy) |
| Публічний IP (LB Argo CD) | Standard static IP `kubernetes-*` у MC_ RG | ~$3.5 / міс | | Live до видалення: `20.54.22.159` (HTTP, `server.insecure: true`) |
| Публічний IP (LB ingress-nginx) | Standard static IP `kubernetes-*` у MC_ RG | ~$3.5 / міс | | Live до видалення: `4.210.50.215` для nip.io HTTPS (media + Argo); замінив ранній окремий `media-api-lb` на `:8080` |
| Redis | Под (`Deployment`) у `media` | $0 | | Черга між API та воркером; Azure Cache for Redis ніколи не створювався (перевірено) |
| Сховище (Terraform state) | `sttfaksdevne02` (Standard_LRS) | ~$1 / міс | | Крихітний state-блоб; забутстраплено поза Terraform |
| **Разом, у простої** | | **~$218 / міс** | | |
| **Разом, під навантаженням** | | **~$310 / міс** | | |

## Заплановані ресурси (ще не створені)

| Ресурс | Конфігурація | Орієнтовна вартість | Нотатки |
|---|---|---|---|
| Prometheus + Grafana | In-cluster | $0 | Працює на наявних нодах |

## Як вимірюються витрати

1. Azure portal → **Cost Management + Billing** → *Cost analysis* → фільтр за resource group `rg-dev-aks-ne`.
2. Експортувати місячні суми й оновити колонку «Фактична вартість».
3. Перед створенням чогось нового — спочатку додати рядок у *Заплановані ресурси*.

### Факт, вересень 2026 (з початку місяця, на 8 вересня)

| Область | Фактична вартість | Примітки |
|---|---|---|
| `mc_rg-dev-aks-ne_aks-dev-cluster-ne_northeurope` (ноди, диски, LB) | $56.94 | 8 днів роботи VM |
| `rg-dev-aks-ne` (PostgreSQL, IP, ACR, Key Vault, сховище, логи) | $14.39 | |
| **Разом MTD** | **$71.33** | Темп ≈ $267/міс — вище оцінки простою ~$218 (user-нода часом була піднята) |

### Статус, 10 вересня 2026

- Підписка read-only (`ReadOnlyDisabledSubscription`, імовірно вичерпано
  trial-кредити): AKS `Deallocated`, усі записи (start, apply, доступ до state)
  заблоковано, і **нарахувань немає**, поки вимкнено.
- План повернення й точні команди: [docs/recovery.ua.md](recovery.ua.md).
  Відкладено: PR #18 (безпечні для квоти оновлення) і перевірка після старту.

### Фінал, 10 вересня 2026 — кластер видалено

- За рішенням власника (без білінгових дій): `az aks delete` прийнято,
  `aks-dev-cluster-ne` зник (`ResourceNotFound`; node resource group
  `MC_rg-dev-aks-ne_aks-dev-cluster-ne_northeurope` видалено разом із ним).
  Решта ресурсів (VNet, ACR, Key Vault, PostgreSQL, IP, Log Analytics,
  state storage) лишаються, але коштують **$0**, поки підписка вимкнена.
- Останні відомі витрати: **$71.33 MTD (8 вересня)**. Перебудова з коду
  можлива будь-коли після ввімкнення: `terraform apply` у
  `terraform/environments/dev`, далі Argo CD синхронізує GitOps-репо.
- Залишки (перевірено 10 вересня, після delete): node resource group
  `MC_rg-dev-aks-ne_aks-dev-cluster-ne_northeurope` досі показує VMSS,
  3 публічні IP, диски та identities — прибирання на боці Azure в очікуванні
  (імовірно заблоковано вимкненою підпискою). $0, поки вимкнено; після
  ввімкнення перевір, що група зникла, інакше видали вручну.

## Прибирання

- Після завершення задачі: `terraform destroy` у `terraform/environments/dev`, потім оновити цей файл.
- User pool масштабується до **0** у простої — сам кластер продовжує працювати.
- Повний цикл життя — у `docs/playbook.md`.

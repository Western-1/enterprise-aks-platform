# Плейбук — кожна команда пояснена

[English version](playbook.md)

Команди запускаються з PowerShell на Windows. Усе нижче перевірено.

## 1. Вхід і підписка

```powershell
az login --use-device-code   # якщо браузерне вікно WAM не відкрилось — цей прапорець примусово вмикає device-code flow
az account show              # яка підписка зараз
az account set --subscription "<назва>"   # перемкнути, якщо їх декілька
```

> **Порада**: якщо `az login` зависає, а в `--debug` видно `Broker enabled? True`,
> вимкніть WAM-брокер один раз: `az config set core.broker=off`.

## 2. Підняття інфраструктури (Terraform)

```powershell
cd terraform/environments/dev

# один раз: завантажити провайдерів
terraform init

# створити локальний файл секретів (ніколи не комітити)
# terraform.tfvars з subscription_id — вже у .gitignore
terraform fmt -recursive    # форматування
terraform validate          # статичні перевірки
terraform plan              # подивитись, що зміниться
terraform apply             # застосувати (додайте -auto-approve, щоб пропустити підтвердження)
```

Очікуваний результат `apply`: ресурси створені в resource group `rg-dev-aks-ne`
(VNet, підмережі, ACR, Key Vault, PostgreSQL, AKS, Log Analytics).

## 3. Підключення kubectl

```powershell
az aks get-credentials --name aks-dev-cluster-ne --resource-group rg-dev-aks-ne --overwrite-existing
kubectl get nodes
kubectl get pods -A
```

Очікується: дві ноди `system` у статусі `Ready`, системні поди (cilium, gatekeeper,
`aks-secrets-store-csi-driver`, `ama-logs`) — усі `Running`.

## 4. Робота з Key Vault

```powershell
# список назв секретів (значення ніколи не друкуються в репозиторій)
az keyvault secret list --vault-name kv-dev-media-ne --query "[].name" --output table
```

Секрети в Key Vault створює Terraform — ніколи не кладіть їх у файли,
що потрапляють у git.

> Сховище зараз навмисно порожнє: застосунок входить без пароля (Entra ID),
> тож legacy-секрети `db-password` / `db-url` видалено. Admin-пароль існує
> лише в Terraform state (break-glass).

## 5. Масштабування / зупинка / запуск кластера (економія)

```powershell
# зменшити user pool до 0 (він і сам так робить)
kubectl scale --replicas=0 deployment/<назва>

# зменшити ноди system pool (економить ~$92/міс за ноду)
az aks scale --name aks-dev-cluster-ne --resource-group rg-dev-aks-ne --node-pool system --node-count 1

# повне знесення всього
cd terraform/environments/dev
terraform destroy
```

> Кластер коштує ~$210/міс при роботі 24/7. Зупиняйте його після роботи.
> `terraform destroy` видаляє всі ресурси і state — наступний `terraform apply`
> перебудує ту саму платформу.

## 6. Часті перевірки

```powershell
az aks show --name aks-dev-cluster-ne --resource-group rg-dev-aks-ne --query "{state:provisioningState, version:kubernetesVersion}"
az postgres flexible-server show --name psql-dev-media-ne --resource-group rg-dev-aks-ne --query "{state:state, version:version}"
az acr show --name acrdevmedia --query "{loginServer:loginServer, sku:sku.name}"
```

### Безпечні для квоти оновлення AKS

Dev-підписка має чотири регіональні vCPU, які зайняті двома system-нодами.
User pool використовує `max_unavailable = "1"` у Terraform (без surge-нод).
System (default) pool так не вміє — azurerm 4.81 підтримує там лише `max_surge`,
тому його zero-surge policy застосовується разово через CLI і зберігається
(Terraform це поле не керує, тож дрейфу немає):

```powershell
az aks nodepool update --resource-group rg-dev-aks-ne --cluster-name aks-dev-cluster-ne --nodepool-name system --max-surge 0 --max-unavailable 1
```

Під час оновлення одна нода може бути недоступною; перед переходом на surge
policy збільште регіональну vCPU-квоту.

## 7. Перевірка витрат

```powershell
# у порталі: Cost Management + Billing → Cost analysis → фільтр rg-dev-aks-ne
# після цього оновіть docs/costs.md і docs/costs.ua.md
```

## 8. Argo CD (GitOps)

UI Argo CD публічний через Azure Load Balancer (Standard, frontend IP з кластерного
outbound LB):

```powershell
# відкрийте в браузері (admin / початковий пароль із секрету нижче)
# URL: http://<frontend-ip>/ — отримайте його:
kubectl get svc argocd-server -n argocd -o jsonpath="{.status.loadBalancer.ingress[0].ip}"

# початковий пароль адміністратора
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# CLI (argocd.exe)
argocd login <frontend-ip>:80 --username admin --password <пароль> --insecure
argocd app list                     # застосунки та їхній sync-статус
argocd app sync <app-name>          # примусова синхронізація
argocd app get cluster-config       # деталі та ресурси
```

> Примітка: сервер працює з `server.insecure: true` (чистий HTTP) для демо — у проду
> Argo CD сам обслуговує TLS, зазвичай за ingress з SSO.
>
> Примітка: `kubectl port-forward` до Argo CD на цьому кластері не працює — датаплейн
> Cilium відкидає трафік на порт сервісу на IP ноди (backend LB = порт сервісу з
> floating IP; перехоплюється тільки nodePort). Підтримуваний шлях — LoadBalancer-сервіс.
> NSG `nsg-aks` дозволяє 80/443 з Інтернету для frontend LB — для інших портів розширте
> `lb_ingress_ports` у Terraform.

### Як додати новий застосунок у кластер

1. Запуште маніфести в `enterprise-aks-gitops` (наприклад, `apps/media-api/`).
2. Додайте маніфест `Application` у `enterprise-aks-gitops/infrastructure/argocd/`.
3. Пуш. Argo CD синхронізує новий застосунок протягом хвилини — **kubectl apply не потрібен**.

## 9. Демо-застосунок end-to-end (media-api)

```powershell
# поди та db-init job
kubectl get pods -n media
kubectl logs -n media job/db-init        # "database 'media' created"

# health усередині кластера (port-forward на цьому кластері не працює)
kubectl exec deploy/media-api -n media -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/healthz').read().decode())"
# {"status":"ok","db":true,"redis":true,"http":200}

# публічний load balancer (порт 8080, див. terraform lb_ingress_ports)
curl.exe http://4.245.138.35:8080/healthz
curl.exe -X POST http://4.245.138.35:8080/media/items -H "Content-Type: application/json" -d "@item.json"
curl.exe http://4.245.138.35:8080/media/items   # view_count росте — воркер обробив чергу
```

Очікувано: `/healthz` — `ok` з `db` і `redis` true; POST повертає 201 з `id`;
GET показує елемент.

### Діагностика демо (вивчені уроки)

| Симптом | Причина | Лікування |
|---|---|---|
| `ImagePullBackOff`, `Failed to authorize ... acr-credential-provider` | `AcrPull` видано system identity кластера, а образи тягне **kubelet identity** агент-пулу | `principal_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id` (modules/aks) |
| `no pg_hba.conf entry ... no encryption` з asyncpg | Кривий URL пароля (неекрановані `@`, `&`, `#`) або под без лейбла `app: media` для `allow-db-egress` | Буквено-цифровий пароль + username з `%40`; лейбл на кожен под, що говорить із БД |
| Зміна через Terraform/CLI «успішна», але сервер її ігнорує | Хибне ім'я REST-властивості (`authentication` замість `authConfig`); операції з паролем асинхронні — треба пильнувати операцію | Використовувати `properties.authConfig`; чекати `Azure-AsyncOperation` до `Succeeded` |
| `AADSTS500011` для `https://ossrdbms.database.windows.net` | Flexible Server чекає audience **ossrdbms-aad** | Scope `https://ossrdbms-aad.database.windows.net/.default` |
| Обмін токена висить у поді | `default-deny` блокує egress до `login.microsoftonline.com:443` | NetworkPolicy `allow-aad-egress` (TCP 443); варіант Cilium FQDN тут не спрацював |
| Синк Argo CD застряг на `Job ... field is immutable` | Змінився pod template job | `kubectl delete job <name> -n media`, Argo перестворить, потім sync |

## 10. CI/CD (GitHub Actions, OIDC, без секретів)

- `ci.yml` (PR + main): `terraform fmt/validate/plan` (remote state), Checkov,
  pytest на Python 3.12, збірка docker, Trivy-скан образу.
- `cd.yml` (main): збирає й пушить у ACR образ із тегом `sha-<short>`, потім піднімає
  тег у маніфестах `apps/media` в enterprise-aks-gitops (коміт від
  `github-actions[bot]`), щоб Argo CD задеплоїв, — повний цикл перевірено.
  Потрібен секрет `GITOPS_PAT` (класик-PAT зі scope `repo` або fine-grained
  із Contents write на GitOps-репо); без нього крок варнить і скіпає.
- Job `db-init` має `Replace=true`: pod template у Job незмінний, тож Argo
  видаляє й перестворює його на bump тега замість падіння синку
  (bootstrap-скрипт ідемпотентний).
- Автентикація — OIDC: app registration `github-actions-oidc` з federated
  credentials для `ref:refs/heads/main` і `pull_request` (увага: GitHub шле
  subject із суфіксами `@owner-id/@repo-id` — у разі помилки AADSTS700213
  скопіюй subject дослівно з тексту помилки). Ролі (мінімальні): Reader на
  підписку, AcrPush на ACR, Storage Blob Data Contributor на state-сховище,
  AKS Cluster User на кластер, Key Vault Secrets User на сховище.
- CI-план іде з `-refresh=false`: firewall Key Vault (за дизайном) блокує
  data plane ранера; refresh відбувається на apply.
- State Terraform лежить у `sttfaksdevne02/tfstate` (забутстраплено разово, поза
  Terraform). Змінні репо (не секрети): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
  `AZURE_SUBSCRIPTION_ID`, `TF_VAR_current_user_object_id`, `TF_VAR_home_ip`.

## 11. Моніторинг (kube-prometheus-stack через Argo CD)

```powershell
# здоров'я стека
kubectl get pods -n monitoring
kubectl get prometheus -n monitoring
kubectl get app monitoring -n argocd

# admin-пароль Grafana (генерує чарт)
kubectl -n monitoring get secret monitoring-grafana -o jsonpath="{.data.admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# метрика застосунку end-to-end (запустити з пода в неймспейсі monitoring,
# напр. kubectl run promq --image=nicolaka/netshoot -n monitoring)
curl "http://monitoring-kube-prometheus-prometheus.monitoring:9090/api/v1/query?query=media_items_created_total"
# {"status":"success",...,"media_items_created_total",...,"1"}
```

Очікувано: усі поди моніторингу Running, Prometheus `1` desired/ready,
`media_items_created_total` росте з кожним POST /media/items.

> У Grafana навмисно немає публічного ендпоїнта (зайві ~$3.5/міс за frontend):
> перевіряти через Prometheus API зсередини кластера.

```powershell
# трейси: згенерувати трафік, потім пошукати в Tempo з пода в monitoring
curl.exe -X POST http://4.245.138.35:8080/media/items -H "Content-Type: application/json" -d "@item.json"
kubectl run tempoq --image=nicolaka/netshoot --restart=Never -n monitoring -- sleep 300
kubectl exec tempoq -n monitoring -- curl -s "http://tempo.monitoring:3200/api/search?limit=5"
# {"traces":[{"traceID":"...","rootServiceName":"media-api","rootTraceName":"GET /healthz",...}, ...]}
kubectl delete pod tempoq -n monitoring
```

> Чарт колектора 0.172+ вимагає явний `image.repository`
> (`otel/opentelemetry-collector-contrib`); Service tempo віддає OTLP лише для
> receivers із заданим `endpoint` (`0.0.0.0:4317` / `:4318`).

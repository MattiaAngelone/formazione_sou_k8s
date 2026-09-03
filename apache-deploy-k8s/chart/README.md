# Deploy di Apache su Kubernetes con Helm, TLS e Ingress

Questo esercizio esegue il deploy di **Apache HTTP Server** su Kubernetes tramite un chart Helm personalizzato.

Il chart crea:

* un `Deployment` con due repliche Apache;
* un `Service` interno al cluster;
* un `Ingress` NGINX raggiungibile tramite `apache.formazione.local`;
* un certificato TLS autofirmato per HTTPS;
* readiness probe, liveness probe, resource requests e limits.

## Struttura del chart

```text
charts/apache-tls/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── configmap.yaml
    ├── secret.yaml
    ├── deployment.yaml
    ├── service.yaml
    └── ingress.yaml
```

| File              | Funzione                                           |
| ----------------- | -------------------------------------------------- |
| `Chart.yaml`      | Contiene nome e versione del chart.                |
| `values.yaml`     | Raccoglie i valori configurabili.                  |
| `configmap.yaml`  | Definisce la configurazione SSL di Apache.         |
| `secret.yaml`     | Genera e conserva il certificato TLS.              |
| `deployment.yaml` | Avvia Apache e monta configurazione e certificato. |
| `service.yaml`    | Espone Apache nel cluster sulle porte 80 e 443.    |
| `ingress.yaml`    | Instrada le richieste HTTPS verso il Service.      |

## Come funziona

* I valori presenti in `values.yaml` vengono inseriti nei manifest durante il rendering dei template Helm.
* Il certificato, a differenza dei manifests singoli, è generato con `genSelfSignedCert`. La funzione `lookup` permette di riutilizzarlo durante gli aggiornamenti della release.
* Il Deployment abilita SSL, monta Secret e ConfigMap e controlla Apache tramite probe HTTPS.
* L'annotazione `checksum/config` riavvia i Pod quando cambia la configurazione SSL.
* L'Ingress usa NGINX e inoltra le richieste al backend in HTTPS tramite `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"`.

> Eventuali risorse Apache create in precedenza con manifest singoli devono essere rimosse prima di installare il chart.

## Installazione

Posizionarsi nella cartella `charts` della repository:

```bash
cd formazione_sou_k8s/charts
```

Controllare il chart e visualizzare i manifest che verranno generati:

```bash
helm lint ./apache-tls
helm template apache ./apache-tls -n formazione-sou
```

Installare o aggiornare la release:

```bash
helm upgrade --install apache ./apache-tls -n formazione-sou
```

## Verifica

```bash
helm list -n formazione-sou
kubectl get deployment,pods,service,ingress,configmap,secret -n formazione-sou
kubectl rollout status deployment/apache -n formazione-sou
curl -k https://apache.formazione.local/
```

La verifica è conclusa correttamente quando:

* la release `apache` risulta installata;
* i Pod sono nello stato `1/1 Running`;
* l’Ingress usa l’host `apache.formazione.local`;
* `curl` restituisce la pagina predefinita di Apache.

L’opzione `-k` è necessaria perché il certificato è autofirmato e non proviene da una CA pubblica.

## Comandi utili

```bash
helm get values apache -n formazione-sou    # mostra i valori della release
helm history apache -n formazione-sou       # mostra le revisioni
helm rollback apache 1 -n formazione-sou    # torna alla revisione 1
helm uninstall apache -n formazione-sou     # rimuove la release
```

## Risultato finale

Apache viene gestito come un’unica release Helm, configurabile e versionata. L’applicazione è raggiungibile in HTTPS tramite `apache.formazione.local`, mentre certificato, configurazione SSL e collegamenti tra le risorse sono gestiti automaticamente dal chart.

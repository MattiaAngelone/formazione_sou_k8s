# Helm Chart — flask-app-example

Helm Chart per il deploy su Kubernetes dell'immagine Docker prodotta dalla pipeline Jenkins `flask-app-example-multibranch`.

Il chart permette di scegliere **quale tag dell'immagine rilasciare** direttamente al momento del deploy, senza modificare i file YAML.

---

## Obiettivo

La pipeline Jenkins produce immagini nel formato:

```text
mattiaangelone/flask-app-example:<tag>
```

Helm utilizza il tag ricevuto in input per generare il Deployment Kubernetes:

```bash
helm upgrade --install flask-app-example ./charts/flask-app-example \
  -n formazione-sou \
  --set image.tag=v1.0.0
```

Il Deployment utilizzerà quindi:

```text
mattiaangelone/flask-app-example:v1.0.0
```

Se `image.tag` non viene specificato, viene utilizzato il valore `appVersion` presente in `Chart.yaml`.

---

## Struttura

```text
charts/
└── flask-app-example/
    ├── Chart.yaml
    ├── values.yaml
    ├── .helmignore
    └── templates/
        ├── _helpers.tpl
        ├── deployment.yaml
        ├── service.yaml
        ├── serviceaccount.yaml
        ├── NOTES.txt
        └── tests/
            └── test-connection.yaml
```

I componenti `Ingress` e `HorizontalPodAutoscaler` generati dallo scaffold iniziale sono stati rimossi perché non necessari.

> Con Helm 3 il comando utilizzato per generare lo scaffold è `helm create`; `helm init`, presente nelle vecchie versioni di Helm, non viene più utilizzato.

---

## Configurazione principale

I valori principali definiti in `values.yaml` sono:

| Valore             | Default                            | Descrizione                      |
| ------------------ | ---------------------------------- | -------------------------------- |
| `replicaCount`     | `1`                                | Numero di repliche               |
| `image.repository` | `mattiaangelone/flask-app-example` | Repository Docker                |
| `image.tag`        | `""`                               | Tag dell'immagine da rilasciare  |
| `image.pullPolicy` | `IfNotPresent`                     | Policy di download dell'immagine |
| `containerPort`    | `5000`                             | Porta utilizzata dalla Flask app |
| `service.type`     | `NodePort`                         | Tipo di Service Kubernetes       |
| `service.port`     | `80`                               | Porta esposta dal Service        |

Nel Deployment l'immagine viene costruita dinamicamente:

```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
```

Questo permette di utilizzare lo stesso chart per rilasciare versioni diverse dell'applicazione.

---

## Prerequisiti

Sono necessari:

* Kubernetes / Minikube attivo
* Helm 3
* immagine Docker disponibile nel repository
* accesso al cluster tramite `kubectl`

Verifica:

```bash
minikube status
helm version
kubectl get nodes
```

---

## Validazione del chart

Prima del deploy è possibile controllare il chart senza modificare il cluster.

### Controllo sintassi

```bash
helm lint ./charts/flask-app-example
```

### Rendering dei manifest

```bash
helm template test ./charts/flask-app-example \
  --set image.tag=v1.0.0
```

Questo comando permette di verificare, tra le altre cose, che il tag sia stato inserito correttamente nel Deployment.

---

## Deploy

Per installare o aggiornare l'applicazione:

```bash
helm upgrade --install flask-app-example ./charts/flask-app-example \
  --namespace formazione-sou \
  --create-namespace \
  --set image.tag=v1.0.0
```

`upgrade --install` permette di utilizzare lo stesso comando sia per la prima installazione sia per gli aggiornamenti successivi.

Per rilasciare un nuovo tag è sufficiente cambiare il valore:

```bash
helm upgrade --install flask-app-example ./charts/flask-app-example \
  -n formazione-sou \
  --set image.tag=v1.0.1
```

---

## Verifica

Controllare le risorse create:

```bash
kubectl get all -n formazione-sou
```

Controllare quale immagine è utilizzata dal Deployment:

```bash
kubectl get deploy flask-app-example \
  -n formazione-sou \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Per raggiungere l'applicazione tramite Minikube:

```bash
minikube service flask-app-example \
  -n formazione-sou \
  --url
```

---

## Aggiornamenti e rollback

Visualizzare la cronologia delle release:

```bash
helm history flask-app-example -n formazione-sou
```

Ripristinare una revisione precedente:

```bash
helm rollback flask-app-example <REVISIONE> \
  -n formazione-sou
```

Esempio:

```bash
helm rollback flask-app-example 1 \
  -n formazione-sou
```

---

## Disinstallazione

Per rimuovere la release:

```bash
helm uninstall flask-app-example \
  -n formazione-sou
```


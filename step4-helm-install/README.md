# Step 4 — Deploy Helm tramite Jenkins

## Obiettivo

Collegare Jenkins al cluster Minikube locale e creare una pipeline che recuperi il chart dalla repository `formazione_sou_k8s` e lo distribuisca nel namespace `formazione-sou`.

## Preparazione dell’ambiente

### 1. Collegamento delle VM

Jenkins e Minikube si trovano su due VM differenti. Nei rispettivi `Vagrantfile` è stata configurata una rete privata comune:

- VM Rocky con Jenkins: `192.168.56.20`;
- VM Ubuntu con Minikube: `192.168.56.21`.

In questo modo l’agent Jenkins può raggiungere la VM Kubernetes.

### 2. Esposizione dell’API server

Minikube è stato avviato rendendo raggiungibile l’API server dalla rete privata e inserendo l’IP della VM nel certificato TLS:

```bash
minikube start --driver=docker \
  --listen-address=0.0.0.0 \
  --apiserver-ips=192.168.56.21 \
  --apiserver-port=8443
```

Poiché Docker pubblica l’API server su una porta host variabile, è stato creato un relay TCP con `socat`.

Il relay espone l’indirizzo fisso:

```text
https://192.168.56.21:8443
```

e inoltra il traffico verso la porta reale di Minikube senza modificare TLS o credenziali.

Il relay viene avviato automaticamente dal servizio:

```text
/etc/systemd/system/minikube-relay.service
```

### 3. Identità e permessi di Jenkins

Nel namespace `formazione-sou` è stato creato il ServiceAccount `jenkins-deployer`:

```bash
kubectl create serviceaccount jenkins-deployer \
  --namespace formazione-sou
```

Un RoleBinding gli assegna il ClusterRole `edit`, limitatamente al namespace:

```bash
kubectl create rolebinding jenkins-deployer-edit \
  --clusterrole=edit \
  --serviceaccount=formazione-sou:jenkins-deployer \
  --namespace=formazione-sou
```

È stato quindi generato un kubeconfig contenente:

- endpoint `https://192.168.56.21:8443`;
- CA del cluster;
- token del ServiceAccount;
- namespace predefinito `formazione-sou`.

Il kubeconfig è stato caricato in Jenkins come credenziale di tipo **Secret file**, con ID:

```text
kubeconfig-formazione-sou
```

Il file contiene un token e non deve essere inserito nella repository.

### 4. Preparazione dell’agent Jenkins

La pipeline viene eseguita nel container `jenkins-agent`, non sul controller.

Nel `Dockerfile-agent` sono quindi stati installati:

- `kubectl v1.35.1`;
- `Helm v3.19.0`.

La connessione è stata verificata direttamente dal container:

```bash
docker exec jenkins-agent kubectl version --client
docker exec jenkins-agent helm version
docker exec jenkins-agent curl -sk https://192.168.56.21:8443/version
```

### Funzionamento della pipeline

- `agent { label 'docker-agent' }` esegue il job sull’agent che contiene Helm e `kubectl`.
- `IMAGE_TAG` permette di scegliere il tag dell’immagine al momento della build.
- `environment` definisce il percorso del chart, il nome della release e il namespace.
- `withCredentials` rende temporaneamente disponibile il kubeconfig salvato in Jenkins.
- Helm legge automaticamente il file indicato dalla variabile `KUBECONFIG`.
- `helm upgrade --install` installa la release se non esiste oppure la aggiorna se è già presente.
- `--set-string image.tag=...` passa al chart il tag scelto come stringa.
- `--atomic` esegue il rollback automatico se il deploy fallisce.
- `--timeout 5m` imposta un tempo massimo di cinque minuti.

Non è presente uno stage di checkout perché, usando **Pipeline script from SCM**, Jenkins clona automaticamente la repository prima di eseguire gli stage.|

La pipeline viene avviata con **Build with Parameters**, indicando il valore di `IMAGE_TAG`.

## Verifica finale

Al termine del deploy, dalla VM Kubernetes vengono eseguiti i seguenti controlli:

```bash
helm list -n formazione-sou
kubectl get all -n formazione-sou
curl http://$(minikube ip):31273
```

Il risultato atteso è:

- release Helm con stato `deployed`;
- Deployment disponibile;
- Pod in stato `Running`;
- applicazione raggiungibile e risposta `hello world`.

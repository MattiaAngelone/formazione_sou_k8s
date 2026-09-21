# Jenkins CI/CD Lab

Sistema di **Continuous Integration**: un server Jenkins (Master + Agent) automatizzato
con Ansible su una VM Rocky Linux, e una **pipeline dichiarativa** che builda l'immagine Docker di
una web app e la pubblica su Docker Hub.

# Step 1 — Infrastruttura Jenkins

## Scopo

Jenkins è un *automation server*: un servizio sempre attivo che esegue sequenze di operazioni in
risposta a eventi. Da solo non sa fare nulla di specifico — orchestra strumenti esistenti (git,
docker, shell). Questo step costruisce l'infrastruttura su cui gira, applicando l'**infrastructure
as code**: ogni pezzo, dal motore Docker ai container di Jenkins, nasce da codice Ansible, quindi
è documentato, ripetibile e ricostruibile con un comando.

Jenkins si regge su due ruoli: il **Master** è il cervello (interfaccia web, configurazione,
decide cosa eseguire); l'**Agent** sono le braccia (esegue materialmente il lavoro). Separarli
serve alla sicurezza — le build non girano sul controller, che custodisce dati sensibili — e alla
scalabilità.

Una **VM Linux** perché è l'ambiente reale di Jenkins e
isola il lavoro; una **rete Docker dedicata** perché consente di assegnare **IP statici**, e il
Master deve avere un indirizzo fisso affinché l'Agent sappia dove trovarlo.

UI su `http://192.168.56.20:8080`.

## Provisioning

Ansible organizza il lavoro in due **role**, per responsabilità:

- **`docker`** — aggiunge il repository ufficiale Docker CE, installa e avvia il motore, e installa l'SDK Python docker,
  indispensabile perché i moduli Ansible dialogano con Docker tramite quella libreria.
- **`jenkins`** — crea la rete e il volume, builda un'immagine Agent personalizzata (Agent
  ufficiale + client Docker), avvia il container Master e quello Agent con i rispettivi IP statici.

Il volume disaccoppia i dati dal container, che
può essere distrutto e ricreato senza perdite. L'Agent invece **non** ha volume, ed è voluto: è
stateless, e un workspace pulito a ogni build evita che residui di esecuzioni precedenti falsino i
risultati.

## Il nodo Agent

Il Master accetta un Agent solo se questo si presenta con un
**secret** che è il Master stesso a generare. L'ordine è quindi obbligato — prima si crea il nodo
nella UI (che restituisce il secret), poi si avvia il container passandoglielo.

In **Manage Jenkins → Nodes → New Node**: nome `agent1`, Permanent Agent, remote root
`/home/jenkins/agent`, label `docker-agent`, launch method *connectin
g it to the controller*.

# Step 2 — Pipeline dichiarativa (build & push)

## Scopo

A ogni modifica, l'app viene impacchettata in un'immagine Docker e pubblicata su Docker Hub. I passi sono descritti nel `Jenkinsfile`.

L'applicazione è volutamente minima (`flask-app` che risponde `hello world`,
più il suo Dockerfile). Il codice arriva alla pipeline via **Git**: `checkout scm` clona la repo nel workspace dell'Agent.

## Come la pipeline usa Docker

L'Agent è un container che di suo non ha il client Docker né vede il demone della VM. La soluzione è **DooD** (*Docker outside of Docker*):
all'Agent si installa il client e si **monta il socket** `/var/run/docker.sock` della VM. Il client
dentro il container comanda così il demone esterno — l'Agent non fa girare un proprio Docker, e le
immagini finiscono nel Docker della VM. Per i permessi sul socket, l'Agent gira come `user: root`.

## Gli stage

1. **Checkout** — clona la repo nel workspace dell'Agent.
2. **Determina il tag** — Decide quale etichetta utilizzare in base al contesto Git.
3. **Build** — Costruisce l'immagine.
4. **Push** — Pubblica l'immagine dentro dockerhub.

Immagine pubblicata: `mattiaangelone/flask-app-example`.

## Logica dei tag Git

Se l'immagine uscisse sempre come `latest`, ogni build sovrascriverebbe la precedente. Il **tag**
dovrebbe invece dire da dove viene il codice in modo tale da distinguerlo.

| Origine della build      | Tag immagine             | Significato                          |
|--------------------------|--------------------------|--------------------------------------|
| Branch `main` / `master` | `latest`                 | la versione stabile                  |
| Branch `develop`         | `develop-<sha>`    | build di sviluppo  |
| Tag Git (es. `v1.0.0`)   | lo stesso tag            | release ufficiale e immutabile       |

## Job Multibranch

Perché quella logica funzioni, Jenkins deve passare alla pipeline il contesto Git — cosa che un job
Pipeline semplice, legato a un solo branch indicato a mano, non fa in modo affidabile. Il
**Multibranch Pipeline** esplora la repo da solo, scopre branch e tag, e per ognuno esegue una
pipeline con il contesto corretto.
I branch vengono buildati alla scansione,
i **tag** vanno lanciati con *Build Now*.
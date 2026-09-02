# Step 5 — Check Deployment Best Practices

Uno script che verifica se il Deployment dell'app Flask, quello installato dalla pipeline dello
Step 4, dichiara gli attributi minimi richiesti dalle best practice. Se ne manca anche uno, esce con
errore.

Gli attributi controllati sono quattro: **Readiness Probe**, **Liveness Probe**, **Limits** e
**Requests**.

---

## Il problema, e perché serve una seconda identità

Lo Step 4 aveva già prodotto un'identità nel cluster: `jenkins-deployer`, usata dalla pipeline per
installare il chart.

Chi **installa** e chi **verifica** fanno due lavori diversi e devono avere permessi diversi. Il
deployer scrive, ma solo dentro `formazione-sou`. Il reader legge ovunque, ma non può modificare
niente. Se lo stesso account facesse entrambe le cose, un controllo automatico avrebbe il potere di
alterare proprio ciò che sta controllando.

---

## RBAC in quattro oggetti

Kubernetes separa i permessi su due assi, e da questo nascono i quattro oggetti di RBAC.

Il primo asse è **cosa si può fare**. Un **Role** è un elenco di permessi valido dentro un namespace;
un **ClusterRole** è lo stesso elenco, ma definito a livello di cluster.

Il secondo asse è **chi lo può fare**. Un **RoleBinding** assegna permessi dentro un namespace, un
**ClusterRoleBinding** li assegna su tutto il cluster.

una definizione da sola non fa niente. Un ClusterRole è solo un
foglio di carta con scritto cosa sarebbe permesso, finché un binding non lo collega a qualcuno.

Combinando i due assi si ottengono quattro casi:

| Definizione | Binding | Risultato |
|---|---|---|
| Role | RoleBinding | Permessi in quel namespace |
| ClusterRole | RoleBinding | Permessi **solo** nel namespace del binding |
| ClusterRole | ClusterRoleBinding | Permessi su **tutti** i namespace |
| Role | ClusterRoleBinding | Non ammesso |

La seconda riga è quella usata nello Step 4: un ClusterRole dentro un
RoleBinding **non** dà permessi globali. Il ClusterRole dice *quali* permessi, il RoleBinding dice
*dove valgono*. Per questo `jenkins-deployer` poteva scrivere in `formazione-sou` e riceveva
Forbidden altrove.

Questo step usa invece la terza riga, perché "cluster-reader" significa lettura su tutto il cluster.

---

## La verifica

```bash
KUBECONFIG=reader-kubeconfig kubectl auth can-i get deployments -n formazione-sou    # yes
KUBECONFIG=reader-kubeconfig kubectl auth can-i get deployments -n kube-system       # yes
KUBECONFIG=reader-kubeconfig kubectl auth can-i delete deployments -n formazione-sou # no
KUBECONFIG=reader-kubeconfig kubectl auth can-i get secrets -n formazione-sou        # no
```

Le prime due insieme provano che il binding è davvero cluster-wide, le altre due provano il minimo
privilegio: sola lettura, e solo sui Deployment.

---

## Come funziona lo script

Fa due cose: esporta il Deployment in JSON con kubectl, e cerca con jq gli attributi che mancano. Si lancia così:
```bash
KUBECONFIG=reader-kubeconfig ./check_deployment.sh
```
L'identità non è scritta nel codice: `**kubectl**` legge da solo la variabile KUBECONFIG, quindi è chi lancia lo script a decidere con quali permessi girerà.

I controlli guardano **`.spec.template.spec.containers[]`**, cioè il modello di Pod che il Deployment usa per crearli, non i Pod in esecuzione. È lo stato desiderato: se il modello non dichiara i limiti, nessun Pod ne avrà mai, nemmeno quelli creati domani.

Il filtro **`jq`** ragiona al contrario: select() lascia passare il nome di un attributo solo se il suo valore è null, quindi l'elenco che ne esce contiene i mancanti. Se è vuoto, va tutto bene.

Lo script elenca tutti i problemi prima di uscire, invece di fermarsi al primo, ed esce con 1 se ne trova.
---

## Il ciclo completo

```
values.yaml  →  pipeline Jenkins (Step 4)  →  Deployment  →  script (Step 5)  →  0 oppure 1
```

Alla prima esecuzione lo script ha segnalato i quattro attributi di `resources` come mancanti, perché
il chart aveva `resources: {}`. era la dimostrazione che lo script
funziona.

La correzione è andata nel **`values.yaml` del chart** inserendo limits e requests e rilanciando la pipeline; a questo punto esce con **exit 0** e tutti gli attributi presenti.

---

## File

| File | Ruolo |
|---|---|
| `rbac/cluster-reader.yaml` | ClusterRole di sola lettura sui Deployment |
| `rbac/service-account.yaml` | ServiceAccount + ClusterRoleBinding |
| `rbac/token.yaml` | Secret con il token persistente |
| `check_deployment.sh` | Lo script di verifica |
| `reader-kubeconfig`, `reader-ca.crt` | Credenziali del reader (**non versionare**) |

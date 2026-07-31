# Esercizio: pipeline Jenkins con parametro ENVIRONMENT

Pipeline dichiarativa che accetta il parametro `ENVIRONMENT` e contiene due stage:
`DEVELOPMENT` e `PRODUCTION`. Viene eseguito soltanto lo stage corrispondente al valore
selezionato, che stampa a video il valore del parametro.

## Spiegazione

### Il blocco `parameters`

```groovy
parameters {
    choice(
        name: 'ENVIRONMENT',
        choices: ['development', 'production'],
        description: 'Ambiente di destinazione'
    )
}
```

Dichiara quali input il job accetta prima di avviarsi.

La sintassi `name: 'ENVIRONMENT'` sono argomenti con nome: Groovy li raccoglie in una mappa
e li passa a `choice`.

### La mappa `params`

`params` è una mappa che Jenkins popola con i valori dei parametri del run corrente, e
`params.ENVIRONMENT` ne legge uno.

### when

```groovy
when {
    expression { params.ENVIRONMENT == 'development' }
}
```

`when` decide se lo stage che la contiene debba essere eseguito. Si colloca dentro `stage`,
prima di `steps`.
Il blocco `when` stabilisce se lo stage deve essere eseguito.
L'espressione restituisce true soltanto quando l'utente ha selezionato `development`:

Se la condizione è **vera**, Jenkins esegue i passi dello stage e scrive nel log:

Ambiente selezionato: `development`

Se la condizione è **falsa**, Jenkins contrassegna lo stage come skipped e passa a quello successivo.

Il ruolo è analogo a
quello del blocco `script`, con una differenza: `script` esegue azioni, `expression` valuta
soltanto una condizione.

### `when` salta lo stage

NelL'output compaiono sempre entrambi gli stage, anche quando ne viene
eseguito uno solo. Quello escluso riporta:

```
Stage "DEVELOPMENT" skipped due to when conditional
```

Lo stage esiste in ogni esecuzione, e `when` decide unicamente se eseguirlo. In una pipeline
scripted, dove lo stesso risultato si otterrebbe con un `if/else`, lo stage non eseguito non
comparirebbe affatto, perché la chiamata che lo crea non verrebbe mai raggiunta.

### Primo lancio

Al primo avvio il pulsante disponibile è **Build Now** e non **Build with Parameters**.
Jenkins registra i parametri di un job solo dopo aver eseguito
il Jenkinsfile almeno una volta. Il primo run utilizza quindi il valore di default, ovvero
il primo elemento di `choices`.

### Lanci successivi

Dal secondo avvio compare **Build with Parameters** con il menu a tendina.

# Esercizio: pipeline Jenkins giorno della settimana

Pipeline dichiarativa che esegue la build solo nei giorni feriali e stampa un messaggio di
warning il sabato e la domenica.

La richiesta dell'esercizio è che il giorno della settimana non venga ricavato da un
comando shell, ma dall'oggetto **Date** messo a disposizione da Groovy.

## Spiegazione

### Uso del blocco script

```groovy
script {
    // codice Groovy
}
```

Una pipeline dichiarativa usa il blocco script quando deve eseguire logica Groovy più articolata, come la dichiarazione di variabili e il costrutto condizionale if/else.

```groovy
def giorno = new Date()[Calendar.DAY_OF_WEEK]
```

`new Date()` crea un oggetto che rappresenta la data e l'ora correnti.

`Calendar.DAY_OF_WEEK` richiede il giorno della settimana. Il valore restituito è un intero da 1 a 7 che viene salvato nella variabile **giorno**.

### Costanti

```groovy
if (giorno >= Calendar.MONDAY && giorno <= Calendar.FRIDAY)
```
Con Calendar i giorni vengono numerati in questo caso da 1 a 7 partendo da Domenica.

Scrivere `giorno >= 1 && giorno <= 5` per intendere "lunedì-venerdì" selezionerebbe in
realtà domenica-giovedì.

`Calendar.MONDAY` vale 2 e `Calendar.FRIDAY` vale 6:
senza doverlo ricordare, e la condizione si legge come una frase.

```groovy
echo "Giorno feriale (${giorno}): eseguo la build"
sh 'echo "build simulata"'
````

`echo` è uno step di Jenkins, non un comando Groovy: scrive nel Console Output del run.

`sh` esegue un comando nella shell dell'agent.

## Test del ramo weekend

Per verificare il comportamento del sabato e della domenica senza attendere il fine settimana
basta modificare il replay dalla schermata della build esguita.

È sufficiente sostituire il calcolo con un valore fisso:

```groovy
def giorno = Calendar.SATURDAY
```

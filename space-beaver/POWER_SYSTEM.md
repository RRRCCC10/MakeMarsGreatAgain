# Sistema elettrico

## Flusso della rete

La rete seleziona automaticamente uno dei due flussi:

- con almeno una batteria collegata: `Pannelli -> Trasformatore -> Batterie -> Consumatori`;
- senza batterie collegate: `Pannelli -> Trasformatore -> Consumatori`.

Il percorso e' diviso in tre reti indipendenti: corrente grezza dai pannelli,
corrente trasformata diretta alle batterie e corrente in uscita dalle batterie.
I cavi di due reti diverse non possono condividere una cella o creare una
giunzione, anche quando passano vicino allo stesso macchinario.

- Ogni pannello produce fino a 100 kW: rampa 0–100% tra le 06:00 e le 07:00,
  piena potenza fino alle 17:00 e rampa 100–0% entro le 18:00.
- Tra le 18:00 e le 06:00 la produzione solare e' sempre 0 kW.
- Ogni batteria contiene fino a 500 kWh.
- Ogni batteria conserva una carica indipendente; una batteria disconnessa non
  si carica e non si scarica.
- In modalita' diretta i consumatori funzionano soltanto quando la produzione
  solare istantanea copre tutta la richiesta; non esiste energia notturna.
- Se la produzione supera la richiesta, l'eccesso carica le batterie.
- Se la produzione non basta, la rete usa automaticamente le batterie.
- Se produzione e batterie non coprono la richiesta, l'intera rete entra in blackout.
- Un pannello richiede due celle per il proprio sprite e una terza cella libera a destra per l'uscita del cavo.

## Sprite dei dispositivi

- Il trasformatore usa 4 frame completi da 32x32 disposti in una griglia 2x2.
- La batteria usa frame da 16x16: le 5 righe rappresentano i livelli di carica e ciascuna riga contiene 4 frame di animazione.
- La riga della batteria viene scelta dalla carica reale; l'animazione scorre soltanto i 4 frame di quella riga.

## Ciclo giorno/notte

- Una giornata completa dura 8 minuti reali: 12 ore diurne e 12 notturne.
- Le fasi mostrate dalla UI sono `ALBA` 05:00–06:00, `GIORNO` 06:00–17:00,
  `TRAMONTO` 17:00–18:00 e `NOTTE` 18:00–05:00.
- Il colore del mondo viene trasformato senza texture alternative; UI e pixel art
  mantengono il filtro nearest.
- Batteria e trasformatore usano LED e aloni locali coerenti con alimentazione,
  carica/scarica e ora del giorno.
- L'orologio mondiale e' separato dalla rete elettrica, cosi' luce ed energia
  restano sincronizzate anche cambiando la velocita' temporale.

## Cavi automatici

La rete usa una griglia da 16x16 pixel e un percorso A* ortogonale. I cavi:

- sono gratuiti e vengono creati o rimossi automaticamente;
- riutilizzano i tratti esistenti e generano curve, incroci e raccordi a T;
- evitano rocce e dispositivi/edifici;
- possono passare sotto i tubi;
- vengono ricostruiti dopo piazzamento, recupero o raccolta di una roccia.

## Negozio e costruzione

- `B`: apre o chiude l'emporio.
- Pannello solare: 500 milioni.
- Trasformatore: 1 miliardo; ne può esistere soltanto uno tra inventario e mondo.
- Batteria: 750 milioni.
- Dall'inventario (`Tab`) si clicca un dispositivo per equipaggiarlo nello slot rapido 2.
- Click sinistro: piazza il dispositivo sulla griglia.
- Click destro su un dispositivo piazzato: lo recupera nell'inventario senza rimborso.

## Collegare nuovi edifici

Un edificio consumatore può registrarsi con:

```gdscript
PowerGrid.register_consumer(self, cella_connessione, richiesta_kw, direzione_attacco)
```

e implementare:

```gdscript
func set_powered(value: bool) -> void:
    # Avvia o ferma produzione e animazioni del macchinario.
```

Quando viene rimosso deve chiamare `PowerGrid.unregister_consumer(self)`. Se
esiste almeno una batteria collegata, la rete instrada il consumatore dalla
batteria raggiungibile piu' vicina. Altrimenti lo collega direttamente
all'uscita del trasformatore e applica automaticamente lo stato di
alimentazione o blackout.

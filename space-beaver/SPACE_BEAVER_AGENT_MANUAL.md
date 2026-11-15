# SPACE BEAVER — Manuale unico per agente e Game Design

> Documento autosufficiente per un altro agente di ChatGPT/Codex che debba comprendere, modificare, verificare e mantenere il progetto.
> Il documento distingue le regole di gioco già implementate dalle intenzioni di design: quando c'è una differenza, il codice e i test sono la fonte di verità operativa.

## 0. Missione dell'agente

Il compito dell'agente è mantenere ed estendere *Space Beaver*, un gioco 2D pixel-art di sopravvivenza, costruzione logistica e ricerca scientifica su Marte.

Ogni modifica deve conservare quattro proprietà:

1. il giocatore deve capire perché un sistema funziona o non funziona;
2. la grafica, la collisione e la logica devono descrivere lo stesso spazio fisico;
3. acqua, ossigeno, elettricità e risorse devono fluire attraverso reti reali, non attraverso valori duplicati solo nella UI;
4. ogni nuova interazione deve essere verificata con un test automatico e, quando riguarda il layout o l'ordine di rendering, con un controllo visivo nel gioco.

L'agente non deve limitarsi a “far sparire l'errore”: deve individuare la causa, correggere il flusso, aggiungere una regressione e controllare che i sistemi già funzionanti non cambino comportamento.

## 1. Come leggere il progetto prima di modificarlo

Ordine consigliato:

1. leggi questo file;
2. leggi project.godot per conoscere scena principale e autoload;
3. leggi Scenes/main.tscn per capire quali nodi UI e sistemi esistono nella scena;
4. cerca il sistema interessato con rg prima di aprire molti file;
5. leggi il manager/autoload che possiede lo stato, poi la struttura e infine la UI;
6. cerca i test già esistenti per quella caratteristica;
7. implementa la modifica nel punto che possiede realmente la regola, non in un pannello grafico che la imita;
8. esegui il test specifico, il test di regressione e una scansione editor headless.

Comandi di esplorazione utili:

~~~powershell
rg --files
rg -n "nome_funzione|nome_segnale|nome_item" scripts Scenes tests
Get-Content scripts\NomeSistema.gd -Raw
Get-Content tests\nome_test.gd -Raw
~~~

Non usare grep se rg è disponibile. Non usare script Python o redirezioni shell per scrivere file: le modifiche al codice e alla documentazione vanno fatte con apply_patch.

## 2. Percorso e avvio del progetto

Repository corrente:

~~~text
C:\Users\riccardo\Documents\GitHub\TheMartian\space-beaver
~~~

Scena principale:

~~~text
Scenes/main.tscn
~~~

Eseguibile Godot usato nei test locali:

~~~text
C:\Users\riccardo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
~~~

Comandi di verifica:

~~~powershell
& "C:\Users\riccardo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\Users\riccardo\Documents\GitHub\TheMartian\space-beaver" --script "C:\Users\riccardo\Documents\GitHub\TheMartian\space-beaver\tests\power_network_page_smoke.gd"

& "C:\Users\riccardo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --path "C:\Users\riccardo\Documents\GitHub\TheMartian\space-beaver" --quit
~~~

Un test riuscito deve stampare il proprio marker *_OK e terminare con codice 0. La scansione editor deve terminare senza errori di parser o script non risolti.

## 3. Architettura reale

Il progetto usa Godot 4 e separa lo stato globale dagli oggetti della mappa.

### 3.1 Autoload

| Autoload | Responsabilità |
|---|---|
| UIState | Un solo modal globale alla volta; blocca il mondo mentre una GUI è aperta, con eccezione della minimappa. |
| GridManager | Griglia di costruzione semplice e oggetti piazzabili. |
| Inventory | Hotbar, zaino, stack, strumenti, tute, borraccia, rocce, rover e camera. |
| Oxygen | Ossigeno della tuta e rigenerazione in ambienti respirabili. |
| SuitSystem | Tute possedute, equipaggiate, protezione e capacità. |
| Hunger / Hydration | Fame, sete, consumo nel tempo e uso della razione/borraccia. |
| Economy | Budget NASA, spesa, ricompense e reset missione. |
| BuildableRegistry | Registro di strutture vive, ispezione, ricerca per posizione e demolizione. |
| WorldClock | Ora marziana, avanzamento e fattore solare. |
| Radiation / Temperature | Danno ambientale, dose, freddo, protezioni e soglie di morte. |
| PipeManager | Categorie, sorgenti, ingressi, collegamenti e flussi di acqua/H2/O2. |
| PowerGrid | Pannelli, trasformatore, batterie, consumatori, percorsi dei cavi, potenza e blackout. |
| DeliveryManager | Ordini aggregati e capsule di consegna. |
| Shop | Catalogo e configurazione degli acquisti. |
| GameState | Fallimento e riavvio completo della missione. |
| RoverInteraction | Stato globale del rover e interazioni da vicino. |
| AchievementManager | Definizioni, prerequisiti, progresso, riscatti, premi e bonus. |
| FieldCamera | Foto, rullino, archivio e trasmissione alla Terra. |

### 3.2 Scena principale e nodi runtime

Scenes/main.tscn istanzia:

- player;
- Map, RockFields, RockScatter;
- DayNightEnvironment;
- InventoryUI, SurvivalUI, PowerUI, ShopUI, DeliveryUI, DeathUI;
- RadiationUI, TemperatureUI, WorldMapUI;
- AchievementBoard, AchievementSuccessUI;
- LandingSequence.

Gli edifici e i macchinari non sono scene statiche obbligatorie: vengono creati dagli script, registrati nei manager e aggiunti al nodo della scena corrente.

### 3.3 Mappa dei file principali

| File | Regola da conoscere |
|---|---|
| Scenes/node.gd | Controller di gioco/build mode: anteprime, click di piazzamento, rotazione, demolizione, macchinario vicino e guida contestuale. |
| scripts/player.gd | Movimento, collisione, input contestuale e blocco quando UIState indica una GUI modale. |
| scripts/PowerGrid.gd | Fonte di verità dell'elettricità; non duplicare la logica nella UI. |
| scripts/power_ui.gd | Pagina modale del Centro di distribuzione, aperta con L; lista e toggle per ogni elemento elettrico. |
| scripts/PipeManager.gd | Fonte di verità dei tubi e dei flussi di fluidi. |
| scripts/pipe.gd, scripts/CableSegment.gd | Visualizzazione e orientamento dei segmenti di rete. |
| scripts/BaseDome.gd | Cupole abitative, aria, temperatura, airlock, collisioni, configurazioni e base rover. |
| scripts/Greenhouse.gd | Serra, airlock, aiuole, patate, acqua, ossigeno vegetale, luce e alimentazione volontaria. |
| scripts/PowerDevice.gd | Pannello, trasformatore, batteria e trivella di ghiaccio. |
| scripts/ProcessMachine.gd | Elettrolizzatore e Sabatier, ingressi/uscite fluidi e produzione continua. |
| scripts/RockDrill.gd | Trivella mineraria, riserva di campioni, rarità per bioma e raccolta. |
| scripts/ResearchMachine.gd | XRD, Raman e ICP-MS, analisi, animazione, upgrade, rapporti e ricompense. |
| scripts/Rover.gd / scripts/RoverInteraction.gd | Rover, salita/discesa, pannelli solari, batteria e richiamo al dock. |
| scripts/Shop.gd / scripts/shop_ui.gd | Catalogo, sezioni, configurazione cupole e ordine unico. |
| scripts/Inventory.gd / scripts/inventory_ui.gd | Movimento degli oggetti tra hotbar e zaino, icone, strumenti e modali. |
| scripts/achievement_graph_board_v2.gd | Tavola a grafo ramificato; nasconde le altre GUI quando è aperta. |
| scripts/AchievementManager.gd | Tutta la progressione economica e scientifica. |
| scripts/achievement_success_ui.gd | Schermata/notifica quando un obiettivo raggiunge il target. |
| scripts/WorldMapUI.gd | Mappa, zoom e pan con rotella premuta; minimappa non modale. |
| scripts/GameState.gd | Reset totale della missione. |

## 4. Regola globale delle GUI

UIState possiede un solo active_modal.

- Shop, inventario, tavola achievement, archivio foto, scheda tecnica, camera di decompressione, riserva trivella e pagina elettrica non possono rimanere aperti insieme.
- Quando un modal è aperto, il giocatore non può muoversi, costruire, raccogliere, usare E/F, ruotare, collegare reti, aprire altre GUI, riscattare obiettivi o cambiare zoom.
- Esc chiude qualsiasi modal.
- Il tasto di apertura dello stesso pannello lo richiude.
- La minimappa è l'unica eccezione: mentre è aperta consente il movimento e il pan, ma blocca tutte le altre azioni di gioco.
- Prima di aprire una UI usare try_open_modal(id); alla chiusura usare close_modal(id).
- Non testare l'interfaccia solo rendendo invisibile un Control: lo stato modale deve essere aggiornato.

Pattern compatibile con test standalone:

~~~gdscript
var ui_state := get_node_or_null("/root/UIState")
if ui_state != null and not bool(ui_state.call("try_open_modal", &"nome_modal")):
    return
~~~

Evitare di riferirsi direttamente a un autoload nuovo in uno script che viene pre-caricato dai test: in Godot può fallire il type resolution in un contesto standalone. Usare lookup dinamico quando il test carica script isolati.

## 5. Centro di distribuzione elettrica

La modifica più recente ha sostituito il vecchio HUD elettrico sempre visibile con una pagina operativa.

### Apertura

- L: apre/chiude PowerNetworkRoot;
- Esc: chiude la pagina;
- la pagina si registra come modal power_network;
- il mondo è bloccato mentre la pagina è aperta;
- non si apre sopra shop, inventario, tavola achievement o altri modal.

### Contenuto

La pagina contiene:

1. intestazione CENTRO DI DISTRIBUZIONE ELETTRICA;
2. istruzione che spiega che un elemento disconnesso non produce e non assorbe;
3. stato rete e ora marziana;
4. pannelli collegati, batterie collegate e stato generale;
5. metriche di produzione, richiesta, riserva, luce solare e autonomia;
6. elenco scorrevole raggruppato in GENERAZIONE, CONVERSIONE, ACCUMULO, CONSUMO;
7. per ogni elemento: nome, dettaglio, stato del cavo, flusso/potenza e pulsante;
8. legenda colori.

PowerGrid.get_network_devices() costruisce il modello che la UI visualizza. Per ogni elemento conserva il riferimento al nodo reale, così il pulsante non modifica una copia grafica.

Stati visualizzati:

- OPERATIVO: abilitato, collegato e alimentato;
- COLLEGATO · IN ATTESA: abilitato e collegato, ma senza potenza utile in quel momento;
- CAVO NON COLLEGATO: l'elemento è abilitato ma il percorso non raggiunge il raccordo;
- IN ATTESA DI LUCE: pannello abilitato durante la notte;
- DISCONNESSO: elemento disabilitato manualmente.

PowerGrid.set_device_network_enabled(device, enabled) è il punto unico del comando. Il dispositivo riceve set_network_enabled, la rete viene ricostruita e la pagina si aggiorna.

Questa distinzione è importante: [ COLLEGA ] abilita l'elemento, ma non crea magicamente un cavo mancante. Se la geometria della rete non raggiunge il raccordo, la riga deve mostrare CAVO NON COLLEGATO.

## 6. Flussi tecnici da preservare

### Elettricità

~~~text
pannelli → trasformatore → batterie/consumatori
~~~

La topologia viene ricostruita da PowerGrid; produzione, domanda, carica, scarica, blackout e sprite accesi derivano da quel modello.

### Fluidi

~~~text
trivella acqua → tubo acqua → elettrolizzatore/serra
elettrolizzatore → tubo H₂ / tubo O₂
tubo H₂ → Sabatier
tubo O₂ → cupola
~~~

Un’uscita non collegata non deve accumulare materiale se la macchina è a produzione continua. Un raccordo valido dipende da categoria, cella e apertura del tubo.

### Cupola

~~~text
acquisto/configurazione → consegna → piazzamento
→ corridoio e due porte → pressurizzazione → atmosfera
→ tubo O₂ + eventuale elettricità → autonomia e temperatura
~~~

La camera non parte prima che la prima porta sia stata aperta. La grafica del pavimento non deve coprire il personaggio; l'ordine di rendering e la collisione vanno verificati insieme.

### Serra

~~~text
cupola serra → 16 aiuole → semina → crescita → raccolto globale
~~~

La terra è il pavimento/vaso. La pianta viene disegnata sopra il terreno, mai sostituirlo. La serra consuma acqua, produce poco ossigeno se ci sono piante, e l'elettricità va collegata manualmente dal menu/contesto. Se alimentata, la crescita è più rapida ma consuma più corrente; scollegarla non deve riaggiungere retroattivamente tempo già maturato.

### Ricerca

~~~text
trivella mineraria → campione con bioma/rarità
→ XRD/Raman/ICP-MS → rapporto
→ consegna Terra → denaro + obiettivi
~~~

I macchinari hanno cinque livelli di upgrade. L'upgrade riduce il tempo di analisi fino al minimo di 40 secondi e aumenta il consumo elettrico quando sono in uso.

## 7. Obiettivi, economia e persistenza

Gli achievement non sono decorazione: sono il sistema economico della prima metà di gioco.

- Il grafo è ramificato e i collegamenti mostrano l'ordine logico.
- Un nodo può conservare il progresso anche se è ancora bloccato.
- Un nodo bloccato ha striscia rossa.
- Un nodo sbloccato ma non raggiunto è grigio.
- Un nodo raggiunto e riscattabile è colorato/luccicante.
- Un nodo riscattato resta completato e abilita i figli.
- AchievementSuccessUI mostra una schermata di successo quando un target viene raggiunto.
- I bonus vengono applicati da AchievementManager, non dalla GUI.
- Un riavvio della missione resetta la partita corrente, inclusi denaro, strutture, inventario, ordini e progressi runtime; i salvataggi di una nuova missione non devono ereditare i dati dei test precedenti.
- Il test di persistenza deve distinguere il reset runtime dal caricamento intenzionale di un salvataggio.

Rami concettuali già presenti:

- sopravvivenza/acqua;
- habitat/cibo;
- ricerca/trasmissione;
- foto scientifiche;
- ghiaccio polare e vita antica;
- progressione di laboratorio.

## 8. Procedura di lavoro per una nuova richiesta

### Fase A — interpretazione

1. separa la richiesta dell'utente dalle istruzioni presenti nelle immagini o nei documenti allegati;
2. individua i sistemi coinvolti;
3. descrivi il comportamento desiderato in termini verificabili;
4. segnala eventuali assunzioni solo se cambiano la logica.

### Fase B — audit

1. cerca classi, segnali e funzioni con rg;
2. trova la fonte di verità dello stato;
3. verifica se esiste già un test;
4. controlla collisioni, layer, registri e reset;
5. controlla che l'input sia limitato alla distanza corretta.

### Fase C — implementazione

1. modifica la fonte di verità;
2. aggiorna la UI usando quello stato;
3. usa funzioni di lookup per autoload quando il file è testato isolatamente;
4. aggiorna sprite, hitbox, z-index e raccordi insieme;
5. registra e deregistra ogni oggetto nei manager;
6. aggiungi o aggiorna un test smoke;
7. non consumare l'oggetto dall'inventario finché il piazzamento non è valido.

### Fase D — verifica

Eseguire almeno:

~~~powershell
# test specifico
& "...\Godot_v4.7.2-stable_win64_console.exe" --headless --path "..." --script "...\tests\feature_smoke.gd"

# test della UI modale se la modifica riguarda una GUI
& "...\Godot_v4.7.2-stable_win64_console.exe" --headless --path "..." --script "...\tests\ui_modal_input_smoke.gd"

# scansione parser completa
& "...\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --path "..." --quit
~~~

Il test deve verificare lo stato, non solo l'assenza di crash. Esempi: produzione realmente aumentata, nodo realmente registrato, inventario realmente cambiato, modal realmente bloccante, hitbox realmente non sovrapposta.

## 9. Diagnosi dei problemi tipici

| Sintomo | Controlli da fare |
|---|---|
| Lo sprite è invisibile ma la hitbox esiste | z_index, visible, texture/frame, Sprite2D figlio, _refresh_visuals, layer interni/esterni. |
| Un tubo sembra collegato ma lo stato dice scollegato | cella del raccordo, direzione richiesta, categoria del tubo, PipeManager e posizione reale. |
| Una macchina accumula output scollegato | controllare che il flusso sia emesso solo se is_source_connected/consumer valido; rimuovere stock fittizi. |
| La serra torna indietro quando si scollega la corrente | salvare il tempo maturato; il bonus deve valere solo sul delta futuro, mai ricalcolare il timer base da zero. |
| E o F funziona da lontano | il gestore input deve controllare distanza, nodo vicino e stato di UIState; aggiungere regressione specifica. |
| Il giocatore è sotto un corridoio o un pavimento | verificare z_index, ordine dei figli, collisione statica e posizione del personaggio. |
| Un edificio si piazza sopra una roccia o il player | includere tutte le celle occupate in can_place_*; controllare BuildableRegistry, GridManager e fisica. |
| Una GUI si apre sopra un'altra | chiamare UIState.try_open_modal; non usare solo visible=false. |
| I progressi del test restano dopo F5 | controllare _reset_session_state, reset_for_new_mission e la modalità persistenza di AchievementManager. |
| Preload Could not resolve script | verificare path/case del file, errori parser nelle righe indicate e dipendenze autoload; eseguire scansione editor. |
| add_child() fallisce perché il parent è busy | usare call_deferred("add_child", child) nel punto in cui il nodo viene creato durante una modifica dell'albero. |

## 10. Checklist di accettazione

Una funzionalità è completa solo se:

- sprite visibile in anteprima e nel mondo;
- hitbox proporzionata e testata;
- layer coerente con terreno, player, corridoio e interno;
- piazzamento impossibile sopra player, roccia o struttura;
- rotazione coerente con sprite, impronta, porta e raccordi;
- input limitato alla distanza;
- GUI modale integrata con UIState;
- stato prodotto dal manager, non inventato dalla UI;
- collegamenti elettrici/fluidi registrati e rimossi correttamente;
- demolizione e raccolta aggiornano inventario e reti;
- reset missione deterministico;
- test smoke con marker *_OK;
- scansione editor senza errori;
- layout adattivo a risoluzioni diverse;
- spiegazione leggibile quando il sistema non può funzionare.

## 11. Modello mentale finale per l'agente

Prima di cambiare il codice chiediti:

- Quale manager possiede questa informazione?
- Quale nodo fisico rappresenta davvero il dispositivo?
- Quale raccordo/cella/direzione viene usato per collegarlo?
- Cosa succede se il cavo o il tubo non è connesso?
- Cosa succede se l'utente apre una GUI durante l'azione?
- Cosa succede quando l'oggetto viene demolito, raccolto o quando la missione viene riavviata?
- Quale test dimostra che non è solo una modifica grafica?

Se la risposta non è chiara, non aggiungere una scorciatoia nella UI: risali alla fonte di verità e correggi il flusso lì.

---

## 12. Registro delle funzionalità già implementate

Questa è la fotografia operativa dello stato raggiunto durante il lavoro sul progetto. Prima di modificare una di queste aree, l'agente deve cercare le relative funzioni e test invece di ricreare il sistema da zero.

### Interfaccia e input

- Le GUI modali sono coordinate da `UIState`: shop, inventario, achievement, archivio foto, schede tecniche, depositi, airlock e rete elettrica si escludono a vicenda.
- `Esc` chiude il modal corrente; lo stesso tasto che lo apre lo può richiudere.
- La minimappa resta l'unica UI non modale: permette movimento, zoom e pan con rotella premuta, ma impedisce le altre azioni.
- La tavola achievement nasconde le altre `CanvasLayer` mentre è aperta e le ripristina alla chiusura.
- Gli input contestuali `E`, `F`, `V`, `R`, `U`, `P`, `O`, `C`, `L` controllano sempre distanza e stato prima di eseguire l'azione.

### Infrastruttura e bug di piazzamento

- Cupole, serra, corridoi, porte, basi rover, tubi, pannelli e macchinari hanno anteprima, impronta e collisione coerenti.
- Il piazzamento rifiuta sovrapposizioni a giocatore, rocce, edifici e celle già occupate.
- Il sistema conserva rotazione di sprite, hitbox, raccordi e orientamento dei corridoi.
- La demolizione aggiorna registro, inventario, cavi, tubi, sorgenti e consumatori.
- Gli oggetti possono essere trasferiti tra hotbar e zaino; le strutture possono essere recuperate senza lasciare registrazioni fantasma.

### Elettricità

- Il vecchio pannello elettrico permanente è stato sostituito dalla pagina `PowerUI`, aperta con `L`.
- `PowerGrid.get_network_devices()` espone una riga per ogni pannello, trasformatore, batteria e consumatore registrato.
- Ogni riga mostra collegamento, flusso, potenza e stato; il pulsante collega o scollega solo quel nodo.
- Scollegare un dispositivo disabilita produzione/consumo, ricostruisce la rete e aggiorna subito cavi e metriche.
- L'abilitazione manuale non finge un cavo: se il percorso fisico non raggiunge il raccordo, lo stato resta `CAVO NON COLLEGATO`.
- Cupole e serra espongono `set_network_enabled`, `is_network_enabled` e `get_display_name` per essere controllate dalla pagina.

### Fluidi e supporto vitale

- Tubi acqua, idrogeno e ossigeno rispettano categoria, cella di raccordo e apertura richiesta.
- L'elettrolizzatore produce H₂/O₂ come flusso continuo e non come cisterna nascosta.
- Il Sabatier riceve idrogeno e alimenta direttamente il razzo con metano.
- Le cupole consumano ossigeno, perdono atmosfera nel tempo e mostrano riserva/autonomia tramite il raccordo O₂.
- La serra verifica acqua e alimentazione separatamente; la corrente è opzionale e manuale.

### Cupole, airlock e serra

- Le cupole hanno corridoio separato dal corpo, porta esterna e porta interna.
- La decompressione/pressurizzazione non può iniziare finché la prima porta corretta non è stata aperta.
- La serra riusa il modello di airlock della cupola abitativa, senza duplicare un secondo flusso di porte.
- La terra resta il pavimento; i cinque/quattro frame di crescita della patata sono sprite sopra le aiuole.
- La crescita salva il tempo maturato: scollegare la corrente non cancella il progresso né riapplica retroattivamente il bonus.
- Le piante contribuiscono all'ossigeno interno; la serra non ha ossigeno infinito.

### Rover

- La base rover ha sprite, hitbox, posizione di parcheggio e stato di alimentazione reali.
- Il rover è visibile nel mondo, si raggiunge da vicino e si sale/scende con `E`.
- `F` apre i pannelli solari solo a distanza valida e non può attivarsi da lontano o mentre una GUI modale è aperta.
- Il rover acquistato dalla base può essere richiamato al dock con un costo separato; il richiamo aggiorna la posizione fisica e la batteria.

### Ricerca, foto e progressione

- XRD, Raman e ICP-MS sono posizionabili nelle cupole, hanno sprite spento/in uso/finito, analizzano campioni e generano rapporti vendibili.
- Ogni laboratorio può essere potenziato cinque volte; il tempo minimo previsto è 40 secondi e l'uso assorbe corrente.
- La trivella mineraria seleziona campioni in base al bioma e alla rarità, con inventario interno trasferibile o scartabile.
- Il ghiaccio profondo primordiale è raro ovunque e più probabile ai poli; lo studio può sbloccare il ramo della vita antica.
- L'obiettivo Sacca campioni concede anche la telecamera; `P` scatta, `O` trasmette, `C` apre l'archivio.
- Gli achievement sono un grafo ramificato di economia, ricerca, esplorazione, sopravvivenza, foto e vita antica; raggiungimento e riscatto sono stati separati.

### Test di regressione da usare come mappa

| Area | Test consigliato |
|---|---|
| Pagina elettrica e blocco modale | `tests/power_network_page_smoke.gd`, `tests/ui_modal_input_smoke.gd` |
| Cupola e airlock | `tests/base_dome_smoke.gd` |
| Serra, acqua, crescita e luce | `tests/greenhouse_smoke.gd`, `tests/greenhouse_visual_smoke.gd` |
| Reti elettriche e batterie | `tests/day_night_power_smoke.gd`, `tests/direct_transformer_smoke.gd`, `tests/independent_batteries_smoke.gd` |
| Tubi e macchine a fluidi | `tests/process_machine_fluid_smoke.gd`, `tests/cable_pathfinding_smoke.gd` |
| Rover | `tests/rover_smoke.gd`, `tests/rover_dock_input_smoke.gd`, `tests/rover_panel_input_smoke.gd` |
| Ricerca e trivella | `tests/research_machine_smoke.gd`, `tests/rock_drill_smoke.gd`, `tests/resource_rocks_smoke.gd` |
| Achievement e reset | `tests/achievement_smoke.gd`, `tests/achievement_board_smoke.gd`, `tests/restart_from_zero_smoke.gd` |
| Layout responsive e mappa | `tests/responsive_ui_smoke.gd`, `tests/streaming_map_markers_smoke.gd` |

## 13. Specifica completa del gioco

# SPACE BEAVER

## Game Design Document

**Genere:** survival, costruzione di basi e gestione logistica in pixel art 2D.  
**Ambientazione:** una missione umana su Marte.  
**Stato del documento:** riferimento di design della versione giocabile corrente. Descrive sia l'intenzione di gioco sia le regole già implementate; dove il bilanciamento potrà cambiare, i valori qui riportati sono quelli attuali.

---

## 1. Visione

*Space Beaver* è un gioco in cui il giocatore non “conquista” Marte con un singolo edificio: costruisce lentamente una catena di sopravvivenza. Ogni passo dipende da quello precedente.

Il protagonista è un astronauta solo, atterrato in un mondo ostile. Deve esplorare, raccogliere campioni, produrre acqua e ossigeno, generare elettricità, creare un riparo pressurizzato, coltivare cibo e finanziare la missione con la ricerca scientifica inviata alla Terra.

L'idea centrale è che gli impianti siano leggibili come sistemi fisici: l'acqua passa nei tubi, l'ossigeno viene prodotto e fornito, l'energia ha limiti di produzione e accumulo, una cupola può esaurire la sua atmosfera e una serra smette di crescere se non riceve acqua. Le strutture non sono soltanto decorazioni o menu: definiscono le possibilità del giocatore.

### Pilastri di design

1. **Sopravvivenza comprensibile.** Ossigeno, sete, fame, freddo e radiazioni sono sempre visibili e hanno cause chiare.
2. **Logistica visiva.** Tubi, cavi, porte, raccordi e macchinari mostrano come funziona la base.
3. **Progressione a catena.** Acqua → elettricità → supporto vitale → habitat → cibo → ricerca → finanziamenti.
4. **Esplorazione con rischio.** I biomi remoti offrono campioni interessanti, ma sono più freddi e richiedono tute, rover e pianificazione.
5. **Pixel art funzionale.** Gli sprite sono al servizio della leggibilità: stati accesi/spenti, animazioni di lavoro, porte, luce notturna, crescita delle piante e indicatori di rete.

---

## 2. Fantasia del giocatore e obiettivo della missione

Il giocatore vive la fantasia di essere il primo tecnico-scienziato incaricato di rendere abitabile una piccola porzione di Marte.

Non esiste una scorciatoia sicura: per analizzare un campione serve un laboratorio, per far funzionare il laboratorio serve elettricità, per esplorare a lungo servono aria, acqua, cibo, una cupola e infine un rover. I rapporti scientifici trasformano l'esplorazione in nuovi fondi, con cui la base può crescere.

La condizione di fallimento è la morte dell'astronauta. La missione termina se uno dei sistemi vitali raggiunge la soglia critica:

- ossigeno della tuta esaurito;
- idratazione esaurita;
- fame esaurita;
- dose acuta di radiazioni letale;
- ipotermia letale.

Il riavvio di una missione è una nuova partita: scorte, economia, strutture, ordini, progressi e obiettivi ripartono da zero.

---

## 3. Loop di gioco

```text
Esplora e raccogli rocce
          ↓
Costruisci rete, acqua e impianti
          ↓
Mantieni vivo l'astronauta e la cupola
          ↓
Coltiva cibo e amplia l'autonomia
          ↓
Analizza campioni nei laboratori
          ↓
Invia rapporti alla Terra e ricevi fondi
          ↓
Acquista infrastrutture e attrezzatura migliore
          ↺
```

Un ciclo pratico tipico è:

1. Il giocatore esplora la zona sicura e raccoglie pietre.
2. Compra tramite lo shop un impianto o una tuta; l'ordine arriva in una capsula vicino all'astronauta.
3. Collega il nuovo impianto alla rete elettrica e, se serve, alle reti di fluidi.
4. Crea una cupola con aria, temperatura e accesso tramite camera di decompressione.
5. Installa una serra e avvia una produzione di patate.
6. Porta un campione a un macchinario scientifico; al completamento invia il rapporto alla Terra.
7. Investe il denaro ricevuto in nuovi moduli, protezioni, rover e capacità di ricerca.

---

## 4. Mondo, mappa ed esplorazione

### Mappa

Il mondo è una mappa marziana estesa, suddivisa in tile da **16×16 pixel** e gestita a chunk per mantenere leggibile e fluida l'esplorazione. Il giocatore non può uscire dai confini del mondo. Rocce, edifici e strutture hanno collisioni e non devono poter essere sovrapposti durante il piazzamento.

La carta topografica mostra soltanto ciò che è stato esplorato. Visualizza terreno, posizione del giocatore, capsule di consegna e marcatori delle strutture.

### Biomi e temperatura esterna

Ogni bioma modifica la temperatura superficiale, interpolata tra notte e giorno.

| Bioma | Giorno | Notte |
|---|---:|---:|
| Pianura di atterraggio | −20 °C | −73 °C |
| Regolite scura | −17 °C | −68 °C |
| Cratere roccioso | −35 °C | −88 °C |
| Bordo della calotta | −52 °C | −98 °C |
| Ghiaccio polare | −65 °C | −115 °C |
| Altopiano basaltico | −30 °C | −82 °C |

Più un bioma è ostile, più la scelta di tuta, riparo, scorte e rover diventa importante.

### Rocce e campioni

Le rocce sono ostacoli fisici e raccolti con `E` da vicino. Entrano nell'inventario come campioni; i laboratori consumano un campione per analisi.

| Formazione | Campione comune | Campione raro |
|---|---|---|
| Pianura di Ares | Regolite rossa | Pietra ferrica |
| Nucleo polare | Ghiaccio polveroso | Ghiaccio blu compatto |
| Crateri d'impatto | Pietra da cratere | Vetro d'impatto |
| Formazione basaltica | Roccia basaltica | Basalto nero |
| Bordo della calotta | Roccia criogenica | Ghiaccio profondo |

---

## 5. Tempo, luce e ciclo solare

Una giornata marziana di gioco dura **8 minuti reali**. L'orologio mondiale è indipendente dalla rete elettrica, così la luce e la produzione solare restano coerenti.

| Fase | Ora di gioco | Effetto |
|---|---|---|
| Alba | 05:00–06:00 | La luce aumenta; la produzione solare non è ancora piena. |
| Giorno | 06:00–17:00 | La produzione solare cresce al mattino e poi resta al massimo. |
| Tramonto | 17:00–18:00 | La produzione solare scende progressivamente. |
| Notte | 18:00–05:00 | I pannelli producono 0 kW; diventano necessari batterie, riparo e luce artificiale. |

La potenza solare raggiunge il 100% fra le 07:00 e le 17:00, sale da 0% a 100% fra le 06:00 e le 07:00 e scende da 100% a 0% fra le 17:00 e le 18:00.

---

## 6. Sopravvivenza dell'astronauta

La UI di sopravvivenza mostra costantemente i parametri critici. La pressione serve a rendere l'espansione della base una necessità, non solo un obiettivo estetico.

### Ossigeno personale

- La tuta standard contiene **100 unità di O₂**.
- All'esterno l'ossigeno cala di **0,30 unità al secondo**.
- Il freddo aumenta il consumo di ossigeno.
- Dentro un ambiente pressurizzato con atmosfera respirabile, la tuta si ricarica a **2 unità al secondo** fino al massimo della tuta equipaggiata.

### Idratazione e acqua

- La sete parte a 100 e cala di **0,30 al secondo**.
- Una borraccia contiene fino a **2,0 L**.
- Bere consuma **0,2 L** e recupera **10** punti di sete.
- Una trivella alimentata può ricaricare la borraccia quando è selezionata nella hotbar e il giocatore è vicino.

### Fame e cibo

- La sazietà parte a 100 e cala di **0,20 al secondo**.
- Una razione recupera **30** punti di fame.
- Il raccolto completo della serra fornisce 16 razioni di patate.

### Freddo e ipotermia

La temperatura interna normale dell'astronauta è 37 °C. A **28 °C** si verifica ipotermia fatale. Il gioco calcola il divario fra temperatura effettiva e tolleranza termica della tuta:

- freddo lieve: riduce destrezza e movimento;
- freddo grave: riduce pesantemente movimento e aumenta il consumo di ossigeno;
- un riparo riduce il problema, una cupola alimentata lo riduce molto di più.

### Radiazioni

La radiazione cosmica di fondo è sempre presente. Possono verificarsi avvisi e picchi solari; gli eventi estremi sono predisposti nel sistema ma non sono attivati nel bilanciamento corrente.

Le tute e le cupole riducono separatamente la radiazione solare e cosmica. La dose acuta si dimezza ogni 24 ore di gioco; a **4.000 mSv** la missione fallisce. Prima della soglia letale, la radiazione riduce gradualmente la velocità del personaggio.

---

## 7. Tute EVA

Le tute sono acquistabili nello shop, diventano proprietà della missione e possono essere equipaggiate dall'inventario. Conservano una riserva di ossigeno distinta per modello.

| Tuta | Solare | Cosmica | O₂ | Tolleranza freddo | Movimento |
|---|---:|---:|---:|---:|---:|
| EVA standard | 30% | 5% | 100 | −50 °C | 100% |
| EVA rinforzata | 45% | 8% | 130 | −72 °C | 98% |
| EVA Explorer | 60% | 12% | 160 | −90 °C | 100% |
| EVA Storm | 75% | 18% | 200 | −112 °C | 94% |

La tuta non sostituisce una base: espande il raggio esplorabile e concede tempo per rientrare in sicurezza.

---

## 8. Inventario, hotbar e consegne

### Inventario

L'inventario è composto da una hotbar di **5 slot** e uno zaino di **20 slot**.

- Slot 1: strumento tubi, protetto.
- Slot 2–3: slot operativi per oggetti costruibili.
- Slot 4: borraccia, protetto.
- Slot 5: razioni, protetto.

Gli edifici e macchinari costruibili possono passare sia dallo zaino alla hotbar sia dalla hotbar allo zaino. Gli slot protetti evitano lo spostamento accidentale delle attrezzature vitali.

### Shop e capsule

Lo shop non consegna gli acquisti istantaneamente nell'inventario:

1. L'acquisto scala il budget.
2. Gli acquisti ravvicinati vengono aggregati per **4 secondi** in un unico ordine.
3. Una capsula atterra vicino all'astronauta in una posizione libera da rocce ed edifici.
4. Il giocatore raccoglie il contenuto con `E` da vicino.

Questo fa sì che fare acquisti durante un'esplorazione abbia un costo logistico reale, ma non obblighi a tornare alla base.

---

## 9. Costruzione, collisioni e rotazione

Il piazzamento avviene su griglia. L'anteprima mostra struttura e orientamento prima della conferma.

Regole fondamentali:

- non è possibile piazzare un oggetto sopra il giocatore;
- non è possibile piazzarlo sopra una roccia o sopra un'altra struttura;
- le impronte di cupola, camera di decompressione e base rover vengono incluse nella verifica;
- le costruzioni statiche hanno collisioni coerenti con la parte solida dello sprite;
- i macchinari possono essere ruotati per allineare porte, cavi, tubi e disposizione interna.

`R` ruota la struttura in anteprima. Per le cupole ruota la direzione dell'ingresso e della camera di decompressione; per macchinari e dispositivi ruota la loro impronta e i raccordi; per un tubo diritto alterna l'orientamento orizzontale/verticale.

Il tasto destro è usato per ispezione o rimozione, a seconda del punto cliccato. Cliccare un macchinario mostra le sue specifiche; clic destro sul raccordo O₂ di una cupola mostra il suo pannello atmosferico dettagliato.

---

## 10. Rete elettrica

L'energia è un sistema di rete automatico ma fisico. I cavi sono creati e rimossi automaticamente, gratuiti, usano percorsi ortogonali A* sulla griglia e non attraversano rocce o edifici. Possono passare sotto i tubi.

### Catena elettrica

```text
Pannelli solari → Trasformatore → Batterie → Consumatori
                         └──────→ Consumatori diretti (se non ci sono batterie)
```

La rete distingue tre flussi incompatibili: corrente grezza dai pannelli, corrente trasformata verso le batterie e corrente in uscita dalle batterie. Cavi di flussi diversi non possono condividere la stessa cella o creare una falsa giunzione.

### Regole di alimentazione

- Ogni pannello produce al massimo **100 kW**.
- Ogni batteria ha capacità **500 kWh** e una carica indipendente.
- Se la produzione supera i consumi, l'eccesso carica le batterie.
- Se la produzione non basta, le batterie scaricano automaticamente.
- Senza batterie, un consumatore funziona solo se la produzione solare istantanea copre tutta la richiesta.
- Se pannelli e batterie non coprono la domanda, la rete va in blackout.
- Un pannello richiede due celle di sprite più una cella libera alla sua destra per l'uscita del cavo.
- Il trasformatore è unico: non se ne può possedere più di uno tra mondo, inventario e consegne.

### Collegamento volontario

I consumatori possiedono uno stato di collegamento alla rete. Vicino a un macchinario, `V` abilita o disabilita volontariamente il suo raccordo elettrico. Questo è particolarmente importante per la serra: non deve attivarsi automaticamente solo perché un cavo passa vicino.

### Dispositivi energetici

| Dispositivo | Prezzo | Effetto |
|---|---:|---|
| Pannello solare | $500 MLN | Produce fino a 100 kW di giorno. |
| Trasformatore | $1 MLD | Trasforma e instrada la rete; uno solo. |
| Batteria | $750 MLN | Accumula 500 kWh per notte e picchi di domanda. |

---

## 11. Rete dei fluidi

I tubi trasportano risorse e non sono semplici collegamenti grafici. Sono creati con lo strumento tubi, costano **$100 MLN** per segmento e possono essere diritti oppure a croce.

| Comando con strumento tubi | Azione |
|---|---|
| Click sinistro | Piazza il segmento nella cella selezionata. |
| `T` | Alterna tubo diritto e raccordo a croce. |
| `R` | Ruota il tubo diritto. |
| Click destro | Demolisce il segmento bersagliato. |

Le categorie principali sono acqua, idrogeno e ossigeno. I raccordi di macchine e cupole impongono la categoria corretta: una linea deve connettersi al lato giusto della porta, non soltanto toccare visivamente lo sprite.

### Principio di flusso

- La trivella crea acqua quando ha elettricità.
- L'elettrolizzatore consuma acqua e produce flussi di H₂/O₂ solo sulle linee effettivamente connesse.
- Una cupola consuma l'ossigeno ricevuto per reintegrare la propria riserva.
- La serra consuma acqua direttamente dalla rete durante la crescita.
- Il Sabatier consuma H₂ e consegna CH₄ direttamente al razzo.

L'elettrolizzatore **non è un serbatoio**: nessun gas deve accumularsi al suo interno quando le uscite non sono collegate.

---

## 12. Estrazione e supporto vitale

### Trivella di ghiaccio

| Caratteristica | Valore |
|---|---:|
| Prezzo | $1,25 MLD |
| Assorbimento | 60 kW |
| Produzione | 40 L/h di gioco |
| Raccordo acqua | Destra, cella centrale |

Quando la trivella è alimentata estrae acqua. Se la sua uscita è collegata a una tubazione, l'acqua è disponibile ai consumatori. Con la borraccia selezionata, il giocatore può avvicinarsi e premere `E` per ricaricarla.

### Trivella mineraria

La trivella mineraria è una struttura elettrica senza uscita a tubo: perfora e vaglia il terreno locale, conservando carote geologiche in una riserva interna.

| Caratteristica | Valore |
|---|---:|
| Prezzo | $1,55 MLD |
| Assorbimento | 85 kW |
| Cadenza | 1 campione ogni 12 s reali |
| Capacità riserva | 32 campioni |
| Rarità speciale | 5% per estrazione |

Il bioma della cella di posa determina il catalogo estraibile. Ogni bioma offre due campioni comuni e una scoperta rara al 5%; i campioni dei biomi più remoti hanno moltiplicatori di ricavo scientifico maggiori. Avvicinandosi e premendo `E` si apre la riserva: il giocatore può trasferire una pila specifica nello zaino, prendere tutto o scartare l'intera riserva. Una riserva piena ferma la trivella finché non viene svuotata.

| Bioma | Campioni comuni | Scoperta rara al 5% |
|---|---|---|
| Pianura di atterraggio | Pietra marziana, Andesite marziana | Shoshonite olivinica |
| Regolite scura | Regolite rossa, Ematite nodulare | Goethite idrata |
| Cratere roccioso | Pietra da cratere, Breccia da impatto | Impactite vetrosa |
| Bordo della calotta | Roccia criogenica, Regolite perclorata | Sali solfati idrati |
| Ghiaccio polare | Ghiaccio polveroso, Ghiaccio laminato | Ghiaccio salmastro |
| Altopiano basaltico | Roccia basaltica, Basalto vescicolare | Olivina ferrifera |

### Elettrolizzatore

| Caratteristica | Valore |
|---|---:|
| Prezzo | $1,8 MLD |
| Assorbimento | 65 kW |
| Acqua assorbita | 40 L/h |
| Idrogeno prodotto | 4,0 kg/h |
| Ossigeno prodotto | 35,6 kg/h |

L'acqua entra **in basso a sinistra**. L'idrogeno esce dal lato sinistro della tile in alto a sinistra; l'ossigeno dal lato destro della tile in alto a destra. Le due uscite sono indipendenti: la macchina può funzionare se è connessa almeno una delle due linee, senza pretendere entrambe. I flussi scollegati non vengono stoccati.

### Reattore Sabatier

| Caratteristica | Valore |
|---|---:|
| Prezzo | $2,2 MLD |
| Assorbimento | 50 kW |
| Idrogeno assorbito | fino a 4,0 kg/h |
| Metano prodotto | fino a 4,0 kg/h |

Il Sabatier può essere posizionato solo nello spazio previsto alla sinistra della base di lancio. Richiede H₂ e elettricità; il metano non richiede alcun tubo, perché viene caricato direttamente nel razzo. Il serbatoio del razzo contiene fino a **400 kg di CH₄**.

---

## 13. Cupole abitative

Le cupole sono habitat pressurizzati acquistabili in tre dimensioni. Lo sprite ha una versione esterna e una interna; quando il giocatore entra, l'ambiente è reso leggibile senza nascondere il personaggio o il pavimento.

| Cupola | Raggio utile | Prezzo |
|---|---:|---:|
| Piccola | 62 px | $1,2 MLD |
| Media | 108 px | $2,4 MLD |
| Grande | 145 px | $4,0 MLD |

Tutte le cupole possono ospitare macchinari. La dimensione influisce soprattutto sulla superficie disponibile e sulle opzioni di configurazione, non su un divieto artificiale di contenuto.

### Camera di decompressione

L'accesso non avviene attraversando il muro della cupola. Ogni cupola ha un corridoio con due porte e una propria collisione.

**Entrata dall'esterno**

1. Avvicinarsi alla porta esterna e premere `E`.
2. Entrare nel corridoio.
3. Premere `F` per iniziare il ciclo di pressurizzazione.
4. Seguire a schermo una sequenza di quattro tasti direzionali (`W`, `A`, `S`, `D`).
5. A ciclo completato la porta interna si apre e il giocatore entra nella cupola.

**Uscita verso Marte**

1. Aprire la porta interna con `E`.
2. Entrare nel corridoio.
3. Avviare con `F` il ciclo opposto di decompressione e completare la sequenza.
4. Aprire la porta esterna.

Il ciclo non può essere avviato senza avere attraversato la prima porta corretta. Le porte usano sprite animati di apertura e chiusura.

### Atmosfera e ossigeno della cupola

Le cupole ricevono una riserva iniziale di **180 unità di O₂**, ma non hanno ossigeno infinito.

- perdita passiva: **0,02 unità/s**;
- consumo aggiuntivo quando l'astronauta è all'interno: **0,30 unità/s**;
- il raccordo O₂ esterno visibile usa la forma del tubo dell'ossigeno;
- la riserva viene reintegrata solo da una linea O₂ correttamente connessa;
- la ricarica massima è **1,5 unità/s**;
- 1 kg di O₂ proveniente dalla rete equivale a 100 unità di riserva della cupola.

Il tasto destro sul raccordo O₂ mostra una scheda con riserva, consumo, autonomia stimata, sorgenti connesse, stato del riscaldamento, schermature e base rover.

### Temperatura e alimentazione

La cupola offre un bonus termico passivo di **+8 °C**. Se collegata e alimentata dalla rete, il riscaldamento porta il bonus a **+45 °C** e assorbe **35 kW**. Il collegamento elettrico non ha un attacco visibile: deve apparire come una proprietà della rete, non come un tubo aggiuntivo.

### Configurazioni acquistabili

Al momento dell'acquisto, lo shop apre la configurazione della cupola e mostra con chiarezza le opzioni selezionabili.

| Add-on | Prezzo | Effetto |
|---|---:|---|
| Schermatura in piombo | $500 MLN | Aumenta la protezione radiologica della cupola. |
| Materiale idrogenato | $350 MLN | Aumenta la protezione contro radiazione cosmica e solare. |
| Base di ricarica rover | $600 MLN | Disponibile solo per cupola media o grande; costruisce il dock accanto alla cupola. |

---

## 14. Base rover e rover esplorativo

La base rover è un modulo fisico collegato alla cupola media o grande. Ha sprite, hitbox e punto d'attracco: non è un indicatore UI.

### Base rover

- Il rover si compra esclusivamente dalla base rover, non nello shop generale.
- Acquisto rover: **$2,4 MLD**.
- Richiamo di un rover non attraccato: **$300 MLN**.
- Un rover richiamato riappare visibilmente sul dock, se non ha un pilota e i pannelli sono chiusi.
- Il dock alimentato assorbe **50 kW** dalla cupola e ricarica il rover a **55 kW** quando è parcheggiato.

### Rover

| Caratteristica | Valore |
|---|---:|
| Batteria totale | 120 kWh |
| Carica iniziale | 72 kWh |
| Consumo di marcia | 7,5 kW |
| Ricarica solare con pannelli aperti | fino a 18 kW |
| Velocità | 310 |

Il rover possiede una batteria dedicata e non dipende dalla rete per muoversi. Da vicino, `E` fa salire o scendere l'astronauta. I pannelli solari possono essere aperti/chiusi con `F` solo quando il giocatore è vicino e a piedi; `F` non deve attivare il rover da lontano né interferire con la camera di decompressione.

---

## 15. Serra di patate

La serra è una cupola agricola con il proprio ingresso pressurizzato, basato sulle stesse regole di camera di decompressione delle cupole abitative.

### Struttura

- Prezzo: **$3,2 MLD**.
- Il pavimento/muro e il vetro sono due layer sovrapposti.
- Il vetro è poco trasparente esternamente e molto più trasparente quando il giocatore è dentro.
- Le pareti e le aiuole hanno collisione; il corridoio centrale resta libero e percorribile.
- All'interno si trovano due aiuole parallele, da **8 posti** ciascuna: totale **16 piante**.
- Gli sprite delle piante si sovrappongono alla terra; non sostituiscono il letto di coltivazione sottostante.
- Il raccordo dell'acqua è sul lato sinistro.

### Acqua e crescita

La serra cresce solo quando riceve acqua da una rete con una sorgente disponibile. Il tubo fisicamente collegato senza una sorgente che eroghi acqua non è sufficiente.

| Parametro | Valore |
|---|---:|
| Consumo acqua | 16 L per ora di gioco |
| Primo ciclo | 5 minuti reali |
| Cicli successivi | 3 minuti reali |
| Lotto di semi | Pianta tutte le 16 aiuole |
| Raccolto | 16 razioni di patate |

Il tempo è registrato come lavoro di crescita. Se si disattiva la corrente, il lavoro già completato rimane completato: non viene regalato tempo collegando l'energia all'ultimo istante, né viene annullato il vantaggio già ottenuto.

### Alimentazione volontaria

La serra può essere collegata o scollegata manualmente dalla rete tramite il pannello della struttura / comando di rete vicino al macchinario.

- assorbimento base: **10 kW**;
- quando alimentata, luci e riscaldamento aggiungono **15 kW**;
- crescita: **+60%** di velocità quando alimentata;
- di notte, una serra alimentata emette luce e mantiene l'interno illuminato;
- di notte le piante producono ossigeno solo se la serra è illuminata e alimentata.

### Ossigeno della serra

La serra non è una sorgente di O₂ infinito.

| Parametro | Valore |
|---|---:|
| Capacità atmosferica | 60 unità |
| Riserva iniziale | 36 unità |
| Perdita passiva | 0,035 unità/s |
| Consumo con astronauta dentro | +0,30 unità/s |
| Produzione per pianta matura | fino a 0,010 unità/s |

Le piante producono sempre più ossigeno al crescere del loro stadio. Con 16 piante, la produzione compensa parzialmente le perdite, ma non elimina il bisogno di gestire l'atmosfera.

### Interazioni agricole

- Con semi di patate disponibili, avvicinarsi alle aiuole e premere `E` per seminare il lotto.
- Vicino alla serra appare un timer fino al raccolto, oltre allo stato acqua/corrente.
- Quando il lotto è maturo, avvicinarsi alle aiuole: le 16 patate vengono raccolte insieme.
- Dopo il raccolto le piante rimangono piantate e avviano il ciclo di ricrescita da 3 minuti; non serve acquistare nuovi semi per ogni raccolto.

---

## 16. Ricerca scientifica

I macchinari di ricerca servono a trasformare le rocce in rapporti scientifici finanziabili. Possono essere installati in qualunque cupola abitativa, incluse quelle piccole; non sono installabili nella serra. Hanno collisione, si ruotano con `R` durante il piazzamento e richiedono spazio libero interno.

### Flusso di ricerca

```text
Raccogli una pietra → Portala a un laboratorio → E per caricarla
→ Analisi alimentata → Rapporto pronto → E per trasmetterlo alla Terra
→ Fondo economico ricevuto
```

Ogni analisi consuma un solo campione. Durante l'analisi il macchinario assorbe una grande quantità di energia; senza alimentazione il tempo non deve progredire. Il ricavo base dello strumento viene moltiplicato dal valore geologico del campione: una pietra comune vicina vale meno di una scoperta rara ottenuta con trivella in un bioma remoto.

### Economia della ricerca: rapporti e contratti

La prima metà della partita è sostenuta dalla ricerca, non dalla vendita passiva di risorse. Ogni pietra consegnata genera un **rapporto pagato immediatamente**; in parallelo il rapporto alimenta contratti scientifici visibili nella tavola `J`. Questi contratti sono grandi borse una tantum: danno il capitale necessario per acquistare il laboratorio successivo, gli upgrade, la logistica o l'espansione della base.

Un rapporto registra quattro dati: laboratorio usato, bioma di provenienza, rarità e quantità totale di trasmissioni. Per questo il giocatore ha una ragione concreta per spostare la trivella mineraria, esplorare fonti diverse e scegliere quale strumento specializzare. I progressi vengono registrati anche se il contratto è ancora bloccato; la borsa si può però riscuotere soltanto quando sono stati riscossi i contratti collegati.

```text
Campione → analisi energivora → pagamento del rapporto
         └→ contatore strumento / bioma / rarità / trasmissioni
            └→ contratto pronto → clic sul nodo dorato → grande finanziamento
```

I bonus riscossi si sommano: Segnale da Marte aumenta tutti i rapporti del 10%; Atlante di Ares aggiunge il 10%; Ponte Terra il 15%; le tre discipline aggiungono il 15% ai loro rispettivi strumenti; Costellazione rara aggiunge il 25% ai soli campioni rari; Direttorato scientifico aggiunge il 20% globale. La ricerca diventa quindi più redditizia proprio quando il giocatore affronta campioni e biomi più difficili.

### Contratti a piedi: capitale prima della rete

Prima di avere una cupola, una batteria o un laboratorio, l'astronauta può già finanziare la missione con due filoni autonomi:

| Filone | Azione reale | Premi progressivi |
|---|---|---|
| Raccolta | Raccogliere rocce fisiche della mappa con `E` | Prima pietra, Taccuino di campo, Sacca campioni, Catalogo di superficie, Luce nella polvere per una rara naturale. |
| Esplorazione | Rivelare biomi distinti camminando sulla mappa | Orizzonte aperto, Tre colori di Marte, Linea di orizzonte, Spedizione polare. |

Queste attività non richiedono corrente, macchinari o una base. I loro premi vanno da **$100 MLN** a **$1,1 MLD** e coprono il primo acquisto strutturale. La raccolta conta solo campioni presi fisicamente dalla superficie: trasferire materiale dalla trivella non falsa i contratti a piedi.

### Telecamera scientifica e contratti fotografici

Riscattare **Sacca campioni** consegna, oltre ai $420 MLN, una **telecamera scientifica** gratuita. Non è acquistabile: è il premio per avere dimostrato di saper raccogliere e catalogare la superficie. Va spostata in uno slot rapido dell'hotbar, come lo strumento tubi.

| Comando con telecamera equipaggiata | Azione |
|---|---|
| `P` | Scatta: identifica automaticamente bioma, fase del sol, rocce o struttura vicina e salva un PNG locale nel rullino. |
| `O` | Trasmette alla Terra il più vecchio scatto non inviato. Solo la trasmissione avanza i contratti e paga i premi. |
| `C` | Apre l'archivio fotografico con soggetto, bioma, sol, fase e stato di invio di ogni foto. |

La fotografia è un secondo percorso economico early game: non richiede rete, cupola, laboratorio né consumi energetici. I soggetti speciali riconosciuti sono roccia normale/rara, sei biomi, notte, alba polare, cupola, serra, laboratorio, ghiaccio profondo nell'inventario e laboratorio dopo la scoperta della vita. I contratti pagano da $150 MLN a $4 MLD e premiano il giocatore che si sposta nel mondo invece di restare vicino alla base.

L'archivio conserva fino a 36 scatti. Un effetto lampo dà conferma immediata dello scatto; un messaggio separato conferma l'invio, così “foto fatta” e “foto pagata” non vengono mai confuse.

| Strumento | Prezzo | Tempo base | Ricavo base | Dimensione |
|---|---:|---:|---:|---|
| Diffrattometro a raggi X (XRD) | $1,6 MLD | 2 min 30 s | $450 MLN | 32×16 px |
| Spettrometro Raman | $2,0 MLD | 3 min | $600 MLN | 32×16 px |
| ICP-MS | $2,8 MLD | 4 min | $900 MLN | 48×16 px |

Tutti i laboratori assorbono **240 kW** mentre analizzano. Quando hanno finito, mostrano uno stato/animazione dedicato; la trasmissione del rapporto richiede 4 secondi.

### Upgrade dei laboratori

Da vicino, `U` acquista un upgrade se ci sono fondi. Ogni laboratorio può arrivare a livello 5.

| Livello acquistato | Costo |
|---:|---:|
| 1 | $175 MLN |
| 2 | $250 MLN |
| 3 | $350 MLN |
| 4 | $500 MLN |
| 5 | $700 MLN |

Gli upgrade riducono gradualmente il tempo di analisi. Al massimo livello, qualunque macchina arriva a **40 secondi** di analisi. Il pannello del laboratorio mostra campione, livello, durata attuale, prossimo costo, assorbimento, stato della rete e ricavo del rapporto.

### Ghiaccio profondo primordiale e vita antica

La trivella mineraria può trovare il **ghiaccio profondo primordiale** in ogni bioma con probabilità dell'**1%** per estrazione. Sul bioma del ghiaccio polare la probabilità sale al **10%**: è il posto da cui parte la spedizione più rischiosa e redditizia.

Il campione si può inserire in qualunque laboratorio. Durante lo studio viene mostrata la probabilità di rilevare una biosignatura; il risultato è deciso una volta, all'avvio della scansione, e non cambia con blackout o salvataggi.

| Strumento | Probabilità di vita antica | Perché |
|---|---:|---|
| XRD | 20% (1 su 5) | Può distinguere microstrutture minerali compatibili con attività biologica. |
| Raman | 35% | Riconosce meglio composti organici intrappolati nel ghiaccio. |
| ICP-MS | 55% | Misura firme isotopiche e tracce organiche con maggiore sensibilità. |

Una biosignatura aggiunge **$10 MLD** al pagamento immediato del rapporto, oltre al valore normale del campione e ai bonus attivi. Attiva anche la sequenza a catena: **Carota polare → Ghiaccio primordiale → Strati del tempo → Vita antica → Messaggio vivente**, con borse da $1,8 a $25 MLD. La ricompensa più alta resta sempre incatenata: non può essere riscossa prima della scoperta di vita.

---

## 17. Shop ed economia

### Economia iniziale

La missione comincia con **$10 MLD**. La scelta di prezzi in milioni e miliardi rende evidente quali decisioni sono strutturali: un pannello è accessibile, una cupola o un rover richiedono pianificazione.

### Sezioni dello shop

Lo shop è organizzato in sezioni per evitare un catalogo confuso. La categoria veicoli non viene usata per l'acquisto diretto del rover: il rover appartiene alla base rover.

1. **Tute ed equipaggiamento EVA**
2. **Habitat e cupole**
3. **Energia e distribuzione**
4. **Estrazione risorse**
5. **Supporto vitale**
6. **Ricerca e analisi**

Le cupole mostrano una miniatura e, prima dell'ordine, la pagina di configurazione per piombo, materiale idrogenato e base rover. I semi di patate e le miniature della serra usano sprite con sfondo trasparente.

### Prezzi principali

| Categoria | Oggetto | Prezzo |
|---|---|---:|
| Energia | Pannello | $500 MLN |
| Energia | Trasformatore | $1 MLD |
| Energia | Batteria | $750 MLN |
| Estrazione | Trivella di ghiaccio / trivella mineraria | $1,25 / $1,55 MLD |
| Supporto vitale | Elettrolizzatore | $1,8 MLD |
| Supporto vitale | Sabatier | $2,2 MLD |
| Habitat | Cupola piccola / media / grande | $1,2 / $2,4 / $4,0 MLD |
| Habitat | Serra | $3,2 MLD |
| Habitat | Semi di patate, lotto | $120 MLN |
| Ricerca | XRD / Raman / ICP-MS | $1,6 / $2,0 / $2,8 MLD |
| EVA | Rinforzata / Explorer / Storm | $650 MLN / $1,1 / $1,8 MLD |

---

## 18. Tavola degli obiettivi

La tavola degli obiettivi è una progressione a grafo, non una lista lineare. Si apre con `J`; quando è aperta, le altre GUI di gioco vengono nascoste per lasciare spazio alla lettura del grafo. `J` o `Esc` la chiudono.

### Stati visivi dei nodi

| Stato | Aspetto | Significato |
|---|---|---|
| Bloccato | Fascia rossa superiore | I prerequisiti non sono ancora riscattati. Il progresso può comunque avanzare. |
| Disponibile | Grigio spento | I prerequisiti sono riscattati, ma l'obiettivo non è ancora raggiunto. |
| Raggiunto e da riscattare | Colore del ramo, luccicante | Il traguardo è completo; cliccare il nodo per ricevere la ricompensa. |
| Riscattato | Colorato | Ricompensa già ottenuta; apre i nodi successivi. |

I collegamenti scorrono orizzontalmente e si diramano per raccolta, esplorazione, fotografia, acqua/sopravvivenza, habitat/cibo, ricerca industriale e biologia polare. Una ricompensa è riscattabile solo dopo che tutti i prerequisiti sono stati riscattati, anche se il suo contatore è già completo. La rete contiene **55 nodi**: i 9 contratti iniziali e i 15 contratti fotografici rendono possibile guadagnare senza infrastruttura, mentre i rami successivi trasformano la ricerca nella fonte principale di capitale.

### Grafo attuale

```text
PRIMA PIETRA ── TACCUINO ── SACCA CAMPIONI ── CATALOGO DI SUPERFICIE
                       └────────────────────── LUCE NELLA POLVERE
                       └─ TELECAMERA ── PRIMO SCATTO ── PROVINO ── CARTOLINE DA MARTE
                                          ├─ RITRATTO MINERALE ── LENTE SULL'ANOMALIA
                                          ├─ GALLERIA BIOMI ── SEI ORIZZONTI ── LUCE POLARE
                                          │                    └─ GHIACCIO ALL'ALBA
                                          └─ CIELO NOTTURNO / AVAMPOSTO / SERRA / LABORATORIO
ORIZZONTE APERTO ── TRE COLORI ── LINEA DI ORIZZONTE ── SPEDIZIONE POLARE
                                                                    │
PRIMA BASE ── ACCESSO SICURO ── PRIMA TRIVELLA ── BORRACCIA RICARICATA
    └─ RETE ELETTRICA ── SERRA ── PIANTAGIONE ── RACCOLTO
                     └─ PRIMO LAB ── SEGNALE DA MARTE ── CATENA DI CUSTODIA
                          ├─ CAROTA GEOLOGICA ── CAROTA POLARE ── GHIACCIO PRIMORDIALE
                          │                                      └─ STRATI DEL TEMPO ── VITA ANTICA ── MESSAGGIO VIVENTE
                          └─ RAPPORTI ── XRD / RAMAN / ICP-MS ── BREVETTI ─┐
                                       ├─ ATLANTE ── ARCHIVIO PLANETARIO ─┤─ DIRETTORATO ── DIVIDENDO MARZIANO
                                       └─ CONVOGLIO DATI ── PONTE TERRA ──┘
```

La sequenza esatta dei prerequisiti principali è:

| Obiettivo | Condizione | Prerequisiti | Ricompensa |
|---|---|---|---|
| Prima pietra | Raccogli una roccia fisica a piedi | — | +$120 MLN |
| Taccuino di campo | Raccogli 3 rocce a piedi | Prima pietra | +$220 MLN |
| Sacca campioni | Raccogli 8 rocce a piedi | Taccuino | +$420 MLN |
| Primo scatto | Trasmetti 1 fotografia | Sacca campioni | +$150 MLN |
| Provino marziano | Trasmetti 3 fotografie | Primo scatto | +$260 MLN |
| Cartoline da Marte | Trasmetti 8 fotografie | Provino | +$720 MLN |
| Ritratto minerale / Lente sull'anomalia | Foto di roccia / di roccia rara | Primo scatto / Ritratto | +$240 / $750 MLN |
| Galleria di biomi / Sei orizzonti | Foto da 3 / 6 biomi | Primo scatto / Galleria | +$360 MLN / $1,2 MLD |
| Ghiaccio all'alba / Luce polare | Foto criosfera all'alba / dal polo | Galleria / Spedizione polare + Galleria | +$520 MLN / $1,05 MLD |
| Cielo senza atmosfera | Foto notturna | Primo scatto | +$430 MLN |
| Primo avamposto | Foto esterna della cupola | Prima base + Primo scatto | +$610 MLN |
| Vetro e clorofilla / Scienza in campo | Foto serra / laboratorio | Serra o laboratorio + Primo scatto | +$800 / $950 MLN |
| Tempo nel ghiaccio | Foto con ghiaccio primordiale custodito | Ghiaccio primordiale + Primo scatto | +$2 MLD |
| Testimone della vita | Foto laboratorio dopo biosignatura | Vita antica + Scienza in campo | +$4 MLD + Badge Occhio di Marte |
| Catalogo di superficie | Raccogli 3 tipi differenti a piedi | Taccuino | +$600 MLN |
| Luce nella polvere | Raccogli una rara naturale a piedi | Taccuino | +$900 MLN |
| Orizzonte aperto | Esplora il primo bioma | — | +$100 MLN |
| Tre colori di Marte | Esplora 3 biomi | Orizzonte aperto | +$350 MLN |
| Linea di orizzonte | Esplora 5 biomi | Tre colori | +$800 MLN |
| Spedizione polare | Raggiungi il ghiaccio polare | Tre colori | +$1,1 MLD |
| Prima base | Posiziona una cupola abitativa | — | +$150 MLN |
| Accesso sicuro | Completa un ciclo airlock | Prima base | Badge Colono marziano |
| Rete elettrica | Rendi operativa rete con pannelli, trasformatore e batteria | Prima base | +$150 MLN |
| Prima trivella | Posiziona una trivella | Accesso sicuro + Rete elettrica | +$100 MLN |
| Borraccia ricaricata | Riempi la borraccia dalla trivella alimentata | Prima trivella | Consumo acqua −10% |
| Serra operativa | Collega la serra a una sorgente d'acqua | Rete elettrica | +$200 MLN |
| Prima piantagione | Semina il primo lotto | Serra operativa | Crescita colture +5% |
| Primo raccolto | Raccogli 16 patate | Prima piantagione | +$300 MLN |
| Primo laboratorio | Installa uno strumento scientifico | Rete elettrica | +$250 MLN |
| Carota geologica | Posiziona la trivella mineraria | Prima trivella + Primo laboratorio | +$350 MLN |
| Carota polare | Posiziona la trivella mineraria sul ghiaccio polare | Spedizione polare + Carota geologica | +$1,8 MLD |
| Ghiaccio primordiale | Estrai il ghiaccio profondo primordiale | Carota polare | +$3 MLD |
| Strati del tempo | Avvia lo studio del ghiaccio primordiale | Ghiaccio primordiale + Primo laboratorio | +$4,5 MLD |
| Vita antica | Rileva una biosignatura nel ghiaccio | Strati del tempo | +$15 MLD + Badge Scopritore di vita |
| Messaggio vivente | Trasmetti la prova alla Terra | Vita antica | +$25 MLD, rapporti +25% |
| Segnale da Marte | Primo rapporto trasmesso | Primo laboratorio | +$400 MLN, ricavi ricerca +10% |
| Catena di custodia | 3 rapporti | Segnale da Marte | +$550 MLN |
| Reticoli rivelati | 3 rapporti XRD | Segnale da Marte | +$650 MLN, valore XRD +15% |
| Impronte luminose | 3 rapporti Raman | Segnale da Marte | +$800 MLN, valore Raman +15% |
| Tracce nel plasma | 3 rapporti ICP-MS | Catena di custodia | +$1 MLD, valore ICP-MS +15% |
| Segnale anomalo | Primo campione raro trasmesso | Carota geologica + Segnale da Marte | +$1,1 MLD |
| Atlante di Ares | 3 biomi distinti | Carota geologica + Catena di custodia | +$1,25 MLD, dati multi-bioma +10% |
| Convoglio dati | 8 rapporti | Catena di custodia | +$1,4 MLD |
| XRD / Raman / ICP-MS di precisione | Porta il relativo strumento al livello 5 | Contratto della disciplina | +$1 / $1,25 / $1,6 MLD |
| Costellazione rara | 3 campioni rari trasmessi | Segnale anomalo + Raman | +$1,9 MLD, rari +25% |
| Ponte Terra | 15 rapporti | Convoglio dati + ICP-MS | +$2,5 MLD, rapporti +15% |
| Archivio planetario | 6 biomi distinti | Atlante di Ares + Segnale anomalo | +$3 MLD |
| Direttorato scientifico | Tre strumenti al massimo, Ponte Terra e Archivio | Cinque contratti finali | +$4 MLD, rapporti +20%, Badge Direttore scientifico |
| Dividendo marziano | 24 rapporti | Direttorato + Costellazione rara | +$6 MLD, Badge Pioniere del valore |

**Persistenza:** gli obiettivi sono volutamente legati alla singola missione. Non vengono salvati su disco; avviare di nuovo il gioco o ricominciare la missione parte sempre con nodi, premi e bonus a zero.

---

## 19. Schema di progressione consigliato

Il giocatore è libero di sperimentare, ma il percorso didattico naturale è:

1. Camminare, raccogliere rocce, rivelare biomi e trasmettere le prime fotografie: i contratti a piedi e l'archivio visivo finanziano il primo investimento senza corrente.
2. Posizionare la prima cupola e imparare la camera di decompressione.
3. Stabilire rete solare, trasformatore e batteria.
4. Costruire trivella, ricaricare la borraccia e distribuire acqua.
5. Installare l'elettrolizzatore per creare una linea O₂ per la cupola e una linea H₂ per il Sabatier.
6. Scegliere se investire in una serra per autonomia alimentare o in un laboratorio per ricavi più rapidi.
7. Spostare la trivella mineraria tra biomi e usare i rapporti per finanziare gli upgrade.
8. Raggiungere il polo: la trivella lì ha il 10% di trovare ghiaccio profondo primordiale; scegliere ICP-MS massimizza la probabilità della biosignatura.
9. Portare gli strumenti scientifici al livello massimo e completare il Direttorato scientifico.

Questa sequenza evita che il giocatore senta il bisogno di comprare tutto insieme: ogni nuovo sistema risolve un problema concreto e introduce il successivo.

---

## 20. Comandi

| Comando | Azione |
|---|---|
| `W` `A` `S` `D` | Movimento dell'astronauta; anche input della sequenza airlock quando richiesto. |
| Rotella | Zoom della telecamera. |
| `M` | Apri/chiudi carta topografica. |
| Rotella sulla mappa | Zoom della carta. |
| Trascina la rotella sulla mappa ingrandita | Sposta la visuale della carta. |
| `Tab` | Apri/chiudi inventario. |
| `1`–`5` | Seleziona slot hotbar. |
| `B` | Apri/chiudi shop. |
| `J` | Apri/chiudi tavola obiettivi. |
| `P` | Con telecamera equipaggiata, scatta una foto scientifica. |
| `O` | Con telecamera equipaggiata, trasmetti alla Terra lo scatto più vecchio non inviato. |
| `C` | Con telecamera equipaggiata, apri/chiudi archivio fotografico. |
| `Esc` | Chiude pannelli/modal aperti. |
| Click sinistro | Usa l'oggetto selezionato, piazza o ispeziona una struttura. |
| Click destro | Demolisce/recupera l'oggetto bersagliato; sul raccordo O₂ della cupola apre la diagnostica. |
| `R` | Ruota anteprima di edificio/macchina/tubo. |
| `T` | Con lo strumento tubi, alterna diritto/croce. |
| `E` | Interazione contestuale: porte, capsule, rocce, trivella con borraccia, serra, laboratorio, rover. |
| `F` | Avvia ciclo airlock dal corridoio; vicino a un rover a piedi, apre/chiude i pannelli. |
| `U` | Upgrade del laboratorio vicino. |
| `V` | Abilita/disabilita il raccordo alla rete del macchinario vicino. |

Le azioni contestuali hanno priorità e distanza: `E` non deve raccogliere una roccia lontana né rubare l'interazione a un rover o a una porta più vicina.

---

## 21. Interfaccia e feedback

L'interfaccia ha il compito di spiegare sistemi complessi senza trasformare il gioco in un foglio di calcolo.

### HUD di sopravvivenza

Mostra ossigeno, fame, sete, stato termico, dose/rischio radiologico, ora e stato della rete.

### Pannelli contestuali

Vicino a un impianto il giocatore vede:

- stato di alimentazione;
- richieste di input e disponibilità della sorgente;
- produzione/consumo effettivi;
- prompt rilevanti (`E`, `U`, `V`, ecc.);
- timer di lavoro, crescita o analisi;
- stato delle porte e della sequenza airlock, quando necessario.

### Pannelli di ispezione

Il click sinistro su un edificio mostra una scheda con nome, categoria, principio tecnico, stato e specifiche. La cupola espone inoltre l'ispezione atmosferica mediante il suo raccordo O₂. Questi pannelli servono anche da strumento di debug per il giocatore: se un sistema non produce, deve risultare chiaro se manca acqua, potenza, tubo, sorgente o spazio nel razzo.

---

## 22. Architettura di gioco (per sviluppo)

Il progetto è realizzato in Godot. I sistemi principali sono separati in manager/autoload, in modo che UI e strutture condividano una fonte coerente di stato.

| Sistema | Responsabilità |
|---|---|
| `GameState` | Controlla fallimento e riavvio completo della missione. |
| `Inventory` | Hotbar, zaino, stack, borraccia, rocce, rover recuperato. |
| `Economy` | Budget della missione. |
| `Shop` | Catalogo, prezzi, configurazioni cupola, acquisti. |
| `DeliveryManager` | Aggregazione ordini e capsule di consegna. |
| `WorldClock` / `DayNightController` | Ora, ciclo solare, colore e luce del mondo. |
| `PowerGrid` | Topologia automatica di cavi, produzione, batterie e blackout. |
| `PipeManager` | Topologia, categorie e consumo di fluidi. |
| `BuildableRegistry` | Registro di strutture, ispezione, hitbox e demolizione. |
| `Oxygen`, `Hydration`, `Hunger`, `Temperature`, `Radiation` | Simulazione delle necessità e dei rischi dell'astronauta. |
| `SuitSystem` | Proprietà, possesso ed equipaggiamento delle tute. |
| `AchievementManager` | Grafo missione, premi e bonus non persistenti. |
| `FieldCamera` | Rullino, cattura locale, identificazione del soggetto, invio alla Terra e UI archivio. |
| `WorldMapUI` | Esplorazione rivelata, zoom, pan e marcatori. |

### Principi tecnici da preservare

1. **Una sola fonte di verità.** Il flusso di acqua, gas e potenza non va duplicato nella UI.
2. **Nessun accumulo invisibile.** Se una macchina è dichiarata “a flusso continuo”, non deve avere una riserva segreta.
3. **Interazioni a distanza controllata.** Ogni `E`/`F` verifica vicinanza e stato; un input non deve attivare sistemi lontani.
4. **Collisione e grafica separate ma coerenti.** Gli sprite possono avere trasparenze e layer diversi, ma la hitbox deve rappresentare le parti solide e lo spazio percorribile.
5. **Piazzamento validato prima del consumo.** L'oggetto viene rimosso dall'inventario soltanto dopo un piazzamento valido.
6. **Riavvio deterministico.** Una nuova missione resetta manager, mondo, inventario, ordini e achievement senza ereditare dati di test precedenti.
7. **Interfaccia adattiva.** Finestra liberamente ridimensionabile; shop, inventario, mappa, archivio e tavola usano ancoraggi percentuali e mantengono margini leggibili invece di una risoluzione rigida.

---

## 23. Criteri di qualità delle funzionalità

Ogni nuova struttura dovrebbe rispettare questa checklist prima di essere considerata completa:

- sprite visibile sia in anteprima sia dopo il piazzamento;
- ordine di rendering corretto rispetto a terreno, giocatore, corridoio e layer interni;
- hitbox proporzionata e testata;
- impossibilità di sovrapporsi a giocatore, rocce o edifici;
- rotazione coerente di sprite, impronta, porte e raccordi;
- consumo/produzione gestiti dalla rete corretta;
- UI di stato che spiega il motivo quando non funziona;
- azioni contestuali limitate alla distanza corretta;
- recupero/demolizione che aggiorna cavi, tubi, registro e inventario;
- test automatico di fumo e prova manuale nel gioco.

---

## 24. Glossario

| Termine | Significato |
|---|---|
| Airlock / camera di decompressione | Corridoio a due porte che isola l'interno pressurizzato dall'esterno marziano. |
| Rete attiva | Un dispositivo è cablato, abilitato e riceve potenza sufficiente. |
| Sorgente disponibile | Un tubo è connesso a un produttore che, in quel momento, eroga davvero la risorsa. |
| Flusso diretto | Risorsa prodotta nel tick corrente e disponibile solo ai consumatori connessi; non è un magazzino. |
| Raccordo | Cella e direzione precisa in cui un tubo/cavo può connettersi a una struttura. |
| Obiettivo raggiunto | Il contatore dell'obiettivo è completo; può ancora essere bloccato se non sono stati riscattati i prerequisiti. |
| Obiettivo riscattato | Ricompensa applicata e nodi figli potenzialmente sbloccati. |

---

## 25. Sintesi finale

*Space Beaver* è una simulazione di sopravvivenza marziana in cui ogni sicurezza dipende da un'infrastruttura costruita e mantenuta dal giocatore. La cupola dà riparo ma consuma ossigeno; l'ossigeno richiede acqua ed energia; l'energia dipende dal sole e dalle batterie; il cibo richiede una serra con acqua e luce; l'espansione richiede denaro, e il denaro arriva da una ricerca che a sua volta richiede campioni, spazio e moltissima energia.

Il risultato desiderato è una base che il giocatore sappia leggere a colpo d'occhio: ciò che funziona è acceso, collegato e produttivo; ciò che non funziona spiega perché; ciò che è pericoloso richiede una scelta consapevole prima di uscire nel pianeta rosso.



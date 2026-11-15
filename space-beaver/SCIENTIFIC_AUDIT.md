# Audit scientifico dei testi di Space Beaver

Documento preparato per una revisione da parte di uno scienziato. Le percentuali,
i tempi, le ricompense e le capacità produttive sono parametri di gameplay: non
devono essere letti come dati sperimentali o come specifiche di una missione NASA.

## 1. Report narrativo di Perseverance

Il gioco mostra volutamente questo testo, fornito dal committente:

> PERSEVERANCE (NASA, 2021)
>
> • Periodo operativo: 18 febbraio-novembre 2026;
> • Causa della cessazione delle operazioni: il progressivo deterioramento delle ruote e dei motori di trazione, dovuto alla lunga esposizione al terreno marziano e all'usura dei componenti meccanici, compromette la capacità di movimento del rover, rendendolo definitivamente impossibilitato a proseguire le operazioni.
> • Condizione finale: rimarrebbe immobilizzato nel cratere Jezero, su Marte. Prima del guasto aveva percorso oltre 45,22 km (dato dell'11 ottobre 2026), superando il record di Opportunity.

### Verifica

- Il valore di 45,22 km all'11 ottobre 2026 e il superamento dei 45,16 km di
  Opportunity sono coerenti con il comunicato JPL del 12 ottobre 2026.
- La fonte JPL consultata descrive Perseverance come operativo, con i sistemi di
  mobilità funzionanti, e parla di una missione estesa fino circa alla fine del
  2028. Perciò “cessazione a novembre 2026” e “immobilizzato” sono da trattare
  come una linea narrativa alternativa del gioco, non come una conclusione NASA
  verificata.
- L'usura delle ruote è un rischio tecnico reale: NASA ha documentato che le
  rocce taglienti possono danneggiare le ruote dei rover. Il testo però non deve
  essere presentato come causa storica reale del fermo di Perseverance senza una
  fonte ufficiale aggiornata.

## 2. Sistemi fisici e macchinari

### Pannello solare fotovoltaico

Testo mostrato:

> Le celle fotovoltaiche convertono i fotoni solari in corrente continua tramite
> l'effetto fotovoltaico nei semiconduttori.

Valutazione: corretto come spiegazione sintetica. “100 kW”, la produzione
proporzionale alla luce e la produzione notturna nulla sono parametri del gioco.
La polvere che riduce la luce disponibile e quindi la potenza è fisicamente
plausibile e documentata da NASA, ma l'effetto numerico della tempesta è una
semplificazione di gameplay.

### Trasformatore elettrico

Testo mostrato:

> L'induzione elettromagnetica trasferisce energia tra avvolgimenti isolati e
> adatta tensione e corrente alla rete di accumulo.

Valutazione: corretto per un trasformatore convenzionale in corrente alternata.
La frase “ogni trasformatore crea una rete indipendente” descrive una regola di
rete del gioco, non una conseguenza fisica automatica: nella realtà dipende da
come gli avvolgimenti e i sistemi sono collegati.

### Batteria di accumulo

Testo mostrato:

> L'energia elettrica viene immagazzinata come energia chimica reversibile e
> restituita alla rete quando la produzione solare non copre il carico.

Valutazione: corretto come descrizione generale di una batteria ricaricabile.
“500 kWh”, i flussi e la disponibilità notturna sono parametri del gioco.

### Trivella di estrazione del ghiaccio

Testo mostrato:

> Modello ISRU del gioco: la testa perfora regolite marziana contenente ghiaccio;
> il ghiaccio recuperato viene separato e fuso per ottenere acqua liquida.

Valutazione: è una descrizione prudente di un sistema ISRU ipotetico. ISRU
significa “utilizzo delle risorse in situ”. Su Marte l'acqua è soprattutto
considerata come ghiaccio o minerali idratati; l'estrazione, la purificazione e
la fusione richiederebbero apparecchiature e bilanci energetici non simulati in
dettaglio dal gioco. “80 L/h”, “60 kW” e serbatoio da “500 L” sono gameplay.

### Elettrolizzatore dell'acqua

Testo mostrato:

> L'elettrolisi usa energia per scindere l'acqua in H₂ e O₂ e li fornisce in
> continuo sulle rispettive linee, senza serbatoi interni.

Reazione da mostrare o controllare:

> 2 H₂O → 2 H₂ + O₂

Valutazione: corretto per l'elettrolisi dell'acqua. La reazione richiede energia
e produce il doppio di moli di idrogeno rispetto alle moli di ossigeno. Nel gioco
le uscite sono flussi diretti e senza accumulo: è una scelta di simulazione.
L'acqua deve essere pura o trattata adeguatamente in un sistema realistico; il
gioco non simula la purificazione.

### Reattore Sabatier

Testo mostrato:

> La reazione di Sabatier combina CO₂ atmosferica e idrogeno per sintetizzare
> metano e acqua: CO₂ + 4 H₂ → CH₄ + 2 H₂O. Nel modello di gioco il metano viene
> trasferito direttamente al razzo.

Valutazione: reazione corretta. Servono CO₂, H₂, catalizzatore, controllo della
temperatura e gestione del calore; il gioco assume che la CO₂ atmosferica sia
disponibile e non simula questi sottosistemi. In una catena ISRU l'acqua prodotta
può essere riciclata verso l'elettrolisi. Il trasferimento diretto al razzo è una
regola del gioco.

## 3. Strumenti scientifici

### Diffrattometro a raggi X (XRD)

Testo mostrato:

> La diffrazione dei raggi X identifica le fasi cristalline del campione dalla
> geometria del reticolo atomico.

Valutazione: corretto. Le posizioni e intensità dei picchi dipendono dalla
struttura cristallina e permettono di identificare fasi minerali. XRD non è, da
solo, un rilevatore di vita e non dimostra una biosignatura.

### Spettrometro Raman

Testo mostrato:

> Lo scattering Raman del laser rivela i legami molecolari e la composizione
> mineralogica senza distruggere il campione.

Valutazione: sostanzialmente corretto. Lo spettro Raman deriva da modi
vibrazionali e può caratterizzare minerali e alcune molecole. “Non distruttivo”
va inteso come analisi che, in condizioni appropriate, non richiede di
consumare il campione; il laser, la preparazione e il materiale possono comunque
causare alterazioni in casi estremi.

### Spettrometro ICP-MS

Testo mostrato:

> Il plasma accoppiato induttivamente ionizza il campione; lo spettrometro di
> massa misura gli elementi e le loro abbondanze.

Valutazione: corretto come sintesi. In pratica il campione deve essere preparato
e introdotto nello strumento; ICP-MS misura concentrazioni elementari e può
misurare rapporti isotopici con configurazioni e calibrazioni adeguate. Non è una
prova autonoma di vita e non “rileva materia organica” in modo specifico senza
metodi complementari.

### Biosignature / segnale compatibile

Nel gioco XRD, Raman e ICP-MS hanno rispettivamente chance 20%, 35% e 55% di
produrre un risultato positivo sul ghiaccio profondo. Questi numeri sono ora
esplicitamente marcati come **modello di gioco**. Non sono sensibilità, accuratezze
o probabilità pubblicate per strumenti reali. Un risultato positivo va chiamato
“segnale compatibile con una possibile biosignatura”, non “prova di vita”. Una
vera biosignatura richiederebbe più linee di evidenza, controlli contro la
contaminazione, contesto geologico e analisi indipendenti.

## 4. Campioni e terminologia della trivella

“Carota” è un termine tecnico corretto per un cilindro di roccia estratto con un
carotaggio, ma non è il nome della missione né il nome della trivella. Per questo
la progressione del gioco ora usa:

- **CAMPIONAMENTO GEOLOGICO**: prima installazione della trivella mineraria;
- **CAMPIONAMENTO POLARE**: installazione nel bioma polare;
- **campione geologico**: materiale conservato dalla trivella;
- **carota di roccia**: termine tecnico ammesso solo quando si intende davvero
  un cilindro ottenuto tramite carotaggio.

I nomi mineralogici usati dal gioco (basalto, andesite, olivina, ematite,
goethite, solfati, breccia e impactite) sono categorie o nomi plausibili, ma le
associazioni precise a biomi, rarità e moltiplicatori economici sono costruzione
narrativa. La “shoshonite olivinica”, il “ghiaccio profondo primordiale” e la
biosignatura nel ghiaccio sono elementi fittizi del gioco e devono restare
marcati come tali.

## 5. Ambiente marziano e sopravvivenza

### Atmosfera e supporto vitale

Il gioco assume correttamente che l'atmosfera marziana sia molto sottile e ricca
di CO₂, quindi non respirabile. La riserva di O₂ della cupola, i consumi, la
pressione, le perdite e l'equivalenza tra kg e “unità” sono astrazioni numeriche:
non sono valori ingegneristici certificati.

### Radiazioni

Il gioco distingue fondo cosmico e picchi solari e usa mSv per la dose. La
distinzione fisica è corretta; tute e habitat possono ridurre l'esposizione, ma
la protezione reale dipende da massa, composizione, geometria, durata e spettro
della radiazione. La soglia di 4.000 mSv, il dimezzamento in 24 ore e i bonus
delle schermature sono regole di gioco da non presentare come limiti clinici
universali.

### Tempeste di polvere

La polvere può ridurre la luce sui pannelli e contaminare o danneggiare
meccanismi ed elettronica. Il vento marziano, però, esercita una pressione molto
inferiore a quella suggerita da molte rappresentazioni cinematografiche: i
debuff, l'aumento dei consumi EVA e i livelli di sabbia sono bilanciamento del
gioco.

### Serra e patate

La serra pressurizzata, l'acqua per la crescita e il raccolto sono coerenti con
la fantasia di una base, ma “4 o 5 razioni”, tempi di crescita, produzione e
modifica genetica dei semi sono meccaniche di gioco. Non vanno interpretati come
una previsione agricola realistica su Marte. I livelli GM sono progressione
narrativa e non equivalgono a varietà approvate o a una resa sperimentale.

## 6. Fonti primarie da far controllare

- [NASA/JPL — Perseverance sets off-world distance record](https://www.jpl.nasa.gov/news/nasas-perseverance-sets-off-world-record-for-total-distance-driven/)
- [NASA — Perseverance rover components and drill](https://science.nasa.gov/mission/mars-2020-perseverance/rover-components/)
- [NASA/JPL Education — core sampling](https://www.jpl.nasa.gov/edu/resources/project/explore-rocks-using-core-sampling/)
- [NASA ARES — X-ray diffraction](https://ares.jsc.nasa.gov/research/laboratories/xray-diffraction.html)
- [NASA — Mars atmosphere](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/mars-atmosphere-equation-english/)
- [NASA — methane and oxygen production on Mars](https://www.nasa.gov/directorates/stmd/space-tech-research-grants/producing-methane-and-oxygen-on-mars-using-proton-conducting-ceramics/)
- [NASA — dust storms and their effect on solar power](https://science.nasa.gov/solar-system/planets/mars/10-things-dust-in-the-wind-on-mars-and-well-beyond/)
- [NASA — fact and fiction of Martian dust storms](https://www.nasa.gov/solar-system/the-fact-and-fiction-of-martian-dust-storms/)

## 7. Punti da approvare prima di chiamarli “scientifici”

1. Se il report di Perseverance deve essere una ricostruzione storica NASA o una
   storia alternativa del gioco. Il codice conserva il testo richiesto, ma la
   fonte JPL consultata non conferma il fermo a novembre 2026.
2. Se “ghiaccio profondo primordiale” deve restare un elemento fiction oppure
   essere sostituito da un campione geologico realistico, senza implicare vita.
3. Se il gioco vuole usare “segnale compatibile rilevato” come abbreviazione narrativa o
   mantenere sempre la formulazione scientificamente prudente “segnale
   compatibile”. Nel codice e nelle missioni è stata scelta la seconda.
4. I valori numerici di energia, acqua, gas, radiazione, temperatura, tempi e
   resa devono essere approvati come bilanciamento di gioco, non come dati di
   progetto per un habitat reale.

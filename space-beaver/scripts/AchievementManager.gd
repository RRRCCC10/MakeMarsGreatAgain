extends Node

## Progressione della singola missione. Ogni nuovo avvio parte da zero: gli
## obiettivi avanzano anche prima di essere disponibili, ma le ricompense si
## riscattano rispettando il grafo dei prerequisiti.

signal achievement_updated(achievement_id: String)
## Emesso una sola volta quando il progresso raggiunge il bersaglio, anche
## se la ricompensa e' ancora dietro a un prerequisito della rete.
signal achievement_reached(achievement_id: String, claimable_now: bool)
signal achievement_claimable(achievement_id: String)
signal achievement_claimed(achievement_id: String, reward_label: String)

const ACHIEVEMENTS := [
	# Contratti scientifici eseguibili a piedi: danno capitale fin dal primo
	# minuto, senza cupola, macchinari o rete elettrica.
	{
		"id": "first_field_sample", "title": "PRIMA PIETRA", "icon": "●", "color": Color("e9b57b"),
		"description": "Raccogli a piedi il primo campione dalla superficie.", "target": 1,
		"prerequisites": [],
		"reward": {"funds": 120_000_000, "label": "+ $120 MLN · borsa di ricognizione"},
	},
	{
		"id": "field_notes", "title": "TACCUINO DI CAMPO", "icon": "≣", "color": Color("e7c489"),
		"description": "Raccogli 3 campioni a piedi.", "target": 3,
		"prerequisites": ["first_field_sample"],
		"reward": {"funds": 220_000_000, "label": "+ $220 MLN · note di terreno"},
	},
	{
		"id": "sample_satchel", "title": "SACCA CAMPIONI", "icon": "▰", "color": Color("d7a96d"),
		"description": "Raccogli 8 campioni a piedi.", "target": 8,
		"prerequisites": ["field_notes"],
		"reward": {"funds": 420_000_000, "item_id": "field_camera", "label": "+ $420 MLN · contratto di raccolta + telecamera"},
	},
	{
		"id": "surface_catalog", "title": "CATALOGO DI SUPERFICIE", "icon": "◫", "color": Color("f1cd91"),
		"description": "Raccogli 3 tipi differenti di roccia a piedi.", "target": 3,
		"prerequisites": ["field_notes"],
		"reward": {"funds": 600_000_000, "label": "+ $600 MLN · catalogo minerale"},
	},
	{
		"id": "surface_anomaly", "title": "LUCE NELLA POLVERE", "icon": "✧", "color": Color("ffcf6e"),
		"description": "Raccogli a piedi un campione raro in superficie.", "target": 1,
		"prerequisites": ["field_notes"],
		"reward": {"funds": 900_000_000, "label": "+ $900 MLN · premio anomalia"},
	},
	{
		"id": "first_horizon", "title": "ORIZZONTE APERTO", "icon": "⌁", "color": Color("81d8ff"),
		"description": "Esplora il primo bioma marziano.", "target": 1,
		"prerequisites": [],
		"reward": {"funds": 100_000_000, "label": "+ $100 MLN · telemetria iniziale"},
	},
	{
		"id": "biome_survey", "title": "TRE COLORI DI MARTE", "icon": "◌", "color": Color("8ecfff"),
		"description": "Esplora 3 biomi distinti.", "target": 3,
		"prerequisites": ["first_horizon"],
		"reward": {"funds": 350_000_000, "label": "+ $350 MLN · rilievo regionale"},
	},
	{
		"id": "long_range_survey", "title": "LINEA DI ORIZZONTE", "icon": "⇢", "color": Color("87b8f8"),
		"description": "Esplora 5 biomi distinti.", "target": 5,
		"prerequisites": ["biome_survey"],
		"reward": {"funds": 800_000_000, "label": "+ $800 MLN · rotta di esplorazione"},
	},
	{
		"id": "exploration_suit", "title": "EVA OLTRE L'ORIZZONTE", "icon": "◈", "color": Color("a9f0c0"),
		"description": "Acquista una tuta EVA più potente della tuta standard: rinforzata, Explorer o Storm.", "target": 1,
		"prerequisites": ["long_range_survey"],
		"reward": {"funds": 500_000_000, "label": "+ $500 MLN · protocollo esplorazione EVA"},
	},
	{
		"id": "polar_expedition", "title": "SPEDIZIONE POLARE", "icon": "❄", "color": Color("a8f3ff"),
		"description": "Raggiungi ed esplora il ghiaccio polare.", "target": 1,
		"prerequisites": ["biome_survey"],
		"reward": {"funds": 1_100_000_000, "label": "+ $1,1 MLD · mandato criosfera"},
	},
	# Archivio fotografico: sono contratti civili e scientifici eseguibili già
	# con la telecamera di campo. Nessuno richiede una rete elettrica.
	{
		"id": "first_photo", "title": "PRIMO SCATTO", "icon": "▣", "color": Color("86e6f7"),
		"description": "Trasmetti alla Terra la prima fotografia scientifica.", "target": 1,
		"prerequisites": ["sample_satchel"],
		"reward": {"funds": 150_000_000, "label": "+ $150 MLN · primo segnale visivo"},
	},
	{
		"id": "contact_sheet", "title": "PROVINO MARZIANO", "icon": "▤", "color": Color("9adcf0"),
		"description": "Trasmetti 3 fotografie di campo.", "target": 3,
		"prerequisites": ["first_photo"],
		"reward": {"funds": 260_000_000, "label": "+ $260 MLN · rivista esplorativa"},
	},
	{
		"id": "mars_postcard", "title": "CARTOLINE DA MARTE", "icon": "✉", "color": Color("b4f1ff"),
		"description": "Trasmetti 8 fotografie al centro missione.", "target": 8,
		"prerequisites": ["contact_sheet"],
		"reward": {"funds": 720_000_000, "label": "+ $720 MLN · licenza archivio immagini"},
	},
	{
		"id": "field_portrait", "title": "RITRATTO MINERALE", "icon": "◆", "color": Color("efc58e"),
		"description": "Fotografa e trasmetti una roccia raccolta sul terreno.", "target": 1,
		"prerequisites": ["first_photo"],
		"reward": {"funds": 240_000_000, "label": "+ $240 MLN · catalogo di superficie"},
	},
	{
		"id": "rare_lens", "title": "LENTE SULL'ANOMALIA", "icon": "✧", "color": Color("ffe379"),
		"description": "Trasmetti il ritratto di un campione raro o ultra-raro.", "target": 1,
		"prerequisites": ["field_portrait"],
		"reward": {"funds": 750_000_000, "label": "+ $750 MLN · premio immagine anomala"},
	},
	{
		"id": "biome_gallery", "title": "GALLERIA DI BIOMI", "icon": "◌", "color": Color("83d5ff"),
		"description": "Invia fotografie da 3 biomi differenti.", "target": 3,
		"prerequisites": ["first_photo"],
		"reward": {"funds": 360_000_000, "label": "+ $360 MLN · atlante fotografico"},
	},
	{
		"id": "six_horizons", "title": "SEI ORIZZONTI", "icon": "⌁", "color": Color("77c9ff"),
		"description": "Invia almeno una fotografia da tutti e 6 i biomi.", "target": 6,
		"prerequisites": ["biome_gallery"],
		"reward": {"funds": 1_200_000_000, "label": "+ $1,2 MLD · atlante visivo di Marte"},
	},
	{
		"id": "dawn_ice", "title": "GHIACCIO ALL'ALBA", "icon": "☼", "color": Color("d3f7ff"),
		"description": "Fotografa il bordo o il nucleo polare durante l'alba.", "target": 1,
		"prerequisites": ["biome_gallery"],
		"reward": {"funds": 520_000_000, "label": "+ $520 MLN · osservazione criosferica"},
	},
	{
		"id": "polar_light", "title": "LUCE POLARE", "icon": "❄", "color": Color("b5f5ff"),
		"description": "Trasmetti una fotografia dal nucleo polare.", "target": 1,
		"prerequisites": ["polar_expedition", "biome_gallery"],
		"reward": {"funds": 1_050_000_000, "label": "+ $1,05 MLD · dossier calotta"},
	},
	{
		"id": "night_sky", "title": "CIELO NOTTURNO MARZIANO", "icon": "✦", "color": Color("c7b4ff"),
		"description": "Trasmetti una fotografia notturna dalla superficie.", "target": 1,
		"prerequisites": ["first_photo"],
		"reward": {"funds": 430_000_000, "label": "+ $430 MLN · osservazione astronomica"},
	},
	{
		"id": "outpost_portrait", "title": "PRIMO AVAMPOSTO", "icon": "⌂", "color": Color("a5e4e9"),
		"description": "Fotografa una cupola abitativa dall'esterno.", "target": 1,
		"prerequisites": ["first_base", "first_photo"],
		"reward": {"funds": 610_000_000, "label": "+ $610 MLN · cronaca della colonia"},
	},
	{
		"id": "greenhouse_window", "title": "VETRO E CLOROFILLA", "icon": "♧", "color": Color("a4ec9d"),
		"description": "Trasmetti una fotografia della serra operativa.", "target": 1,
		"prerequisites": ["greenhouse", "first_photo"],
		"reward": {"funds": 800_000_000, "label": "+ $800 MLN · programma agricoltura visiva"},
	},
	{
		"id": "lab_in_frame", "title": "SCIENZA IN CAMPO", "icon": "⚗", "color": Color("c7cbff"),
		"description": "Trasmetti la fotografia di un laboratorio installato.", "target": 1,
		"prerequisites": ["first_lab", "first_photo"],
		"reward": {"funds": 950_000_000, "label": "+ $950 MLN · documentazione strumentale"},
	},
	{
		"id": "primordial_frost_photo", "title": "TEMPO NEL GHIACCIO", "icon": "◈", "color": Color("c5f4ff"),
		"description": "Trasmetti una foto mentre custodisci il ghiaccio profondo primordiale.", "target": 1,
		"prerequisites": ["primordial_ice", "first_photo"],
		"reward": {"funds": 2_000_000_000, "label": "+ $2 MLD · archivio criogenico"},
	},
	{
		"id": "life_witness_image", "title": "TESTIMONE DELLA VITA", "icon": "✺", "color": Color("84ffd2"),
		"description": "Fotografa il laboratorio dopo aver rilevato un segnale compatibile con una possibile biosignatura.", "target": 1,
		"prerequisites": ["ancient_life", "lab_in_frame"],
		"reward": {"funds": 4_000_000_000, "badge": "OCCHIO DI MARTE", "label": "+ $4 MLD · immagine storica"},
	},
	{
		"id": "first_base", "title": "PRIMA BASE", "icon": "⌂", "color": Color("70c8ff"),
		"description": "Posiziona la prima cupola abitativa.", "target": 1,
		"prerequisites": [],
		"reward": {"funds": 150_000_000, "label": "+ $150 MLN"},
	},
	{
		"id": "airlock_cycle", "title": "ACCESSO SICURO", "icon": "⇄", "color": Color("9cc8ff"),
		"description": "Completa un ciclo della camera di decompressione.", "target": 1,
		"prerequisites": ["first_base"],
		"reward": {"badge": "COLONO MARZIANO", "label": "Badge: Colono marziano"},
	},
	{
		"id": "stable_grid", "title": "RETE ELETTRICA", "icon": "ϟ", "color": Color("ffe079"),
		"description": "Rendi operativa la rete con pannelli, trasformatore e batteria.", "target": 1,
		"prerequisites": ["first_base"],
		"reward": {"funds": 150_000_000, "label": "+ $150 MLN"},
	},
	{
		"id": "ice_drill", "title": "PRIMA TRIVELLA", "icon": "⌄", "color": Color("6de8ff"),
		"description": "Posiziona una trivella del ghiaccio.", "target": 1,
		"prerequisites": ["airlock_cycle", "stable_grid"],
		"reward": {"funds": 100_000_000, "label": "+ $100 MLN"},
	},
	{
		"id": "refill_bottle", "title": "BORRACCIA RICARICATA", "icon": "◒", "color": Color("73dfff"),
		"description": "Riempi una borraccia usando la riserva d'acqua della trivella.", "target": 1,
		"prerequisites": ["ice_drill"],
		"reward": {"effect": "water_efficiency", "label": "Consumo acqua -10%"},
	},
	{
		"id": "greenhouse", "title": "SERRA OPERATIVA", "icon": "♧", "color": Color("89e89a"),
		"description": "Collega una serra a una sorgente d'acqua.", "target": 1,
		"prerequisites": ["stable_grid"],
		"reward": {"funds": 200_000_000, "label": "+ $200 MLN"},
	},
	{
		"id": "first_planting", "title": "PRIMA PIANTAGIONE", "icon": "✦", "color": Color("9ce66f"),
		"description": "Pianta il primo lotto di patate.", "target": 1,
		"prerequisites": ["greenhouse"],
		"reward": {"effect": "crop_efficiency", "label": "Crescita colture +5%"},
	},
	{
		"id": "first_harvest", "title": "PRIMO RACCOLTO", "icon": "▣", "color": Color("e8c45b"),
		"description": "Raccogli il primo lotto di 4 o 5 razioni.", "target": 1,
		"prerequisites": ["first_planting"],
		"reward": {"funds": 300_000_000, "label": "+ $300 MLN"},
	},
	{
		"id": "genetic_modification", "title": "PATATE GM", "icon": "✿", "color": Color("b5ef87"),
		"description": "Modifica geneticamente i semi di patate nello shop.", "target": 1,
		"prerequisites": ["first_harvest", "perseverance_repair"],
		"reward": {"funds": 300_000_000, "label": "+ $300 MLN · programma semi GM"},
	},
	{
		"id": "genetic_replacement", "title": "RACCOLTO MIGLIORATO", "icon": "↻", "color": Color("9de47f"),
		"description": "Sostituisci in serra un lotto con semi GM più potenti.", "target": 1,
		"prerequisites": ["genetic_modification"],
		"reward": {"funds": 450_000_000, "label": "+ $450 MLN · selezione del raccolto"},
	},
	# La missione Perseverance è una sola catena narrativa: fotografare,
	# documentare e riparare lo stesso rover completa tutti e tre i contratti.
	# Nessun obiettivo richiede di aspettare il guasto di un secondo rover.
	{
		"id": "perseverance_photo", "title": "SEGNALE DA PERSEVERANCE", "icon": "◉", "color": Color("f2ba72"),
		"description": "Fotografa e trasmetti alla Terra il rover Perseverance danneggiato.", "target": 1,
		"prerequisites": ["first_photo"],
		"reward": {"funds": 700_000_000, "label": "+ $700 MLN · telemetria rover"},
	},
	{
		"id": "perseverance_report", "title": "DIAGNOSI A DISTANZA", "icon": "≣", "color": Color("f0d29a"),
		"description": "Studia e invia alla Terra il rapporto danni di Perseverance.", "target": 1,
		"prerequisites": ["perseverance_photo"],
		"reward": {"funds": 1_100_000_000, "label": "+ $1,1 MLD · rapporto firmato"},
	},
	{
		"id": "perseverance_repair", "title": "EREDITÀ OPERATIVA", "icon": "✦", "color": Color("8ae7d4"),
		"description": "Completa la sequenza di manutenzione e ripara Perseverance.", "target": 1,
		"prerequisites": ["perseverance_report"],
		"reward": {"funds": 1_750_000_000, "effect": "genetic_seed_access", "label": "+ $1,75 MLD · accesso bioingegneria"},
	},
	# La ricerca non è un traguardo decorativo: è il principale programma di
	# finanziamento della prima metà della missione. I rapporti pagano ogni volta;
	# questi contratti una tantum premiano invece la qualità e la varietà dei dati.
	{
		"id": "first_lab", "title": "PRIMO LABORATORIO", "icon": "⚗", "color": Color("a4baff"),
		"description": "Installa il primo strumento scientifico in una cupola abitativa.", "target": 1,
		"prerequisites": ["stable_grid"],
		"reward": {"funds": 250_000_000, "label": "+ $250 MLN · borsa di avvio"},
	},
	{
		"id": "first_extraction", "title": "CAMPIONAMENTO GEOLOGICO", "icon": "⧁", "color": Color("e8aa65"),
		"description": "Metti in funzione la prima trivella per rocce.", "target": 1,
		"prerequisites": ["ice_drill", "first_lab"],
		"reward": {"funds": 350_000_000, "label": "+ $350 MLN · mandato geologico"},
	},
	{
		"id": "polar_drill", "title": "CAMPIONAMENTO POLARE", "icon": "❄", "color": Color("a8f3ff"),
		"description": "Posiziona una trivella mineraria nel bioma del ghiaccio polare.", "target": 1,
		"prerequisites": ["polar_expedition", "first_extraction"],
		"reward": {"funds": 1_800_000_000, "label": "+ $1,8 MLD · sovvenzione polare"},
	},
	{
		"id": "primordial_ice", "title": "CAMPIONE DI GHIACCIO PROFONDO", "icon": "◆", "color": Color("b7f4ff"),
		"description": "Trova con la trivella un raro campione di ghiaccio profondo nel modello di gioco.", "target": 1,
		"prerequisites": ["polar_drill"],
		"reward": {"funds": 3_000_000_000, "label": "+ $3 MLD · custodia criogenica"},
	},
	{
		"id": "deep_ice_study", "title": "STUDIO DEGLI STRATI PROFONDI", "icon": "◈", "color": Color("bde8ff"),
		"description": "Avvia lo studio di un campione di ghiaccio profondo in un laboratorio.", "target": 1,
		"prerequisites": ["primordial_ice", "first_lab"],
		"reward": {"funds": 4_500_000_000, "label": "+ $4,5 MLD · protocollo di bioscavo"},
	},
	{
		"id": "ancient_life", "title": "SEGNALE COMPATIBILE", "icon": "✺", "color": Color("7fffd4"),
		"description": "Rileva un segnale compatibile con una biosignatura nel ghiaccio profondo. Le percentuali sono una meccanica di gioco, non una probabilità scientifica validata.", "target": 1,
		"prerequisites": ["deep_ice_study"],
		"reward": {"funds": 15_000_000_000, "badge": "SCOPRITORE DI VITA", "label": "+ $15 MLD · scopritore di vita"},
	},
	{
		"id": "life_relay", "title": "MESSAGGIO DA VERIFICARE", "icon": "✦", "color": Color("f6ffad"),
		"description": "Trasmetti alla Terra il primo segnale compatibile con una possibile biosignatura marziana; non è una prova definitiva di vita.", "target": 1,
		"prerequisites": ["ancient_life"],
		"reward": {"funds": 25_000_000_000, "effect": "life_patent", "badge": "MESSAGGERO DI MARTE", "label": "+ $25 MLD · messaggero di Marte"},
	},
	# Ritorno campioni: questa è la conclusione della spedizione. I contratti
	# registrano i passaggi, ma il manifesto e il lancio restano azioni fisiche
	# eseguite dal giocatore accanto al razzo.
	{
		"id": "life_sample_secured", "title": "CAMPIONE BIOLOGICO", "icon": "✺", "color": Color("80ffcf"),
		"description": "Metti in sicurezza il campione di vita aliena nel contenitore di vetro per il ritorno alla Terra.", "target": 1,
		"prerequisites": ["ancient_life"],
		"reward": {"funds": 5_000_000_000, "label": "+ $5 MLD · protocollo di contenimento"},
	},
	{
		"id": "return_manifest", "title": "MANIFESTO GEOLOGICO", "icon": "▤", "color": Color("d8e9f2"),
		"description": "Carica nel razzo un campione per ogni roccia disponibile nel gioco e il campione biologico. La tab Ritorno elenca bioma e rarità di tutti i campioni.", "target": 1,
		"prerequisites": ["life_sample_secured"],
		"reward": {"funds": 8_000_000_000, "label": "+ $8 MLD · catena di custodia interplanetaria"},
	},
	{
		"id": "sabatier_online", "title": "PROPELLENTE MARZIANO", "icon": "ϟ", "color": Color("ffb86d"),
		"description": "Posiziona accanto al razzo e rendi produttivo il reattore Sabatier: corrente e tubo H₂ devono essere collegati.", "target": 1,
		"prerequisites": ["life_relay", "stable_grid", "first_extraction"],
		"reward": {"funds": 4_000_000_000, "label": "+ $4 MLD · impianto di propellente"},
	},
	{
		"id": "rocket_fueled", "title": "SERBATOIO PIENO", "icon": "▲", "color": Color("ffe079"),
		"description": "Riempi il serbatoio del razzo con 400 kg di metano prodotti dal Sabatier.", "target": 1,
		"prerequisites": ["sabatier_online"],
		"reward": {"funds": 6_000_000_000, "label": "+ $6 MLD · finestra di lancio"},
	},
	{
		"id": "return_launch", "title": "RITORNO ALLA TERRA", "icon": "▲", "color": Color("fff0a2"),
		"description": "Avvia il razzo con il manifesto completo e il serbatoio pieno: i campioni di Marte sono in viaggio verso la Terra.", "target": 1,
		"prerequisites": ["return_manifest", "rocket_fueled"],
		"reward": {"funds": 20_000_000_000, "badge": "RITORNO DA MARTE", "label": "MISSIONE COMPLETATA · campioni in viaggio"},
	},
	{
		"id": "first_report", "title": "SEGNALE DA MARTE", "icon": "▤", "color": Color("79d9ff"),
		"description": "Trasmetti alla Terra il primo rapporto scientifico.", "target": 1,
		"prerequisites": ["first_lab"],
		"reward": {"funds": 400_000_000, "effect": "research_bonus", "label": "+ $400 MLN · ricavi ricerca +10%"},
	},
	{
		"id": "chain_of_custody", "title": "CATENA DI CUSTODIA", "icon": "≡", "color": Color("7ebde9"),
		"description": "Invia 3 rapporti verificati alla Terra.", "target": 3,
		"prerequisites": ["first_report"],
		"reward": {"funds": 550_000_000, "label": "+ $550 MLN · contratto di analisi"},
	},
	{
		"id": "xrd_fieldwork", "title": "RETICOLI RIVELATI", "icon": "X", "color": Color("ffaf73"),
		"description": "Completa 3 rapporti con il diffrattometro XRD.", "target": 3,
		"prerequisites": ["first_report"],
		"reward": {"funds": 650_000_000, "effect": "xrd_precision", "label": "+ $650 MLN · valore XRD +15%"},
	},
	{
		"id": "raman_fieldwork", "title": "IMPRONTE LUMINOSE", "icon": "R", "color": Color("d48cff"),
		"description": "Completa 3 rapporti con lo spettrometro Raman.", "target": 3,
		"prerequisites": ["first_report"],
		"reward": {"funds": 800_000_000, "effect": "raman_precision", "label": "+ $800 MLN · valore Raman +15%"},
	},
	{
		"id": "icp_fieldwork", "title": "TRACCE NEL PLASMA", "icon": "I", "color": Color("72efd3"),
		"description": "Completa 3 rapporti con l'ICP-MS.", "target": 3,
		"prerequisites": ["chain_of_custody"],
		"reward": {"funds": 1_000_000_000, "effect": "icp_precision", "label": "+ $1 MLD · valore ICP-MS +15%"},
	},
	{
		"id": "rare_signal", "title": "SEGNALE ANOMALO", "icon": "✦", "color": Color("ffe079"),
		"description": "Analizza e trasmetti il primo campione raro.", "target": 1,
		"prerequisites": ["first_extraction", "first_report"],
		"reward": {"funds": 1_100_000_000, "label": "+ $1,1 MLD · premio per anomalia"},
	},
	{
		"id": "regional_atlas", "title": "ATLANTE DI ARES", "icon": "⊕", "color": Color("9ed6ff"),
		"description": "Consegna dati da 3 biomi marziani distinti.", "target": 3,
		"prerequisites": ["first_extraction", "chain_of_custody"],
		"reward": {"funds": 1_250_000_000, "effect": "diversity_bonus", "label": "+ $1,25 MLD · dati multi-bioma +10%"},
	},
	{
		"id": "data_convoy", "title": "CONVOGLIO DATI", "icon": "⇑", "color": Color("8be5ff"),
		"description": "Trasmetti 8 rapporti scientifici in totale.", "target": 8,
		"prerequisites": ["chain_of_custody"],
		"reward": {"funds": 1_400_000_000, "label": "+ $1,4 MLD · patrocinio Terra"},
	},
	{
		"id": "xrd_master", "title": "XRD DI PRECISIONE", "icon": "X+", "color": Color("ffaf73"),
		"description": "Porta il diffrattometro XRD al livello 5.", "target": 1,
		"prerequisites": ["xrd_fieldwork"],
		"reward": {"funds": 1_000_000_000, "label": "+ $1 MLD · brevetto cristallografico"},
	},
	{
		"id": "raman_master", "title": "RAMAN DI PRECISIONE", "icon": "R+", "color": Color("d48cff"),
		"description": "Porta lo spettrometro Raman al livello 5.", "target": 1,
		"prerequisites": ["raman_fieldwork"],
		"reward": {"funds": 1_250_000_000, "label": "+ $1,25 MLD · brevetto spettroscopico"},
	},
	{
		"id": "icp_master", "title": "ICP-MS DI PRECISIONE", "icon": "I+", "color": Color("72efd3"),
		"description": "Porta l'ICP-MS al livello 5.", "target": 1,
		"prerequisites": ["icp_fieldwork"],
		"reward": {"funds": 1_600_000_000, "label": "+ $1,6 MLD · brevetto elementare"},
	},
	{
		"id": "rare_constellation", "title": "COSTELLAZIONE RARA", "icon": "★", "color": Color("ffd86b"),
		"description": "Trasmetti 3 campioni rari, anche da biomi diversi.", "target": 3,
		"prerequisites": ["rare_signal", "raman_fieldwork"],
		"reward": {"funds": 1_900_000_000, "effect": "rare_premium", "label": "+ $1,9 MLD · campioni rari +25%"},
	},
	{
		"id": "earth_relay", "title": "PONTE TERRA", "icon": "⇈", "color": Color("76e7d0"),
		"description": "Trasmetti 15 rapporti scientifici in totale.", "target": 15,
		"prerequisites": ["data_convoy", "icp_fieldwork"],
		"reward": {"funds": 2_500_000_000, "effect": "transmission_priority", "label": "+ $2,5 MLD · valore rapporti +15%"},
	},
	{
		"id": "planetary_archive", "title": "ARCHIVIO PLANETARIO", "icon": "◉", "color": Color("b5a0ff"),
		"description": "Completa l'atlante con dati da tutti e 6 i biomi.", "target": 6,
		"prerequisites": ["regional_atlas", "rare_signal"],
		"reward": {"funds": 3_000_000_000, "label": "+ $3 MLD · mandato di cartografia"},
	},
	{
		"id": "science_center", "title": "DIRETTORATO SCIENTIFICO", "icon": "★", "color": Color("ffe36e"),
		"description": "Unisci tre laboratori calibrati, il ponte Terra e l'archivio planetario.", "target": 1,
		"prerequisites": ["xrd_master", "raman_master", "icp_master", "earth_relay", "planetary_archive"],
		"reward": {"funds": 4_000_000_000, "effect": "scientific_director", "badge": "DIRETTORE SCIENTIFICO", "label": "+ $4 MLD · direttore scientifico"},
	},
	{
		"id": "martian_dividend", "title": "DIVIDENDO MARZIANO", "icon": "✦", "color": Color("fff0a2"),
		"description": "Consegna 24 rapporti: la ricerca finanzia la nuova economia della colonia.", "target": 24,
		"prerequisites": ["science_center", "rare_constellation"],
		"reward": {"funds": 6_000_000_000, "badge": "PIONIERE DEL VALORE", "label": "+ $6 MLD · pioniere del valore"},
	},
]

var _progress: Dictionary = {}
var _claimed: Dictionary = {}
var _badges: Dictionary = {}
var _effects: Dictionary = {}
var _reported_biomes: Dictionary = {}
var _field_rock_variants: Dictionary = {}
var _explored_sources: Dictionary = {}
var _photographed_sources: Dictionary = {}
var is_board_open := false


func _ready() -> void:
	_reset_session_state()


func get_ordered_definitions() -> Array:
	return ACHIEVEMENTS.duplicate(true)


func get_definition(achievement_id: String) -> Dictionary:
	for definition in ACHIEVEMENTS:
		if str(definition.get("id", "")) == achievement_id:
			return definition.duplicate(true)
	return {}


func get_progress(achievement_id: String) -> int:
	return int(_progress.get(achievement_id, 0))


func get_target(achievement_id: String) -> int:
	return int(get_definition(achievement_id).get("target", 1))


func get_prerequisites(achievement_id: String) -> Array[String]:
	var prerequisites: Array[String] = []
	var raw_prerequisites: Array = get_definition(achievement_id).get("prerequisites", [])
	for prerequisite in raw_prerequisites:
		var prerequisite_id := str(prerequisite)
		if not prerequisite_id.is_empty():
			prerequisites.append(prerequisite_id)
	return prerequisites


func get_dependent_ids(achievement_id: String) -> Array[String]:
	var children: Array[String] = []
	for definition in ACHIEVEMENTS:
		var child_id := str(definition.get("id", ""))
		if achievement_id in get_prerequisites(child_id):
			children.append(child_id)
	return children


func is_reached(achievement_id: String) -> bool:
	return get_progress(achievement_id) >= get_target(achievement_id)


func is_claimed(achievement_id: String) -> bool:
	return bool(_claimed.get(achievement_id, false))


func is_unlocked(achievement_id: String) -> bool:
	if get_definition(achievement_id).is_empty():
		return false
	for prerequisite_id in get_prerequisites(achievement_id):
		if not is_claimed(prerequisite_id):
			return false
	return true


func is_claimable(achievement_id: String) -> bool:
	return is_unlocked(achievement_id) and is_reached(achievement_id) and not is_claimed(achievement_id)


func get_status(achievement_id: String) -> String:
	if not is_unlocked(achievement_id):
		return "locked"
	if is_claimable(achievement_id):
		return "claimable"
	if is_claimed(achievement_id):
		return "claimed"
	return "available"


func record(achievement_id: String, amount: int = 1) -> bool:
	var definition := get_definition(achievement_id)
	if definition.is_empty() or amount <= 0:
		return false
	var old_progress := get_progress(achievement_id)
	var target := get_target(achievement_id)
	var new_progress := mini(target, old_progress + amount)
	if new_progress == old_progress:
		return false
	_progress[achievement_id] = new_progress
	_refresh_composite_achievements()
	_save_progress()
	achievement_updated.emit(achievement_id)
	if old_progress < target and new_progress >= target:
		achievement_reached.emit(achievement_id, is_claimable(achievement_id))
	if is_claimable(achievement_id):
		achievement_claimable.emit(achievement_id)
	return true


func set_reached(achievement_id: String) -> bool:
	var target := get_target(achievement_id)
	var missing := target - get_progress(achievement_id)
	return record(achievement_id, missing) if missing > 0 else false


func claim(achievement_id: String) -> bool:
	var ui_state := get_node_or_null("/root/UIState")
	if ui_state != null and bool(ui_state.call("has_open_modal")) and not bool(ui_state.call("is_modal_active", &"achievements")):
		return false
	if not is_claimable(achievement_id):
		return false
	var definition := get_definition(achievement_id)
	var reward: Dictionary = definition.get("reward", {})
	_claimed[achievement_id] = true
	var funds := int(reward.get("funds", 0))
	if funds > 0 and is_inside_tree():
		var economy := get_node_or_null("/root/Economy")
		if economy != null:
			economy.call("add_funds", funds)
	var badge := str(reward.get("badge", ""))
	if not badge.is_empty():
		_badges[badge] = true
	var effect := str(reward.get("effect", ""))
	if not effect.is_empty():
		_effects[effect] = true
	var item_id := str(reward.get("item_id", ""))
	if item_id == "field_camera" and is_inside_tree():
		var inventory := get_node_or_null("/root/Inventory")
		if inventory != null and inventory.has_method("grant_field_camera"):
			if not bool(inventory.call("grant_field_camera")):
				push_warning("Ricompensa telecamera in attesa: libera uno slot dello zaino.")
	_save_progress()
	achievement_updated.emit(achievement_id)
	for child_id in get_dependent_ids(achievement_id):
		achievement_updated.emit(child_id)
		if is_claimable(child_id):
			achievement_claimable.emit(child_id)
	achievement_claimed.emit(achievement_id, str(reward.get("label", "Ricompensa riscattata")))
	return true


func get_water_loss_multiplier() -> float:
	return 0.90 if has_effect("water_efficiency") else 1.0


func get_crop_growth_multiplier() -> float:
	return 1.05 if has_effect("crop_efficiency") else 1.0


func get_research_reward_multiplier(machine_id: String = "", rarity: String = "") -> float:
	var multiplier := 1.0
	if has_effect("research_bonus"):
		multiplier *= 1.10
	if has_effect("diversity_bonus"):
		multiplier *= 1.10
	if has_effect("transmission_priority"):
		multiplier *= 1.15
	if has_effect("scientific_director"):
		multiplier *= 1.20
	if has_effect("life_patent"):
		multiplier *= 1.25
	if rarity in ["rare", "ultra_rare"] and has_effect("rare_premium"):
		multiplier *= 1.25
	match machine_id:
		"xrd_diffractometer":
			if has_effect("xrd_precision"):
				multiplier *= 1.15
		"raman_spectrometer":
			if has_effect("raman_precision"):
				multiplier *= 1.15
		"icp_ms":
			if has_effect("icp_precision"):
				multiplier *= 1.15
	return multiplier


func record_research_report(machine_id: String, _sample_id: String, biome: String, rarity: String) -> void:
	# Ogni rapporto alimenta più contratti in parallelo. Anche quando un contratto
	# è ancora bloccato il suo avanzamento resta visibile nel grafo.
	record("first_report")
	record("chain_of_custody")
	record("data_convoy")
	record("earth_relay")
	record("martian_dividend")
	match machine_id:
		"xrd_diffractometer":
			record("xrd_fieldwork")
		"raman_spectrometer":
			record("raman_fieldwork")
		"icp_ms":
			record("icp_fieldwork")
	if rarity in ["rare", "ultra_rare"]:
		record("rare_signal")
		record("rare_constellation")
	var cleaned_biome := biome.strip_edges()
	if not cleaned_biome.is_empty() and not _reported_biomes.has(cleaned_biome):
		_reported_biomes[cleaned_biome] = true
		record("regional_atlas")
		record("planetary_archive")


func record_field_sample(rock_variant: String, rarity: String = "common") -> void:
	# Questi sono contratti senza infrastruttura: una roccia raccolta a piedi vale
	# già dati per Terra e permette di finanziare il primo vero impianto.
	record("first_field_sample")
	record("field_notes")
	record("sample_satchel")
	var cleaned_variant := rock_variant.strip_edges()
	if not cleaned_variant.is_empty() and not _field_rock_variants.has(cleaned_variant):
		_field_rock_variants[cleaned_variant] = true
		record("surface_catalog")
	if rarity == "rare" or rarity == "ultra_rare":
		record("surface_anomaly")


func record_exploration_source(source_id: int) -> void:
	if source_id < 0 or _explored_sources.has(source_id):
		return
	_explored_sources[source_id] = true
	record("first_horizon")
	record("biome_survey")
	record("long_range_survey")
	if source_id == 4:
		record("polar_expedition")


func record_photo_transmission(photo: Dictionary) -> void:
	## I contratti fotografici avanzano soltanto quando lo scatto parte davvero
	## verso la Terra. Scattare senza inviare riempie il rullino, ma non genera
	## denaro né progresso fittizio.
	if photo.is_empty():
		return
	record("first_photo")
	record("contact_sheet")
	record("mars_postcard")
	var source_id := int(photo.get("source_id", -1))
	if source_id >= 0 and not _photographed_sources.has(source_id):
		_photographed_sources[source_id] = true
		record("biome_gallery")
		record("six_horizons")
	var tags: Array = photo.get("tags", [])
	if "rock" in tags:
		record("field_portrait")
	if "rare_rock" in tags:
		record("rare_lens")
	if "dawn_ice" in tags:
		record("dawn_ice")
	if "polar" in tags:
		record("polar_light")
	if "night_sky" in tags:
		record("night_sky")
	if "base" in tags:
		record("outpost_portrait")
	if "greenhouse" in tags:
		record("greenhouse_window")
	if "laboratory" in tags:
		record("lab_in_frame")
	if "primordial_ice" in tags:
		record("primordial_frost_photo")
	if "life_evidence" in tags:
		record("life_witness_image")


func record_polar_drill() -> void:
	record("polar_drill")


func record_primordial_ice_found() -> void:
	record("primordial_ice")


func record_deep_ice_study() -> void:
	record("deep_ice_study")


func record_ancient_life_discovery() -> void:
	# La prova viene scoperta e trasmessa dal medesimo rapporto. La seconda
	# ricompensa resta incatenata: appare pronta, ma richiede prima il claim
	# della scoperta scientifica.
	record("ancient_life")
	record("life_relay")
	var inventory := get_node_or_null("/root/Inventory")
	if inventory != null and inventory.has_method("add_alien_life_sample") and bool(inventory.call("add_alien_life_sample")):
		record("life_sample_secured")


func get_research_contract_summary(machine_id: String) -> String:
	# Sintesi breve per il pannello vicino al laboratorio: mostra al giocatore
	# quale contratto economico sta finanziando prima di consegnare un campione.
	var contract_ids: Array[String] = ["chain_of_custody", "data_convoy", "earth_relay"]
	match machine_id:
		"xrd_diffractometer":
			contract_ids.push_front("xrd_fieldwork")
		"raman_spectrometer":
			contract_ids.push_front("raman_fieldwork")
		"icp_ms":
			contract_ids.push_front("icp_fieldwork")
	var parts: Array[String] = []
	for contract_id in contract_ids:
		var definition := get_definition(contract_id)
		var short_title := str(definition.get("title", contract_id)).capitalize()
		parts.append("%s %d/%d" % [short_title, get_progress(contract_id), get_target(contract_id)])
	return " · ".join(parts)


func has_effect(effect_id: String) -> bool:
	return bool(_effects.get(effect_id, false))


func has_badge(badge_id: String) -> bool:
	return bool(_badges.get(badge_id, false))


func set_persistence_enabled_for_test(enabled: bool) -> void:
	# Gli achievement non sono persistenti per scelta di design. Manteniamo
	# questa API soltanto per compatibilità con i test esistenti.
	if enabled:
		push_warning("La persistenza degli achievement è disabilitata: ogni avvio è una nuova missione.")


func reset_runtime_for_test() -> void:
	_reset_session_state()


func reset_for_new_mission() -> void:
	_reset_session_state()


func _reset_session_state() -> void:
	_progress.clear()
	_claimed.clear()
	_badges.clear()
	_effects.clear()
	_reported_biomes.clear()
	_field_rock_variants.clear()
	_explored_sources.clear()
	_photographed_sources.clear()
	is_board_open = false


func _refresh_composite_achievements() -> void:
	if is_reached("xrd_master") and is_reached("raman_master") and is_reached("icp_master") and is_reached("earth_relay") and is_reached("planetary_archive"):
		var center_old := get_progress("science_center")
		if center_old < get_target("science_center"):
			_progress["science_center"] = get_target("science_center")
			achievement_updated.emit("science_center")
			achievement_reached.emit("science_center", is_claimable("science_center"))
			if is_claimable("science_center"):
				achievement_claimable.emit("science_center")


func _save_progress() -> void:
	# Nessun salvataggio su disco: F5 / nuovo avvio deve sempre ripartire da zero.
	pass

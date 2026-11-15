extends Node

## Progression for one mission. Every new run starts from zero: objectives can
## advance before becoming available, while rewards are claimed according to
## the prerequisite graph.

signal achievement_updated(achievement_id: String)
## Emitted only once when progress reaches the target, even if the reward still
## sits behind a graph prerequisite.
signal achievement_reached(achievement_id: String, claimable_now: bool)
signal achievement_claimable(achievement_id: String)
signal achievement_claimed(achievement_id: String, reward_label: String)

const ACHIEVEMENTS := [
	# Scientific contracts that can be completed on foot. They provide capital from
	# the first minute without a dome, machinery, or electrical grid.
	{
		"id": "first_field_sample", "title": "FIRST ROCK", "icon": "●", "color": Color("e9b57b"),
		"description": "Collect your first surface sample on foot.", "target": 1,
		"prerequisites": [],
		"reward": {"funds": 120_000_000, "label": "+ $120 MN · reconnaissance grant"},
	},
	{
		"id": "field_notes", "title": "FIELD NOTES", "icon": "≣", "color": Color("e7c489"),
		"description": "Collect 3 samples on foot.", "target": 3,
		"prerequisites": ["first_field_sample"],
		"reward": {"funds": 220_000_000, "label": "+ $220 MN · terrain notes"},
	},
	{
		"id": "sample_satchel", "title": "SAMPLE SATCHEL", "icon": "▰", "color": Color("d7a96d"),
		"description": "Collect 8 samples on foot.", "target": 8,
		"prerequisites": ["field_notes"],
		"reward": {"funds": 420_000_000, "item_id": "field_camera", "label": "+ $420 MN · collection contract + camera"},
	},
	{
		"id": "surface_catalog", "title": "SURFACE CATALOG", "icon": "◫", "color": Color("f1cd91"),
		"description": "Collect 3 different rock types on foot.", "target": 3,
		"prerequisites": ["field_notes"],
		"reward": {"funds": 600_000_000, "label": "+ $600 MN · mineral catalog"},
	},
	{
		"id": "surface_anomaly", "title": "LIGHT IN THE DUST", "icon": "✧", "color": Color("ffcf6e"),
		"description": "Collect a rare surface sample on foot.", "target": 1,
		"prerequisites": ["field_notes"],
		"reward": {"funds": 900_000_000, "label": "+ $900 MN · anomaly award"},
	},
	{
		"id": "first_horizon", "title": "OPEN HORIZON", "icon": "⌁", "color": Color("81d8ff"),
		"description": "Explore your first Martian biome.", "target": 1,
		"prerequisites": [],
		"reward": {"funds": 100_000_000, "label": "+ $100 MN · initial telemetry"},
	},
	{
		"id": "biome_survey", "title": "THREE COLORS OF MARS", "icon": "◌", "color": Color("8ecfff"),
		"description": "Explore 3 distinct biomes.", "target": 3,
		"prerequisites": ["first_horizon"],
		"reward": {"funds": 350_000_000, "label": "+ $350 MN · regional survey"},
	},
	{
		"id": "long_range_survey", "title": "HORIZON LINE", "icon": "⇢", "color": Color("87b8f8"),
		"description": "Explore 5 distinct biomes.", "target": 5,
		"prerequisites": ["biome_survey"],
		"reward": {"funds": 800_000_000, "label": "+ $800 MN · exploration route"},
	},
	{
		"id": "exploration_suit", "title": "EVA BEYOND THE HORIZON", "icon": "◈", "color": Color("a9f0c0"),
		"description": "Buy an EVA suit more capable than the standard suit: Reinforced, Explorer, or Storm.", "target": 1,
		"prerequisites": ["long_range_survey"],
		"reward": {"funds": 500_000_000, "label": "+ $500 MN · EVA exploration protocol"},
	},
	{
		"id": "polar_expedition", "title": "POLAR EXPEDITION", "icon": "❄", "color": Color("a8f3ff"),
		"description": "Reach and explore the polar ice.", "target": 1,
		"prerequisites": ["biome_survey"],
		"reward": {"funds": 1_100_000_000, "label": "+ $1.1 BN · cryosphere mandate"},
	},
	# Photo archive: civilian and scientific contracts that work with the field
	# camera alone. None requires an electrical grid.
	{
		"id": "first_photo", "title": "FIRST SHOT", "icon": "▣", "color": Color("86e6f7"),
		"description": "Transmit your first scientific photograph to Earth.", "target": 1,
		"prerequisites": ["sample_satchel"],
		"reward": {"funds": 150_000_000, "label": "+ $150 MN · first visual signal"},
	},
	{
		"id": "contact_sheet", "title": "MARTIAN CONTACT SHEET", "icon": "▤", "color": Color("9adcf0"),
		"description": "Transmit 3 field photographs.", "target": 3,
		"prerequisites": ["first_photo"],
		"reward": {"funds": 260_000_000, "label": "+ $260 MN · exploration magazine"},
	},
	{
		"id": "mars_postcard", "title": "POSTCARDS FROM MARS", "icon": "✉", "color": Color("b4f1ff"),
		"description": "Transmit 8 photographs to mission control.", "target": 8,
		"prerequisites": ["contact_sheet"],
		"reward": {"funds": 720_000_000, "label": "+ $720 MN · image archive license"},
	},
	{
		"id": "field_portrait", "title": "MINERAL PORTRAIT", "icon": "◆", "color": Color("efc58e"),
		"description": "Photograph and transmit a rock collected on the ground.", "target": 1,
		"prerequisites": ["first_photo"],
		"reward": {"funds": 240_000_000, "label": "+ $240 MN · surface catalog"},
	},
	{
		"id": "rare_lens", "title": "LENS ON THE ANOMALY", "icon": "✧", "color": Color("ffe379"),
		"description": "Transmit a portrait of a rare or ultra-rare sample.", "target": 1,
		"prerequisites": ["field_portrait"],
		"reward": {"funds": 750_000_000, "label": "+ $750 MN · anomalous image award"},
	},
	{
		"id": "biome_gallery", "title": "BIOME GALLERY", "icon": "◌", "color": Color("83d5ff"),
		"description": "Send photographs from 3 different biomes.", "target": 3,
		"prerequisites": ["first_photo"],
		"reward": {"funds": 360_000_000, "label": "+ $360 MN · photo atlas"},
	},
	{
		"id": "six_horizons", "title": "SIX HORIZONS", "icon": "⌁", "color": Color("77c9ff"),
		"description": "Send at least one photograph from each of the 6 biomes.", "target": 6,
		"prerequisites": ["biome_gallery"],
		"reward": {"funds": 1_200_000_000, "label": "+ $1.2 BN · visual atlas of Mars"},
	},
	{
		"id": "dawn_ice", "title": "ICE AT DAWN", "icon": "☼", "color": Color("d3f7ff"),
		"description": "Photograph the ice-cap edge or polar core at dawn.", "target": 1,
		"prerequisites": ["biome_gallery"],
		"reward": {"funds": 520_000_000, "label": "+ $520 MN · cryosphere observation"},
	},
	{
		"id": "polar_light", "title": "POLAR LIGHT", "icon": "❄", "color": Color("b5f5ff"),
		"description": "Transmit a photograph from the polar core.", "target": 1,
		"prerequisites": ["polar_expedition", "biome_gallery"],
		"reward": {"funds": 1_050_000_000, "label": "+ $1.05 BN · ice-cap dossier"},
	},
	{
		"id": "night_sky", "title": "MARTIAN NIGHT SKY", "icon": "✦", "color": Color("c7b4ff"),
		"description": "Transmit a nighttime photograph from the surface.", "target": 1,
		"prerequisites": ["first_photo"],
		"reward": {"funds": 430_000_000, "label": "+ $430 MN · astronomical observation"},
	},
	{
		"id": "outpost_portrait", "title": "FIRST OUTPOST", "icon": "⌂", "color": Color("a5e4e9"),
		"description": "Photograph a habitat dome from outside.", "target": 1,
		"prerequisites": ["first_base", "first_photo"],
		"reward": {"funds": 610_000_000, "label": "+ $610 MN · colony chronicle"},
	},
	{
		"id": "greenhouse_window", "title": "GLASS AND CHLOROPHYLL", "icon": "♧", "color": Color("a4ec9d"),
		"description": "Transmit a photograph of the operational greenhouse.", "target": 1,
		"prerequisites": ["greenhouse", "first_photo"],
		"reward": {"funds": 800_000_000, "label": "+ $800 MN · visual agriculture program"},
	},
	{
		"id": "lab_in_frame", "title": "SCIENCE IN FRAME", "icon": "⚗", "color": Color("c7cbff"),
		"description": "Transmit a photograph of an installed laboratory.", "target": 1,
		"prerequisites": ["first_lab", "first_photo"],
		"reward": {"funds": 950_000_000, "label": "+ $950 MN · instrumentation documentation"},
	},
	{
		"id": "primordial_frost_photo", "title": "TIME IN THE ICE", "icon": "◈", "color": Color("c5f4ff"),
		"description": "Transmit a photo while holding the primordial deep-ice sample.", "target": 1,
		"prerequisites": ["primordial_ice", "first_photo"],
		"reward": {"funds": 2_000_000_000, "label": "+ $2 BN · cryogenic archive"},
	},
	{
		"id": "life_witness_image", "title": "WITNESS TO LIFE", "icon": "✺", "color": Color("84ffd2"),
		"description": "Photograph the laboratory after detecting a signal compatible with a possible biosignature.", "target": 1,
		"prerequisites": ["ancient_life", "lab_in_frame"],
		"reward": {"funds": 4_000_000_000, "badge": "EYE OF MARS", "label": "+ $4 BN · historic image"},
	},
	{
		"id": "first_base", "title": "FIRST BASE", "icon": "⌂", "color": Color("70c8ff"),
		"description": "Place the first habitat dome.", "target": 1,
		"prerequisites": [],
		"reward": {"funds": 150_000_000, "label": "+ $150 MN"},
	},
	{
		"id": "airlock_cycle", "title": "SAFE ACCESS", "icon": "⇄", "color": Color("9cc8ff"),
		"description": "Complete one airlock cycle.", "target": 1,
		"prerequisites": ["first_base"],
		"reward": {"badge": "MARTIAN COLONIST", "label": "Badge: Martian Colonist"},
	},
	{
		"id": "stable_grid", "title": "POWER GRID", "icon": "ϟ", "color": Color("ffe079"),
		"description": "Make the grid operational with panels, a transformer, and a battery.", "target": 1,
		"prerequisites": ["first_base"],
		"reward": {"funds": 150_000_000, "label": "+ $150 MN"},
	},
	{
		"id": "ice_drill", "title": "FIRST DRILL", "icon": "⌄", "color": Color("6de8ff"),
		"description": "Place an ice drill.", "target": 1,
		"prerequisites": ["airlock_cycle", "stable_grid"],
		"reward": {"funds": 100_000_000, "label": "+ $100 MN"},
	},
	{
		"id": "refill_bottle", "title": "BOTTLE REFILLED", "icon": "◒", "color": Color("73dfff"),
		"description": "Refill a bottle from the drill's water reserve.", "target": 1,
		"prerequisites": ["ice_drill"],
		"reward": {"effect": "water_efficiency", "label": "Water use -10%"},
	},
	{
		"id": "greenhouse", "title": "OPERATIONAL GREENHOUSE", "icon": "♧", "color": Color("89e89a"),
		"description": "Connect a greenhouse to a water source.", "target": 1,
		"prerequisites": ["stable_grid"],
		"reward": {"funds": 200_000_000, "label": "+ $200 MN"},
	},
	{
		"id": "first_planting", "title": "FIRST PLANTING", "icon": "✦", "color": Color("9ce66f"),
		"description": "Plant the first batch of potatoes.", "target": 1,
		"prerequisites": ["greenhouse"],
		"reward": {"effect": "crop_efficiency", "label": "Crop growth +5%"},
	},
	{
		"id": "first_harvest", "title": "FIRST HARVEST", "icon": "▣", "color": Color("e8c45b"),
		"description": "Harvest the first batch of 4 or 5 rations.", "target": 1,
		"prerequisites": ["first_planting"],
		"reward": {"funds": 300_000_000, "label": "+ $300 MN"},
	},
	{
		"id": "genetic_modification", "title": "GM POTATOES", "icon": "✿", "color": Color("b5ef87"),
		"description": "Genetically modify potato seeds in the store.", "target": 1,
		"prerequisites": ["first_harvest", "perseverance_repair"],
		"reward": {"funds": 300_000_000, "label": "+ $300 MN · GM seed program"},
	},
	{
		"id": "genetic_replacement", "title": "IMPROVED CROP", "icon": "↻", "color": Color("9de47f"),
		"description": "Replace a greenhouse batch with more capable GM seeds.", "target": 1,
		"prerequisites": ["genetic_modification"],
		"reward": {"funds": 450_000_000, "label": "+ $450 MN · crop selection"},
	},
	# The Perseverance mission is one narrative chain: photograph, document, and
	# repair the same rover to complete all three contracts. No objective requires
	# waiting for a second rover to fail.
	{
		"id": "perseverance_photo", "title": "SIGNAL FROM PERSEVERANCE", "icon": "◉", "color": Color("f2ba72"),
		"description": "Photograph and transmit the damaged Perseverance rover to Earth.", "target": 1,
		"prerequisites": ["first_photo"],
		"reward": {"funds": 700_000_000, "label": "+ $700 MN · rover telemetry"},
	},
	{
		"id": "perseverance_report", "title": "REMOTE DIAGNOSIS", "icon": "≣", "color": Color("f0d29a"),
		"description": "Study and send Perseverance's damage report to Earth.", "target": 1,
		"prerequisites": ["perseverance_photo"],
		"reward": {"funds": 1_100_000_000, "label": "+ $1.1 BN · signed report"},
	},
	{
		"id": "perseverance_repair", "title": "OPERATIONAL LEGACY", "icon": "✦", "color": Color("8ae7d4"),
		"description": "Complete the maintenance sequence and repair Perseverance.", "target": 1,
		"prerequisites": ["perseverance_report"],
		"reward": {"funds": 1_750_000_000, "effect": "genetic_seed_access", "label": "+ $1.75 BN · bioengineering access"},
	},
	# Research is not a decorative milestone: it is the main funding program for
	# the first half of the mission. Reports always pay; these one-off contracts
	# instead reward the quality and variety of the data.
	{
		"id": "first_lab", "title": "FIRST LABORATORY", "icon": "⚗", "color": Color("a4baff"),
		"description": "Install the first scientific instrument in a habitat dome.", "target": 1,
		"prerequisites": ["stable_grid"],
		"reward": {"funds": 250_000_000, "label": "+ $250 MN · startup grant"},
	},
	{
		"id": "first_extraction", "title": "GEOLOGICAL SAMPLING", "icon": "⧁", "color": Color("e8aa65"),
		"description": "Bring the first rock drill online.", "target": 1,
		"prerequisites": ["ice_drill", "first_lab"],
		"reward": {"funds": 350_000_000, "label": "+ $350 MN · geological mandate"},
	},
	{
		"id": "polar_drill", "title": "POLAR SAMPLING", "icon": "❄", "color": Color("a8f3ff"),
		"description": "Place a mineral drill in the polar-ice biome.", "target": 1,
		"prerequisites": ["polar_expedition", "first_extraction"],
		"reward": {"funds": 1_800_000_000, "label": "+ $1.8 BN · polar grant"},
	},
	{
		"id": "primordial_ice", "title": "DEEP-ICE SAMPLE", "icon": "◆", "color": Color("b7f4ff"),
		"description": "Find a rare deep-ice sample with the drill in the game model.", "target": 1,
		"prerequisites": ["polar_drill"],
		"reward": {"funds": 3_000_000_000, "label": "+ $3 BN · cryogenic custody"},
	},
	{
		"id": "deep_ice_study", "title": "DEEP-LAYER STUDY", "icon": "◈", "color": Color("bde8ff"),
		"description": "Start studying a deep-ice sample in a laboratory.", "target": 1,
		"prerequisites": ["primordial_ice", "first_lab"],
		"reward": {"funds": 4_500_000_000, "label": "+ $4.5 BN · biosampling protocol"},
	},
	{
		"id": "ancient_life", "title": "COMPATIBLE SIGNAL", "icon": "✺", "color": Color("7fffd4"),
		"description": "Detect a signal compatible with a biosignature in deep ice. Percentages are a game mechanic, not a validated scientific probability.", "target": 1,
		"prerequisites": ["deep_ice_study"],
		"reward": {"funds": 15_000_000_000, "badge": "LIFE DISCOVERER", "label": "+ $15 BN · life discoverer"},
	},
	{
		"id": "life_relay", "title": "MESSAGE TO VERIFY", "icon": "✦", "color": Color("f6ffad"),
		"description": "Transmit the first signal compatible with a possible Martian biosignature to Earth; it is not definitive evidence of life.", "target": 1,
		"prerequisites": ["ancient_life"],
		"reward": {"funds": 25_000_000_000, "effect": "life_patent", "badge": "MESSENGER OF MARS", "label": "+ $25 BN · messenger of Mars"},
	},
	# Sample return is the expedition's conclusion. Contracts record the steps, but
	# the manifest and launch remain physical actions carried out beside the rocket.
	{
		"id": "life_sample_secured", "title": "BIOLOGICAL SAMPLE", "icon": "✺", "color": Color("80ffcf"),
		"description": "Secure the alien-life sample in its glass container for return to Earth.", "target": 1,
		"prerequisites": ["ancient_life"],
		"reward": {"funds": 5_000_000_000, "label": "+ $5 BN · containment protocol"},
	},
	{
		"id": "return_manifest", "title": "GEOLOGICAL MANIFEST", "icon": "▤", "color": Color("d8e9f2"),
		"description": "Load one sample of every rock available in the game and the biological sample into the rocket. The Return tab lists each sample's biome and rarity.", "target": 1,
		"prerequisites": ["life_sample_secured"],
		"reward": {"funds": 8_000_000_000, "label": "+ $8 BN · interplanetary chain of custody"},
	},
	{
		"id": "sabatier_online", "title": "MARTIAN PROPELLANT", "icon": "ϟ", "color": Color("ffb86d"),
		"description": "Place the Sabatier reactor beside the rocket and make it productive: power and the H₂ pipe must be connected.", "target": 1,
		"prerequisites": ["life_relay", "stable_grid", "first_extraction"],
		"reward": {"funds": 4_000_000_000, "label": "+ $4 BN · propellant plant"},
	},
	{
		"id": "rocket_fueled", "title": "FULL TANK", "icon": "▲", "color": Color("ffe079"),
		"description": "Fill the rocket tank with 400 kg of methane produced by the Sabatier reactor.", "target": 1,
		"prerequisites": ["sabatier_online"],
		"reward": {"funds": 6_000_000_000, "label": "+ $6 BN · launch window"},
	},
	{
		"id": "return_launch", "title": "RETURN TO EARTH", "icon": "▲", "color": Color("fff0a2"),
		"description": "Launch the rocket with a complete manifest and full tank: Mars samples are on their way to Earth.", "target": 1,
		"prerequisites": ["return_manifest", "rocket_fueled"],
		"reward": {"funds": 20_000_000_000, "badge": "RETURN FROM MARS", "label": "MISSION COMPLETE · samples in transit"},
	},
	{
		"id": "first_report", "title": "SIGNAL FROM MARS", "icon": "▤", "color": Color("79d9ff"),
		"description": "Transmit the first scientific report to Earth.", "target": 1,
		"prerequisites": ["first_lab"],
		"reward": {"funds": 400_000_000, "effect": "research_bonus", "label": "+ $400 MN · research income +10%"},
	},
	{
		"id": "chain_of_custody", "title": "CHAIN OF CUSTODY", "icon": "≡", "color": Color("7ebde9"),
		"description": "Send 3 verified reports to Earth.", "target": 3,
		"prerequisites": ["first_report"],
		"reward": {"funds": 550_000_000, "label": "+ $550 MN · analysis contract"},
	},
	{
		"id": "xrd_fieldwork", "title": "LATTICES REVEALED", "icon": "X", "color": Color("ffaf73"),
		"description": "Complete 3 reports with the XRD diffractometer.", "target": 3,
		"prerequisites": ["first_report"],
		"reward": {"funds": 650_000_000, "effect": "xrd_precision", "label": "+ $650 MN · XRD value +15%"},
	},
	{
		"id": "raman_fieldwork", "title": "LUMINOUS FINGERPRINTS", "icon": "R", "color": Color("d48cff"),
		"description": "Complete 3 reports with the Raman spectrometer.", "target": 3,
		"prerequisites": ["first_report"],
		"reward": {"funds": 800_000_000, "effect": "raman_precision", "label": "+ $800 MN · Raman value +15%"},
	},
	{
		"id": "icp_fieldwork", "title": "TRACES IN PLASMA", "icon": "I", "color": Color("72efd3"),
		"description": "Complete 3 reports with the ICP-MS.", "target": 3,
		"prerequisites": ["chain_of_custody"],
		"reward": {"funds": 1_000_000_000, "effect": "icp_precision", "label": "+ $1 BN · ICP-MS value +15%"},
	},
	{
		"id": "rare_signal", "title": "ANOMALOUS SIGNAL", "icon": "✦", "color": Color("ffe079"),
		"description": "Analyze and transmit the first rare sample.", "target": 1,
		"prerequisites": ["first_extraction", "first_report"],
		"reward": {"funds": 1_100_000_000, "label": "+ $1.1 BN · anomaly award"},
	},
	{
		"id": "regional_atlas", "title": "ARES ATLAS", "icon": "⊕", "color": Color("9ed6ff"),
		"description": "Deliver data from 3 distinct Martian biomes.", "target": 3,
		"prerequisites": ["first_extraction", "chain_of_custody"],
		"reward": {"funds": 1_250_000_000, "effect": "diversity_bonus", "label": "+ $1.25 BN · multi-biome data +10%"},
	},
	{
		"id": "data_convoy", "title": "DATA CONVOY", "icon": "⇑", "color": Color("8be5ff"),
		"description": "Transmit 8 scientific reports in total.", "target": 8,
		"prerequisites": ["chain_of_custody"],
		"reward": {"funds": 1_400_000_000, "label": "+ $1.4 BN · Earth sponsorship"},
	},
	{
		"id": "xrd_master", "title": "PRECISION XRD", "icon": "X+", "color": Color("ffaf73"),
		"description": "Upgrade the XRD diffractometer to level 5.", "target": 1,
		"prerequisites": ["xrd_fieldwork"],
		"reward": {"funds": 1_000_000_000, "label": "+ $1 BN · crystallography patent"},
	},
	{
		"id": "raman_master", "title": "PRECISION RAMAN", "icon": "R+", "color": Color("d48cff"),
		"description": "Upgrade the Raman spectrometer to level 5.", "target": 1,
		"prerequisites": ["raman_fieldwork"],
		"reward": {"funds": 1_250_000_000, "label": "+ $1.25 BN · spectroscopy patent"},
	},
	{
		"id": "icp_master", "title": "PRECISION ICP-MS", "icon": "I+", "color": Color("72efd3"),
		"description": "Upgrade ICP-MS to level 5.", "target": 1,
		"prerequisites": ["icp_fieldwork"],
		"reward": {"funds": 1_600_000_000, "label": "+ $1.6 BN · elemental patent"},
	},
	{
		"id": "rare_constellation", "title": "RARE CONSTELLATION", "icon": "★", "color": Color("ffd86b"),
		"description": "Transmit 3 rare samples, including samples from different biomes.", "target": 3,
		"prerequisites": ["rare_signal", "raman_fieldwork"],
		"reward": {"funds": 1_900_000_000, "effect": "rare_premium", "label": "+ $1.9 BN · rare samples +25%"},
	},
	{
		"id": "earth_relay", "title": "EARTH RELAY", "icon": "⇈", "color": Color("76e7d0"),
		"description": "Transmit 15 scientific reports in total.", "target": 15,
		"prerequisites": ["data_convoy", "icp_fieldwork"],
		"reward": {"funds": 2_500_000_000, "effect": "transmission_priority", "label": "+ $2.5 BN · report value +15%"},
	},
	{
		"id": "planetary_archive", "title": "PLANETARY ARCHIVE", "icon": "◉", "color": Color("b5a0ff"),
		"description": "Complete the atlas with data from all 6 biomes.", "target": 6,
		"prerequisites": ["regional_atlas", "rare_signal"],
		"reward": {"funds": 3_000_000_000, "label": "+ $3 BN · cartography mandate"},
	},
	{
		"id": "science_center", "title": "SCIENTIFIC DIRECTORATE", "icon": "★", "color": Color("ffe36e"),
		"description": "Unite three calibrated laboratories, the Earth relay, and the planetary archive.", "target": 1,
		"prerequisites": ["xrd_master", "raman_master", "icp_master", "earth_relay", "planetary_archive"],
		"reward": {"funds": 4_000_000_000, "effect": "scientific_director", "badge": "SCIENTIFIC DIRECTOR", "label": "+ $4 BN · scientific director"},
	},
	{
		"id": "martian_dividend", "title": "MARTIAN DIVIDEND", "icon": "✦", "color": Color("fff0a2"),
		"description": "Deliver 24 reports: research funds the colony's new economy.", "target": 24,
		"prerequisites": ["science_center", "rare_constellation"],
		"reward": {"funds": 6_000_000_000, "badge": "VALUE PIONEER", "label": "+ $6 BN · value pioneer"},
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
				push_warning("Camera reward pending: free one backpack slot.")
	_save_progress()
	achievement_updated.emit(achievement_id)
	for child_id in get_dependent_ids(achievement_id):
		achievement_updated.emit(child_id)
		if is_claimable(child_id):
			achievement_claimable.emit(child_id)
	achievement_claimed.emit(achievement_id, str(reward.get("label", "Reward claimed")))
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
	# Every report advances multiple contracts in parallel. Even when a contract is
	# still locked, its progress remains visible in the graph.
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
	# These contracts need no infrastructure: a rock collected on foot already
	# provides data for Earth and helps fund the first real installation.
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
	## Photo contracts advance only when the shot genuinely goes to Earth. Taking
	## photos without sending them fills the camera roll but grants neither money
	## nor artificial progress.
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
	# The evidence is discovered and transmitted by the same report. The second
	# reward remains chained: it appears ready but first requires claiming the
	# scientific discovery.
	record("ancient_life")
	record("life_relay")
	var inventory := get_node_or_null("/root/Inventory")
	if inventory != null and inventory.has_method("add_alien_life_sample") and bool(inventory.call("add_alien_life_sample")):
		record("life_sample_secured")


func get_research_contract_summary(machine_id: String) -> String:
	# Brief summary for the panel near the laboratory. It shows players which
	# economic contract they are funding before they deliver a sample.
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
	# Achievements are intentionally non-persistent. Keep this API only for
	# compatibility with existing tests.
	if enabled:
		push_warning("Achievement persistence is disabled: every run is a new mission.")


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
	# No disk saving: F5 or a new run must always restart from zero.
	pass

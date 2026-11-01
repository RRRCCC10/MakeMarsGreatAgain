class_name PowerDevice
extends Node2D

const SOLAR_TEXTURE := preload("res://sprites/pannello_solare_classico_32x16.png")
const TRANSFORMER_SHEET := preload("res://sprites/trasformatore_spritesheet_con_cavi.png")
const BATTERY_SHEET := preload("res://sprites/batteria_spritesheet_20_frame_con_cavi.png")
const ICE_DRILL_SHEET := preload("res://sprites/trivella_ghiaccio_spritesheet.png")
const TRANSFORMER_FRAME_SIZE := Vector2i(32, 32)
const BATTERY_FRAME_SIZE := Vector2i(16, 16)
const ICE_DRILL_FRAME_SIZE := Vector2i(32, 48)
const BATTERY_CAPACITY_KWH := 500.0
const ICE_DRILL_DEMAND_KW := 60.0
const ICE_DRILL_WATER_L_PER_HOUR := 40.0

var device_id := ""
var origin_cell := Vector2i.ZERO
var is_preview := false
var powered := false
var flow_state := 0
var animation_frame := 0
var animation_timer := 0.0
var battery_energy_kwh := 0.0
var battery_charge_ratio := 0.0
var water_extracted_liters := 0.0
var water_transported_liters := 0.0
var fluid_output_connected := false
var network_enabled := false
var stock_items: Array[Dictionary] = []
var sprite: Sprite2D
var status_indicator: Polygon2D
var night_light: PointLight2D
var physics_body: StaticBody2D


func setup(new_id: String, cell: Vector2i, preview: bool = false) -> void:
	device_id = new_id
	origin_cell = cell
	is_preview = preview
	if is_node_ready():
		_refresh_texture()


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	z_index = 2
	_refresh_texture()
	_setup_night_light()
	_setup_collision()


func _process(delta: float) -> void:
	_update_night_light()
	if device_id == "ice_drill" and not is_preview:
		var pipe_manager := get_node_or_null("/root/PipeManager")
		fluid_output_connected = pipe_manager != null and bool(pipe_manager.call("is_source_connected", self))
		if powered:
			var produced := ICE_DRILL_WATER_L_PER_HOUR * WorldClock.get_game_hours_for_real_delta(delta)
			water_extracted_liters += produced
			if fluid_output_connected:
				water_transported_liters += produced
	if is_preview or device_id == "solar_panel":
		return
	var should_animate := device_id == "transformer" and powered
	should_animate = should_animate or (device_id == "battery" and flow_state != 0)
	should_animate = should_animate or (device_id == "ice_drill" and powered)
	if not should_animate:
		return
	animation_timer += delta
	if animation_timer < 0.10:
		return
	animation_timer = 0.0
	# Il trasformatore ha 4 frame da 32x32. La batteria ha invece
	# 4 frame per ciascuna delle 5 righe che indicano la carica.
	animation_frame = (animation_frame + 1) % 4
	_refresh_texture()


func set_power_state(new_powered: bool, new_flow_state: int = 0) -> void:
	powered = new_powered
	flow_state = new_flow_state
	if not powered and device_id in ["transformer", "ice_drill"]:
		animation_frame = 0
		_refresh_texture()
	_update_night_light()


func set_powered(new_powered: bool) -> void:
	set_power_state(new_powered, flow_state)


func set_network_enabled(enabled: bool) -> void:
	if is_preview or network_enabled == enabled:
		return
	network_enabled = enabled
	if not network_enabled:
		set_power_state(false, 0)
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid != null:
		power_grid.call("request_rebuild")


func is_network_enabled() -> bool:
	return network_enabled


func get_connection_label() -> String:
	if not network_enabled:
		return "DISCONNESSO"
	var power_grid := get_node_or_null("/root/PowerGrid")
	if power_grid == null:
		return "ABILITATO - RETE NON DISPONIBILE"
	var connection_map: Dictionary = power_grid.get("connection_ok")
	return "COLLEGATO ALLA RETE" if bool(connection_map.get(self, false)) else "ABILITATO - IN ATTESA DI RETE"


func get_interaction_summary() -> String:
	match device_id:
		"solar_panel":
			var available_kw := 100.0 * WorldClock.get_solar_factor()
			return "Produzione disponibile: %d kW" % roundi(available_kw)
		"transformer":
			return "Trasformazione e isolamento delle sezioni elettriche"
		"battery":
			return "Carica: %.1f / %.0f kWh  ·  %d%%" % [battery_energy_kwh, BATTERY_CAPACITY_KWH, roundi(battery_charge_ratio * 100.0)]
		"ice_drill":
			return "Consumo: 60 kW  ·  Acqua: %.0f L/h" % get_fluid_output_rate_lph()
	return "Dispositivo elettrico"


func get_stock_items() -> Array[Dictionary]:
	return stock_items.duplicate(true)


func take_stock_item(index: int = 0) -> bool:
	if index < 0 or index >= stock_items.size():
		return false
	var item := stock_items[index]
	var count := int(item.get("count", 0))
	if count <= 0:
		return false
	var inventory := get_node_or_null("/root/Inventory")
	if inventory == null or not bool(inventory.call("add_item", str(item.get("id", "")), str(item.get("name", "Output")), 1, bool(item.get("placeable", false)))):
		return false
	item["count"] = count - 1
	if int(item["count"]) <= 0:
		stock_items.remove_at(index)
	return true


func set_battery_charge_ratio(value: float) -> void:
	set_battery_energy_kwh(clampf(value, 0.0, 1.0) * BATTERY_CAPACITY_KWH)


func set_battery_energy_kwh(value: float) -> void:
	battery_energy_kwh = clampf(value, 0.0, BATTERY_CAPACITY_KWH)
	battery_charge_ratio = battery_energy_kwh / BATTERY_CAPACITY_KWH
	if device_id == "battery":
		_refresh_texture()
	_update_night_light()


func get_battery_energy_kwh() -> float:
	return battery_energy_kwh


func get_battery_available_capacity_kwh() -> float:
	return maxf(0.0, BATTERY_CAPACITY_KWH - battery_energy_kwh)


func get_occupied_power_cells() -> Array[Vector2i]:
	if device_id == "solar_panel":
		return [origin_cell, origin_cell + Vector2i.RIGHT]
	if device_id in ["transformer", "ice_drill"]:
		# Il cavo entra ed esce sulla riga centrale. Lo sprite da 32px
		# sporge di 8px sopra e sotto, quindi riserviamo tutte le celle
		# attraversate per impedire al pathfinding di tagliare l'edificio.
		return [
			origin_cell + Vector2i.UP,
			origin_cell + Vector2i.RIGHT + Vector2i.UP,
			origin_cell,
			origin_cell + Vector2i.RIGHT,
			origin_cell + Vector2i.DOWN,
			origin_cell + Vector2i.RIGHT + Vector2i.DOWN,
		]
	return [origin_cell]


func contains_world_point(world_point: Vector2) -> bool:
	var footprint := Vector2(16, 16)
	if device_id == "solar_panel":
		footprint = Vector2(32, 16)
	elif device_id == "transformer":
		footprint = Vector2(32, 32)
	elif device_id == "ice_drill":
		footprint = Vector2(32, 48)
	return Rect2(global_position - footprint * 0.5, footprint).has_point(world_point)


func get_fluid_output_cell() -> Vector2i:
	return origin_cell + Vector2i(2, 0)


func get_fluid_output_rate_lph() -> float:
	return ICE_DRILL_WATER_L_PER_HOUR if device_id == "ice_drill" and powered and fluid_output_connected else 0.0


func get_machine_specs() -> Dictionary:
	match device_id:
		"solar_panel":
			var solar_connection := get_connection_label()
			return {
				"title": "PANNELLO SOLARE FOTOVOLTAICO",
				"category": "GENERAZIONE ELETTRICA",
				"status": solar_connection if not network_enabled else ("PRODUZIONE ATTIVA" if powered else "NESSUNA PRODUZIONE"),
				"status_color": Color("72eda0") if powered else Color("ffb45d"),
				"principle": "Le celle fotovoltaiche convertono i fotoni solari in corrente continua tramite l'effetto fotovoltaico nei semiconduttori.",
				"specs": ["Potenza nominale: 100 kW", "Produzione: proporzionale alla luce solare", "Produzione notturna: 0 kW", "Uscita elettrica: lato destro", "Rete: %s" % solar_connection],
			}
		"transformer":
			var transformer_connection := get_connection_label()
			return {
				"title": "TRASFORMATORE DI POTENZA",
				"category": "CONDIZIONAMENTO ELETTRICO",
				"status": transformer_connection if not network_enabled else ("IN FUNZIONE" if powered else transformer_connection),
				"status_color": Color("72eda0") if powered else Color("ffb45d"),
				"principle": "L'induzione elettromagnetica trasferisce energia tra avvolgimenti isolati e adatta tensione e corrente alla rete di accumulo.",
				"specs": ["Ingresso: rete pannelli", "Uscita: rete trasformata", "Canali elettrici separati", "Limite missione: 1 unita'", "Rete: %s" % transformer_connection],
			}
		"battery":
			var charge_percent := roundi(battery_charge_ratio * 100.0)
			var battery_connection := get_connection_label()
			var battery_status := battery_connection
			if network_enabled and battery_connection == "COLLEGATO ALLA RETE":
				battery_status = "CARICA %d%%" % charge_percent
			return {
				"title": "BATTERIA DI ACCUMULO",
				"category": "STOCCAGGIO ENERGETICO",
				"status": battery_status,
				"status_color": Color("69c8ff") if charge_percent > 0 else Color("ff655d"),
				"principle": "L'energia elettrica viene immagazzinata come energia chimica reversibile e restituita alla rete quando la produzione solare non copre il carico.",
				"specs": ["Capacita': %.0f kWh" % BATTERY_CAPACITY_KWH, "Energia propria: %.1f kWh" % battery_energy_kwh, "Stato di carica: %d%%" % charge_percent, "Flusso: %s" % _flow_label(), "Alimentazione notturna: disponibile", "Rete: %s" % battery_connection],
			}
		"ice_drill":
			var pipe_status := "CONNESSA - ACQUA IN RETE" if fluid_output_connected else "USCITA IDRICA NON CONNESSA"
			var drill_connection := get_connection_label()
			return {
				"title": "TRIVELLA DI ESTRAZIONE DEL GHIACCIO",
				"category": "ISRU - UTILIZZO RISORSE IN SITU",
				"status": drill_connection if not network_enabled else ("OPERATIVA" if powered else drill_connection),
				"status_color": Color("72eda0") if powered else Color("ff655d"),
				"principle": "La testa di perforazione frantuma il regolite marziano ghiacciato; un sistema termico interno separa e fonde il ghiaccio, ottenendo acqua liquida.",
				"specs": ["Assorbimento elettrico: 60 kW", "Produzione nominale: 40 L/h", "Uscita: destra, cella centrale", "Tubazione: %s" % pipe_status, "Acqua estratta: %.1f L" % water_extracted_liters, "Acqua trasportata: %.1f L" % water_transported_liters, "Rete: %s" % drill_connection],
			}
	return {"title": "MACCHINARIO", "category": "SISTEMA", "status": "SCONOSCIUTO", "status_color": Color.WHITE, "principle": "", "specs": []}


func _flow_label() -> String:
	if flow_state > 0:
		return "IN CARICA"
	if flow_state < 0:
		return "IN SCARICA"
	return "STABILE"


func _refresh_texture() -> void:
	if sprite == null:
		return
	if device_id == "solar_panel":
		sprite.texture = SOLAR_TEXTURE
		return
	var atlas := AtlasTexture.new()
	if device_id == "transformer":
		atlas.atlas = TRANSFORMER_SHEET
		var transformer_column := animation_frame % 2
		var transformer_row := floori(float(animation_frame) / 2.0)
		atlas.region = Rect2(
			Vector2i(transformer_column, transformer_row) * TRANSFORMER_FRAME_SIZE,
			TRANSFORMER_FRAME_SIZE
		)
	elif device_id == "ice_drill":
		atlas.atlas = ICE_DRILL_SHEET
		var drill_column := animation_frame % 2
		var drill_row := floori(float(animation_frame) / 2.0)
		atlas.region = Rect2(
			Vector2i(drill_column, drill_row) * ICE_DRILL_FRAME_SIZE,
			ICE_DRILL_FRAME_SIZE
		)
	else:
		atlas.atlas = BATTERY_SHEET
		# Riga 0 = piena, riga 4 = vuota. Ogni riga contiene i 4
		# frame dell'animazione, che non devono mai cambiare la carica.
		var charge_band := clampi(floori(battery_charge_ratio * 5.0), 0, 4)
		var battery_row := 4 - charge_band
		atlas.region = Rect2(
			Vector2i(animation_frame % 4, battery_row) * BATTERY_FRAME_SIZE,
			BATTERY_FRAME_SIZE
		)
	sprite.texture = atlas


func _setup_night_light() -> void:
	if device_id == "solar_panel":
		return
	status_indicator = Polygon2D.new()
	status_indicator.name = "StatusLight"
	status_indicator.polygon = PackedVector2Array([
		Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
		Vector2(1.0, 1.0), Vector2(-1.0, 1.0),
	])
	status_indicator.position = Vector2(0.0, -5.0 if device_id == "battery" else (-18.0 if device_id == "ice_drill" else -8.0))
	status_indicator.z_index = 4
	add_child(status_indicator)

	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var light_texture := GradientTexture2D.new()
	light_texture.width = 64
	light_texture.height = 64
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(1.0, 0.5)
	light_texture.gradient = gradient
	night_light = PointLight2D.new()
	night_light.name = "NightGlow"
	night_light.texture = light_texture
	night_light.texture_scale = 0.75 if device_id == "battery" else 1.1
	night_light.shadow_enabled = false
	night_light.enabled = false
	add_child(night_light)
	_update_night_light()


func _update_night_light() -> void:
	if status_indicator == null or night_light == null:
		return
	var active := powered and not is_preview
	var light_color := Color("69c8ff")
	if device_id == "battery":
		if flow_state > 0:
			light_color = Color("72eda0")
		elif flow_state < 0:
			light_color = Color("69a7ff")
		elif battery_charge_ratio <= 0.01:
			light_color = Color("ff5d57")
		else:
			light_color = Color("ffd36a")
	elif device_id == "ice_drill":
		light_color = Color("52c7ff") if fluid_output_connected else Color("ffb45d")
	status_indicator.color = light_color
	status_indicator.visible = active
	var night_amount := WorldClock.get_artificial_light_factor()
	night_light.color = light_color
	night_light.energy = (0.58 if device_id == "battery" else 0.72) * night_amount
	night_light.enabled = active and night_amount > 0.01


func _setup_collision() -> void:
	if is_preview:
		return
	physics_body = StaticBody2D.new()
	physics_body.name = "StructureCollision"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	match device_id:
		"solar_panel":
			shape.size = Vector2(30.0, 12.0)
			collision.position = Vector2(0.0, 2.0)
		"transformer":
			shape.size = Vector2(28.0, 18.0)
			collision.position = Vector2(0.0, 6.0)
		"battery":
			shape.size = Vector2(14.0, 12.0)
			collision.position = Vector2(0.0, 2.0)
		"ice_drill":
			# Solo la base occupa il suolo: la parte alta resta attraversabile
			# quando il giocatore cammina dietro alla trivella.
			shape.size = Vector2(27.0, 15.0)
			collision.position = Vector2(0.0, 15.0)
		_:
			shape.size = Vector2(14.0, 14.0)
	collision.shape = shape
	physics_body.add_child(collision)
	add_child(physics_body)

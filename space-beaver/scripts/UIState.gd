extends Node

## Autorità unica sulle interfacce che sospendono il mondo.
##
## Le GUI modali non devono affidarsi a controlli locali sparsi: oltre a
## permettere due finestre contemporaneamente, quei controlli lasciavano attivi
## movimento, E, zoom e tasti dei macchinari. Ogni pannello interattivo apre qui
## la propria sessione e la chiude esplicitamente.

signal modal_changed(active_modal_id: StringName)

const INVENTORY := &"inventory"
const SHOP := &"shop"
const ACHIEVEMENTS := &"achievements"
const MINIMAP := &"minimap"
const FIELD_CAMERA_ARCHIVE := &"field_camera_archive"
const WORLD_PANEL := &"world_panel"
const POWER_NETWORK := &"power_network"

var active_modal: StringName = &""


func try_open_modal(modal_id: StringName) -> bool:
	if modal_id == &"":
		return false
	if active_modal != &"" and active_modal != modal_id:
		return false
	if active_modal == modal_id:
		return true
	active_modal = modal_id
	modal_changed.emit(active_modal)
	return true


func close_modal(modal_id: StringName) -> void:
	if modal_id == &"" or active_modal != modal_id:
		return
	active_modal = &""
	modal_changed.emit(active_modal)


func is_modal_active(modal_id: StringName) -> bool:
	return active_modal == modal_id


func has_open_modal() -> bool:
	return active_modal != &""


func blocks_world_actions() -> bool:
	## Anche la minimappa blocca azioni, costruzioni e interazioni: è l'unica
	## finestra che lascia il giocatore libero di camminare.
	return has_open_modal()


func allows_world_movement() -> bool:
	return active_modal == MINIMAP


func reset_for_new_mission() -> void:
	if active_modal == &"":
		return
	active_modal = &""
	modal_changed.emit(active_modal)

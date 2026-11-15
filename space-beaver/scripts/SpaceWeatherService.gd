extends Node

## Data service deliberately separated from Radiation.gd.
## DONKI only affects which existing profile is used; it can never advance,
## multiply, or make the gameplay schedule harsher.

const CACHE_PATH := "user://donki_space_weather_cache.json"
const CACHE_MAX_AGE_SECONDS := 6.0 * 60.0 * 60.0
const INITIAL_FETCH_DELAY_SECONDS := 5.0
const HISTORY_DAYS := 30
const INTRODUCTION_SOL := 3

# Since September 30, 2026, CCMC hosts the public DONKI catalogue. The old NASA
# endpoint remains for compatibility with older installations or mirrors.
const CCMC_WSA_ENLIL_ENDPOINT := "https://ccmc.gsfc.nasa.gov/DONKI-API/get/WSAEnlilSimulations"
const NASA_WSA_ENLIL_ENDPOINT := "https://api.nasa.gov/DONKI/WSAEnlilSimulations"

var _http: HTTPRequest
var _refresh_delay_seconds := INITIAL_FETCH_DELAY_SECONDS
var _live_fetch_enabled := true
var _request_in_flight := false
var _using_legacy_fallback := false
var _candidate_pool: Array[Dictionary] = []
var _used_candidate_ids: Dictionary = {}
var _last_selected_candidate: Dictionary = {}
var _last_fetch_unix := 0.0


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_load_cache()


func _process(delta: float) -> void:
	if not _live_fetch_enabled or _request_in_flight:
		return
	_refresh_delay_seconds -= delta
	if _refresh_delay_seconds <= 0.0:
		_refresh_delay_seconds = INF
		if _cache_is_fresh():
			return
		_request_refresh(false)


func reset_for_new_mission() -> void:
	# A new game can reuse the cache but must never force an HTTP request or an
	# event during the tutorial.
	_used_candidate_ids.clear()
	_last_selected_candidate.clear()


func choose_event_profile(fallback_profile: String, completed_events: int, current_sol: int) -> String:
	# The first storm always remains instructional and minor. Radiation.gd already
	# controls its countdown; this is a second guardrail.
	if completed_events <= 0 or current_sol < INTRODUCTION_SOL:
		return "minor"
	for candidate in _candidate_pool:
		var candidate_id := str(candidate.get("source_id", ""))
		if candidate_id.is_empty() or _used_candidate_ids.has(candidate_id):
			continue
		_used_candidate_ids[candidate_id] = true
		_last_selected_candidate = candidate.duplicate(true)
		return str(candidate.get("profile_id", fallback_profile))
	return fallback_profile


func get_schedule_statistics() -> Dictionary:
	# Values are game hours: pacing belongs to the game, not the API.
	const FIRST_MEAN_HOURS := 84.0
	const REPEAT_MEAN_HOURS := 96.0
	const WARNING_AND_EVENT_MEAN_HOURS := 1.5 + (0.65 * 2.5) + (0.35 * 4.0)
	return {
		"first_event_min_hours": 72.0,
		"first_event_max_hours": 96.0,
		"first_event_mean_sols": FIRST_MEAN_HOURS / 24.0,
		"repeat_quiet_min_hours": 72.0,
		"repeat_quiet_max_hours": 120.0,
		"repeat_quiet_mean_sols": REPEAT_MEAN_HOURS / 24.0,
		"mean_start_to_start_sols": (REPEAT_MEAN_HOURS + WARNING_AND_EVENT_MEAN_HOURS) / 24.0,
		"expected_events_per_30_sols": 30.0 / ((REPEAT_MEAN_HOURS + WARNING_AND_EVENT_MEAN_HOURS) / 24.0),
	}


func get_candidate_count() -> int:
	return _candidate_pool.size()


func get_last_selected_candidate() -> Dictionary:
	return _last_selected_candidate.duplicate(true)


func set_live_fetch_enabled_for_test(enabled: bool) -> void:
	_live_fetch_enabled = enabled


func ingest_wsa_enlil_for_test(records: Array) -> void:
	_candidate_pool = _normalize_wsa_enlil(records)
	_used_candidate_ids.clear()
	_last_selected_candidate.clear()


func _request_refresh(use_legacy_endpoint: bool) -> void:
	if _request_in_flight:
		return
	_using_legacy_fallback = use_legacy_endpoint
	var endpoint := NASA_WSA_ENLIL_ENDPOINT if use_legacy_endpoint else CCMC_WSA_ENLIL_ENDPOINT
	var url := _build_request_url(endpoint, use_legacy_endpoint)
	var result := _http.request(url)
	if result != OK:
		_request_in_flight = false
		_handle_fetch_failure()
		return
	_request_in_flight = true


func _build_request_url(endpoint: String, legacy_nasa_endpoint: bool) -> String:
	var now_unix := Time.get_unix_time_from_system()
	var start_date := _format_utc_date(now_unix - HISTORY_DAYS * 86400.0)
	var end_date := _format_utc_date(now_unix)
	var query := "startDate=%s&endDate=%s&mostAccurateOnly=true&completeEntryOnly=true" % [start_date, end_date]
	if legacy_nasa_endpoint:
		var api_key := OS.get_environment("DONKI_API_KEY")
		if api_key.is_empty():
			api_key = "DEMO_KEY"
		query += "&api_key=%s" % api_key.uri_encode()
	return "%s?%s" % [endpoint, query]


func _format_utc_date(unix_time: float) -> String:
	var date: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d" % [int(date.get("year", 2000)), int(date.get("month", 1)), int(date.get("day", 1))]


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_handle_fetch_failure()
		return
	var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
	var records: Array = _extract_records(decoded)
	if records.is_empty() and not (decoded is Array):
		_handle_fetch_failure()
		return
	_candidate_pool = _normalize_wsa_enlil(records)
	_last_fetch_unix = Time.get_unix_time_from_system()
	_save_cache()


func _handle_fetch_failure() -> void:
	# The historic NASA format is a non-blocking fallback: both endpoints failing
	# is normal offline and leaves gameplay intact.
	if not _using_legacy_fallback:
		_request_refresh(true)
		return
	_refresh_delay_seconds = CACHE_MAX_AGE_SECONDS


func _extract_records(decoded: Variant) -> Array:
	if decoded is Array:
		return decoded
	if decoded is Dictionary:
		for key in ["events", "data", "results"]:
			var records = decoded.get(key, [])
			if records is Array:
				return records
	return []


func _normalize_wsa_enlil(records: Array) -> Array[Dictionary]:
	var by_id: Dictionary = {}
	for index in records.size():
		var record_variant = records[index]
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		var source_id := str(record.get("simulationID", record.get("activityID", record.get("activityId", record.get("id", "simulation-%d" % index)))))
		var speed := _get_record_speed(record)
		for impact in _get_mars_impacts(record):
			var glancing := bool(impact.get("isGlancingBlow", impact.get("glancingBlow", false)))
			var minor_impact := bool(impact.get("isMinorImpact", false))
			var impact_speed := float(impact.get("speed", speed))
			if impact_speed <= 0.0:
				impact_speed = speed
			var profile_id := "minor" if glancing or minor_impact or impact_speed < 1000.0 else "major"
			var candidate_id := "%s:%s" % [source_id, str(impact.get("arrivalTime", impact.get("arrival_time", "mars")))]
			by_id[candidate_id] = {
				"source_id": candidate_id,
				"profile_id": profile_id,
				"speed_km_s": impact_speed,
				"is_glancing": glancing,
				"arrival_utc": str(impact.get("arrivalTime", impact.get("arrival_time", ""))),
			}
	var candidates: Array[Dictionary] = []
	for candidate in by_id.values():
		candidates.append(candidate)
	candidates.sort_custom(_sort_candidates_by_arrival)
	return candidates


func _get_mars_impacts(record: Dictionary) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for key in ["enlilList", "impactList", "impacts"]:
		var impacts = record.get(key, [])
		if not (impacts is Array):
			continue
		for impact_variant in impacts:
			if not (impact_variant is Dictionary):
				continue
			var impact: Dictionary = impact_variant
			var destination := str(impact.get("location", impact.get("target", impact.get("body", "")))).to_lower()
			if destination == "mars":
				matches.append(impact)
	return matches


func _get_record_speed(record: Dictionary) -> float:
	var speed := float(record.get("speed", record.get("speedKMPS", 0.0)))
	if speed > 0.0:
		return speed
	var cme_inputs = record.get("cmeInputs", [])
	if not (cme_inputs is Array):
		return 0.0
	for input_variant in cme_inputs:
		if input_variant is Dictionary:
			speed = maxf(speed, float((input_variant as Dictionary).get("speed", 0.0)))
	return speed


func _sort_candidates_by_arrival(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("arrival_utc", "")) < str(right.get("arrival_utc", ""))


func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var cache: Dictionary = parsed
	_last_fetch_unix = float(cache.get("last_fetch_unix", 0.0))
	var stored_candidates: Variant = cache.get("candidate_pool", [])
	if stored_candidates is Array:
		for candidate_variant in stored_candidates:
			if candidate_variant is Dictionary:
				_candidate_pool.append(candidate_variant)


func _save_cache() -> void:
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"last_fetch_unix": _last_fetch_unix,
		"candidate_pool": _candidate_pool,
	}))


func _cache_is_fresh() -> bool:
	return _last_fetch_unix > 0.0 and Time.get_unix_time_from_system() - _last_fetch_unix < CACHE_MAX_AGE_SECONDS

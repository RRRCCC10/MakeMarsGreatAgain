class_name TextureTransparency
extends RefCounted

## Trasforma in trasparenza soltanto lo sfondo chiaro raggiungibile dai bordi.
## Il bianco presente *dentro* uno sprite (cupole, riflessi, piante) resta intatto.

static var _cache: Dictionary = {}
const MASK_REVISION := 2


static func without_white_background(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	# La revisione evita che una partita già aperta riusi la vecchia texture
	# prodotta con la soglia troppo aggressiva.
	var cache_key := source.resource_path + "#mask-%d" % MASK_REVISION
	if not cache_key.is_empty() and _cache.has(cache_key):
		return _cache[cache_key]
	var image := source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var pending: Array[Vector2i] = []
	var visited: Dictionary = {}
	for x in image.get_width():
		pending.append(Vector2i(x, 0))
		pending.append(Vector2i(x, image.get_height() - 1))
	for y in image.get_height():
		pending.append(Vector2i(0, y))
		pending.append(Vector2i(image.get_width() - 1, y))
	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()
		if visited.has(point) or point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height():
			continue
		visited[point] = true
		var color := image.get_pixelv(point)
		# I file sorgente della serra sono JPEG: il pavimento e il vetro sono
		# volutamente molto chiari (per esempio 223,227,238 e 237,246,255).
		# La vecchia soglia 0.82 li scambiava per lo sfondo e svuotava la cupola.
		# Rimuoviamo quindi soltanto il bianco/neutro quasi puro, raggiungibile
		# dal bordo, lasciando invariati i dettagli bianchi e azzurri degli sprite.
		var is_near_pure_white := color.r >= 0.965 and color.g >= 0.965 and color.b >= 0.965 and absf(color.r - color.g) <= 0.035 and absf(color.g - color.b) <= 0.035
		if not is_near_pure_white:
			continue
		color.a = 0.0
		image.set_pixelv(point, color)
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			pending.append(point + direction)
	var result := ImageTexture.create_from_image(image)
	if not cache_key.is_empty():
		_cache[cache_key] = result
	return result

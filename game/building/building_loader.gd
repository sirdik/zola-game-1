extends RefCounted

const BLOCK_SIZE := 0.5

const LAYER_COLORS := {
	"g": Color(0.45, 0.65, 0.45),
	"y": Color(0.9, 0.8, 0.3),
	"r": Color(0.75, 0.35, 0.3),
}

static func parse(path: String) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("building_loader: could not open %s" % path)
		return blocks
	var content := file.get_as_text()
	file.close()

	var layer_index := -1
	var row_index := 0
	for raw_line in content.split("\n"):
		var line: String = raw_line.replace("\r", "")
		if line.begins_with(";"):
			continue
		if line.strip_edges() == "":
			continue
		if line.begins_with("[layer"):
			layer_index += 1
			row_index = 0
			continue
		if layer_index < 0:
			continue
		for col in range(line.length()):
			var ch: String = line[col]
			if LAYER_COLORS.has(ch):
				blocks.append({
					"position": Vector3(col * BLOCK_SIZE, layer_index * BLOCK_SIZE, row_index * BLOCK_SIZE),
					"color": LAYER_COLORS[ch],
				})
		row_index += 1

	return blocks

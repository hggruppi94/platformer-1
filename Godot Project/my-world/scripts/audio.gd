extends Node

# Autoload "Audio": sound effects, music, and sound captions.
#
#   Audio.play("jump")                    # a sound effect from res://audio/sfx/jump.wav
#   Audio.play_at("gloop_giggle", pos)    # same, but positioned in the world
#   Audio.music("town")                   # crossfade to an area's music
#
# Music: res://audio/music/<name>.ogg (or .mp3/.wav) is used when it exists; otherwise the generated placeholder
# in res://audio/music/placeholder/ plays. So dropping in town.ogg replaces the town placeholder, nothing else to do.
# Each scene's music comes from SCENE_MUSIC below; Area3D zones can override it (see scripts/music_zone.gd).

signal caption(text: String)                  # "[Gloop giggles]" etc., shown by the HUD when captions are on

const BUSES := ["Music", "SFX"]
const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const FADE := 1.5

const SCENE_MUSIC := {
	"res://scenes/town/town.tscn": "town",
	"res://scenes/school/school.tscn": "school",
	"res://scenes/interiors/aquarium.tscn": "interior",
	"res://scenes/interiors/cafe.tscn": "interior",
	"res://scenes/interiors/restaurant_and_cafe.tscn": "interior",
	"res://scenes/interiors/ninas_house.tscn": "interior",
}

# What each sound looks like as a caption. Sounds not listed here are too minor to caption.
const CAPTIONS := {
	"stomp": "[squelch]",
	"gloop_giggle": "[Gloop giggles]",
	"hurt": "[ouch]",
	"pickup": "[item get]",
	"level_up": "[level up!]",
	"faint": "[Nina faints]",
	"sliver_sealed": "[the Sliver hums, sealed]",
	"sliver_open": "[the Sliver shimmers]",
	"centipede_skitter": "[skittering overhead]",
	"centipede_whisper": "[whispering]",
	"door": "[door]",
	"roll": "[tumble]",
	"bark": "[Rook barks]",
	"zipline": "[zipline whirs]",
	"splash": "[splash]",
	"boing": "[boing!]",
	"bubbles": "[bubbles gurgle]",
}

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current := ""
var _zone_stack: Array[String] = []           # music zones Nina is standing in, innermost last
var _last_caption := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # menu sounds and music keep going while paused
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


# ----------------------------------------------------------------------------- sound effects
func _stream(name: String) -> AudioStream:
	if not _cache.has(name):
		var path := SFX_DIR + name + ".wav"
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


func play(name: String, volume_db := 0.0, pitch_jitter := 0.05) -> void:
	var s := _stream(name)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for q in _players:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _players[0]                         # all busy: steal the oldest slot
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
	_caption(name)


func play_at(name: String, pos: Vector3, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var s := _stream(name)
	var scene := get_tree().current_scene
	if s == null or scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = 40.0
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	_caption(name)


func _caption(name: String) -> void:
	if not CAPTIONS.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_caption.get(name, -10000)) < 1500:   # don't spam the same caption
		return
	_last_caption[name] = now
	caption.emit(CAPTIONS[name])


# ----------------------------------------------------------------------------- music
func music_path(track: String) -> String:
	for ext in [".ogg", ".mp3", ".wav"]:
		if ResourceLoader.exists(MUSIC_DIR + track + ext):
			return MUSIC_DIR + track + ext
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(MUSIC_DIR + "placeholder/" + track + ext):
			return MUSIC_DIR + "placeholder/" + track + ext
	return ""


func music(track: String) -> void:
	if track == _current:
		return
	_current = track
	var path := music_path(track) if track != "" else ""
	var incoming := _music_b if _music_a.playing and _music_a.volume_db > -40.0 else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	if outgoing.playing:
		var tw := create_tween()
		tw.tween_property(outgoing, "volume_db", -80.0, FADE)
		tw.tween_callback(outgoing.stop)
	if path != "":
		var stream: AudioStream = load(path).duplicate()
		_set_loop(stream)
		incoming.stream = stream
		incoming.volume_db = -40.0
		incoming.play()
		create_tween().tween_property(incoming, "volume_db", 0.0, FADE)


func current_track() -> String:
	return _current


func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.get_length() * wav.mix_rate


func push_zone(track: String) -> void:
	_zone_stack.append(track)
	music(track)


func pop_zone(track: String) -> void:
	_zone_stack.erase(track)
	music(_zone_stack.back() if not _zone_stack.is_empty() else _scene_track())


func _scene_track() -> String:
	var scene := get_tree().current_scene
	return SCENE_MUSIC.get(scene.scene_file_path, "") if scene else ""


func _on_scene_changed() -> void:
	_zone_stack.clear()
	music(_scene_track())


# ----------------------------------------------------------------------------- volume (0..1, set from Settings)
func set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, linear <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.001)))

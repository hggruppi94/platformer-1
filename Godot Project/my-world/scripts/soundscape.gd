extends Node

# Autoload "Soundscape": which music and ambience play where and when (plan prompt F3). scripts/audio.gd still does
# the playing and the crossfades; this picks the track twice a second from where the player is and what's going on:
#
#   a race                          -> "race"           (Races.racing())
#   the Gloop King after you        -> "gloop_king"     (a boss in the "bosses" group chasing, close by)
#   a fair on the green (Saturdays) -> "festival"       (Festival.is_on(), on Earth)
#   a music zone you're standing in -> its own track    (scripts/music_zone.gd: interiors; the barn's is "barn_dance")
#   the Skate Park / the Skate Yard -> "skate_park"
#   the Scary World                 -> "scary_world"
#   Galaxity                        -> "town_day" or "town_night", by Galaxity's daylight
#   Earth outdoors                  -> "earth_day" or "earth_night", by Earth's clock
#
# Ambience loops quietly under it (res://audio/ambience, made by tools/make_soundscape.py): birds by day and the wind
# at night, the little aliens' chirps in Galaxity's day, the creek and lake near water, the market's murmur round the
# Market Square, and the mothership's hum near it. The music ducks while someone's talking.
#
# Voices: each line in a conversation plays little blips as it types, pitched for whoever's talking (Rook barks, the
# Green Man hums), on their own "Voices" bus with its own slider in Settings > Audio.

const AMB_DIR := "res://audio/ambience/"
const CHECK_EVERY := 0.5
const AMB_FADE := 2.0
const DUCK_DB := -9.0                         # music under dialogue
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const SCARY := "res://scenes/scary_world/scary_world.tscn"
const SKATE_PARK := Vector3(50, 0, 58)        # Galaxity's Skate Park (tools/build_town.gd SKATE)
const SKATE_YARD := Vector3(30, 0, -100)      # Stars Hollow's Hollow Skate Yard (tools/build_earth.gd YARD)
const MARKET := Vector3(-72, 0, 42)           # Galaxity's Market Square (tools/build_town.gd MARKET)
const LAKE := Vector3(0, 0, 0)                # Galaxity's lake (LAKE_MAIN)
const SKATE_RADIUS := 30.0
# Who sounds like what when they talk: [pitch, blip kind]. Anyone not here gets a pitch made from their name.
const VOICES := {
	"nina": [1.25, "voice"], "nina_earth": [1.25, "voice"], "dash": [1.45, "voice"], "rex": [1.05, "voice"],
	"rook": [1.0, "bark"], "green_man": [0.55, "hum"], "pip": [1.7, "voice"], "bramble": [0.95, "voice"],
	"mr_palmer": [0.75, "voice"], "palmer_earth": [0.75, "voice"], "tally": [1.9, "voice"], "race_starter": [1.8, "voice"],
	"centipede": [0.6, "hum"], "celeste": [1.15, "voice"], "astronaut": [0.85, "voice"],
	"bruno": [1.4, "voice"], "bruno_alien": [1.4, "voice"],
}
const PLAYER_PITCH := 1.3

var _check := 0.0
var _amb: Dictionary = {}                     # ambience name -> AudioStreamPlayer
var _voice: AudioStreamPlayer
var _voice_streams := {}
var _voice_left := 0                          # blips still to go for the line being typed
var _voice_gap := 0.0
var _voice_pitch := 1.0
var _voice_kind := "voice"
var last_track := ""                          # what it picked last (tools/test_soundscape.gd)
var last_ambience: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voices"
	add_child(_voice)
	Dialogue.line_shown.connect(_on_line)
	get_tree().scene_changed.connect(_on_scene_changed)


func _on_scene_changed() -> void:
	_check = 0.0
	# The barn studio's music zone was built as "interior": it's the dance class's track now
	var s := get_tree().current_scene
	if s:
		var studio := s.find_child("StudioMusic", true, false)
		if studio and str(studio.get("track")) == "interior" and Audio.music_path("barn_dance") != "":
			studio.set("track", "barn_dance")


func _process(delta: float) -> void:
	Audio.duck(DUCK_DB if Dialogue.is_active() else 0.0)
	_voices(delta)
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK_EVERY
	var track := Audio.wanted_track()
	if track != Audio.current_track():
		Audio.music(track)
	last_track = track
	_ambience(pick_ambience())


# -----------------------------------------------------------------------------
# Music
# -----------------------------------------------------------------------------
func pick_track() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	var path := scene.scene_file_path
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if Races.racing():
		return "race"
	if player:
		for b in get_tree().get_nodes_in_group("bosses"):
			if not b.get("defeated") and b.get("_was_chasing") and (b as Node3D).global_position.distance_to(player.global_position) < 30.0:
				return "gloop_king"
	if path == EARTH and Festival.is_on() and player and _flat(player.global_position) < 45.0:
		return "festival"
	var zone := Audio.zone_track()
	if zone != "":
		return zone
	if path == SCARY:
		return "scary_world"
	if player and path == TOWN and _flat(player.global_position - SKATE_PARK) < SKATE_RADIUS:
		return "skate_park"
	if player and path == EARTH and _flat(player.global_position - SKATE_YARD) < SKATE_RADIUS:
		return "skate_park"
	if path == TOWN:
		return "town_day" if Clock.daylight() > 0.35 else "town_night"
	if path == EARTH:
		var h := Clock.earth_minutes / 60.0
		return "earth_day" if h >= 6.5 and h < 19.5 else "earth_night"
	return ""                                 # anywhere else: scripts/audio.gd's own SCENE_MUSIC


# -----------------------------------------------------------------------------
# Ambience
# -----------------------------------------------------------------------------
func pick_ambience() -> Array[String]:
	var out: Array[String] = []
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if scene == null or player == null or Audio.zone_track() != "":
		return out                            # indoors (a music zone): no birds in the bakery
	var p := player.global_position
	match scene.scene_file_path:
		EARTH:
			var h := Clock.earth_minutes / 60.0
			out.append("birds" if h >= 6.0 and h < 19.0 else "wind")
			var pond := Vector2(EarthLand.POND.x, EarthLand.POND.y)
			if EarthLand.creek_distance(p.x, p.z) < 18.0 or Vector2(p.x, p.z).distance_to(pond) < 34.0:
				out.append("water")                # Whisper Creek, Mossy Falls and Willow Pond
		TOWN:
			out.append("alien_chirps" if Clock.daylight() > 0.35 else "wind")
			if _flat(p - LAKE) < 50.0:
				out.append("water")
			if _flat(p - MARKET) < 32.0:
				out.append("market")
			var ship := scene.find_child("Mothership", true, false) as Node3D
			if ship and ship.global_position.distance_to(p) < 45.0:
				out.append("mothership_hum")
		SCARY:
			out.append("wind")
	return out


func _ambience(want: Array[String]) -> void:
	last_ambience = want
	for name in want:
		if not _amb.has(name):
			var path := AMB_DIR + name + ".ogg"
			if not ResourceLoader.exists(path):
				continue
			var p := AudioStreamPlayer.new()
			p.name = name
			p.bus = "SFX"
			var stream := (load(path) as AudioStream).duplicate()
			if stream is AudioStreamOggVorbis:
				stream.loop = true
			p.stream = stream
			p.volume_db = -60.0
			add_child(p)
			p.play(randf() * 10.0)
			_amb[name] = p
		var pl: AudioStreamPlayer = _amb[name]
		var level := -17.0 if name in ["market", "mothership_hum"] else -20.0
		if not pl.has_meta("tw") or not (pl.get_meta("tw") as Tween).is_valid() or float(pl.get_meta("to", 0.0)) != level:
			_fade(pl, level)
	for name in _amb.keys():
		if not name in want:
			var pl: AudioStreamPlayer = _amb[name]
			if float(pl.get_meta("to", 0.0)) != -60.0:
				_fade(pl, -60.0)


func _fade(pl: AudioStreamPlayer, to: float) -> void:
	if pl.has_meta("tw"):
		var old: Tween = pl.get_meta("tw")
		if old.is_valid():
			old.kill()
	pl.set_meta("to", to)
	var tw := create_tween()
	tw.tween_property(pl, "volume_db", to, AMB_FADE)
	pl.set_meta("tw", tw)


func playing_ambience() -> Array[String]:
	var out: Array[String] = []
	for name in _amb:
		if float((_amb[name] as AudioStreamPlayer).get_meta("to", -60.0)) > -60.0:
			out.append(name)
	return out


# -----------------------------------------------------------------------------
# Voices
# -----------------------------------------------------------------------------
func voice_of(id: String, speaker: String) -> Array:
	# [pitch, kind] for a line: the player's own lines, a character by id, or a pitch made from the name
	if speaker == Dialogue.player_name():
		return [PLAYER_PITCH, "voice"]
	if VOICES.has(id):
		return VOICES[id]
	var h := absi(hash(speaker if speaker != "" else id)) % 100
	return [0.8 + h / 100.0, "voice"]


func _on_line(speaker: String, text: String) -> void:
	if speaker == "":
		return                                # narration is quiet
	var v := voice_of(str(Dialogue.get("_id")), speaker)
	_voice_pitch = float(v[0])
	_voice_kind = str(v[1])
	if _voice_kind == "bark":
		Audio.play("bark", -6.0, 0.1)        # Rook just says woof
		_voice_left = 0
		return
	_voice_left = clampi(text.length() / 9, 2, 9) if _voice_kind == "voice" else 1
	_voice_gap = 0.0


func _voices(delta: float) -> void:
	if _voice_left <= 0:
		return
	_voice_gap -= delta
	if _voice_gap > 0.0:
		return
	_voice_left -= 1
	_voice_gap = 0.075 + randf() * 0.04
	if not _voice_streams.has(_voice_kind):
		_voice_streams[_voice_kind] = _make_voice(_voice_kind)
	_voice.stream = _voice_streams[_voice_kind]
	_voice.pitch_scale = _voice_pitch * (1.0 + randf_range(-0.08, 0.08))
	_voice.volume_db = -12.0
	_voice.play()


func blips_left() -> int:
	return _voice_left


func _make_voice(kind: String) -> AudioStreamWAV:
	# A short vowel-ish "bah" (two partials, a quick swell), or a long soft hum for the Green Man
	var rate := 22050
	var length := 0.06 if kind == "voice" else 0.5
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var f := t / length
		var env := sin(PI * f)
		var v := (sin(TAU * 330.0 * t) + 0.5 * sin(TAU * 660.0 * t) + 0.25 * sin(TAU * 990.0 * t)) * env * 0.4 \
			if kind == "voice" else sin(TAU * 140.0 * t) * env * 0.5 * (1.0 + 0.2 * sin(TAU * 5.0 * t))
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()

extends AudioStreamPlayer3D

# A sound that loops where it is, like a waterfall's rush: res://audio/sfx/<sound>.wav, played on repeat (it fades
# with distance). Made seamless by tools/make_world_sfx.gd.

@export var sound := "waterfall"


func _ready() -> void:
	var s := load("res://audio/sfx/%s.wav" % sound) as AudioStreamWAV
	if s == null:
		return
	s = s.duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / 2                   # 16-bit mono: 2 bytes a sample
	stream = s
	bus = "SFX"
	play()

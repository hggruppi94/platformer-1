extends "res://scripts/portal_world.gd"

# The Tide Reef, the octopus's home world (plan item 19a world 5; scene built by tools/build_tide_reef.gd). A reef
# city of coral houses and bubble lamps that should be under the sea. The Riptide Gloop (scripts/riptide_gloop.gd)
# swallowed the tide, so it's stuck out: the sea bed's bare, the tide pools are dry and cracked, and the corals are
# going pale.
#
# Otto the octopus (a working name: Hayden may rename him) is the chosen one here. From the story notes
# (story/how-it-fits.md): he has a disability, at first he seems useless and doesn't believe in himself, and his
# strengths turn out to be a big part of the answer. In the game: he gets about in a bubble chair he blew himself, and
# it only drifts along when a friend goes with it, so once you've said hello he comes with you (you're his helper, and
# he never stops needing one: nothing about him gets "fixed"). Everyone else left when the tide went and he couldn't
# keep up. Every puzzle here is one only he can do:
#   Pearl1  the Clam Vault: eight latches that all have to turn at once. He has eight arms (open_vault())
#   Pearl2  the Kelp Grotto: three deep holes. You're the eyes (one has a glint in it, the others have eyes blinking
#           back), Otto's the reach (try_hole())
#   Pearl3  the top of the Coral Spire: he blows bubble steps up it (blow_steps(); each pops a moment after you land on
#           it and he blows it again), and you ride one of his bubbles down (ride_bubble())
# With all three Tide Pearls the Riptide Gloop wakes in the Deep Basin. It's too slippery to pop until Otto wraps his
# arms round it and holds it still (grab(), every few seconds): the friend who thought he was no use saves the day.
# Popping it mends the world (Portals.clear): the tide comes back in, the pools fill, the corals bloom and the sky
# clears.
#
# Slice two, the reward (Hayden: "a quest that starts above water and allows you to unlock [Otto's] ability that
# allows you to swim underwater"): once Otto's said thank you he blows you a bubble for your head and teaches you to
# swim (scripts/swim.gd: Jump to rise, Roll to dive), and then the sea comes right back in, over the houses and the
# spire (set_flood()). The reef's under the sea again for good. Five sea lanterns drifted in with the tide, high up in
# the water; swim up and nudge each one alight (found lamp_1..5), and the tide washes the reef's old chest into
# the Deep Basin (found chest: Remnants and sparkles). Swimming works in any deep water after that (Willow Pond, and
# Otto's Reef Pool by the Void's lake, scripts/reef_pool.gd).

const RIPTIDE := preload("res://scripts/riptide_gloop.gd")
const SHOT_TARGET := preload("res://scripts/shot_target.gd")
const PEARL_NAMES := ["the Clam Vault's pearl", "the Kelp Grotto's pearl", "the Coral Spire's pearl"]
const OTTO_NEAR := 9.0                   # how close Otto has to be to help with something
const OTTO_GAP := 2.6                    # how close he floats to you
const OTTO_SPEED := 9.0
const STEP_HOLD := 2.0                   # seconds a bubble step lasts once you're standing on it
const STEP_BACK := 2.5                   # ...and how long before Otto's blown it again
const STEPS_FAR := 26.0                  # walk this far from the Bubble Pad and the steps pop (Otto comes with you)
const RIDE_SPEED := 8.0
const WAKE_NEAR := 16.0
const GRAB_FIRST := 5.0                  # seconds into the fight before Otto works out what he can do
const GRAB_EVERY := 6.0                  # seconds between holds
const HOLD_TIME := 5.0
const PROUD_AFTER := 3.5
const BUBBLES := 36
const FISH := 14
const PEARL := Color(1.0, 0.86, 0.95)
const SEA := Color(0.3, 0.75, 0.95)
const OTTO_ORANGE := Color(1.0, 0.56, 0.36)
const FLOOR_R := 48.0                    # the sea bed's radius (tools/build_tide_reef.gd)
const SEA_TOP := 13.0                    # the sea's surface once it's right back in: over the houses and the spire
const FLOOD_TIME := 10.0
const TEACH_AFTER := 1.0
# The sea lanterns, high up in the water once the reef's flooded: over a house, the spire, the basin...
const LAMPS := [Vector3(-10.5, 8.0, 14.0), Vector3(26.0, 9.0, -22.0), Vector3(-36.0, 8.5, -6.0), Vector3(0.0, 10.5, -30.0),
	Vector3(-23.0, 12.0, -19.0)]
const LAMP_REACH := 1.9
const LAMP_COLOURS := [Color(1.0, 0.5, 0.8), Color(0.4, 0.95, 1.0), Color(0.75, 0.55, 1.0), Color(1.0, 0.85, 0.4),
	Color(0.5, 1.0, 0.7)]
const CHEST_AT := Vector3(0, 0, -27.5)    # in the Deep Basin, where the Gloop sat
const CHEST_REMNANTS := 4
const CHEST_SPARKLES := 10
const JUNK := ["an old boot!", "a cross crab!", "a rusty tin can.",
	"a sock. Whose sock?"]

# The tide out (stuck) and in (mended): the sky, the light and the haze lerp between these (set_tide)
const DRY := {"top": Color(0.62, 0.68, 0.7), "horizon": Color(0.86, 0.78, 0.62), "ambient": Color(0.9, 0.84, 0.74),
	"fog": Color(0.82, 0.74, 0.58), "density": 0.004, "light": Color(1.0, 0.93, 0.8), "energy": 0.8}
const WET := {"top": Color(0.2, 0.55, 0.9), "horizon": Color(0.65, 0.92, 0.95), "ambient": Color(0.8, 0.95, 1.0),
	"fog": Color(0.6, 0.9, 0.95), "density": 0.002, "light": Color(1.0, 0.98, 0.9), "energy": 0.95}

var tide := 0.0                          # 0 = stuck out, 1 = back in
var flood := 0.0                         # 0 = just the pools, 1 = the sea right in over everything
var flooding := false
var right_hole := 0                      # which of the grotto's holes the pearl's down
var wrong_tries := 0
var steps_up := false
var riding := false
var riptide: CharacterBody3D
var riptide_awake := false
var grabs := 0
var _t := 0.0
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _corals: Array = []                  # [material, its full colour] for everything that goes pale
var _otto: Node3D
var _otto_model: Node3D
var _otto_home := Vector3.ZERO
var _reaches: Array = []                 # Otto's long arms, while they're out: {holder, to, node, t, life}
var _steps: Array = []                   # the bubble steps: {body, shape, mesh, t, back, on}
var _blow_i := 0
var _blow_t := 0.0
var _ride_d := 0.0
var _ride_path: Path3D
var _ride_bubble: MeshInstance3D
var _grab_cd := 0.0
var _bubbles: Array = []
var _fish: Array = []
var _glints: Array = []
var _sea: Node3D                         # the flooded sea: a scripts/water.gd node over the whole reef
var _sea_top: MeshInstance3D
var _rays: Node3D
var _lamps: Array = []                   # [node, its glow material, its light]
var _chest: Node3D


func picture() -> void:
	# In the portal's preview: the reef as it is now, Otto in his bubble chair, a pearl on the spire, the Gloop asleep
	_own_sky()
	_own_corals()
	_add_sea_life()
	var mended := Portals.is_cleared(world_id)
	_add_sea()
	set_tide(1.0 if mended else 0.0)
	set_flood(1.0 if mended else 0.0)
	var o := get_node_or_null("Otto") as Node3D
	if o:
		_otto_model = otto_model()
		o.add_child(_otto_model)
	if not mended:
		var p := get_node_or_null("Pearl3") as Node3D
		if p:
			p.add_child(pearl_model())
		var g := get_node_or_null("RiptideGloop") as Node3D
		if g:
			g.add_child(sleeping_gloop_model())


func setup() -> void:
	_own_sky()
	_own_corals()
	_add_sea_life()
	_add_otto()
	_add_vault()
	_add_grotto()
	_add_steps()
	_add_spire_top()
	if not is_mended():
		_add_riptide()
	_add_sea()
	_add_lamps()
	set_tide(1.0 if is_mended() else 0.0)
	set_flood(1.0 if is_mended() else 0.0)
	if is_mended() and not Portals.has_found(world_id, "swim_taught"):
		get_tree().create_timer(TEACH_AFTER).timeout.connect(_teach_swim)    # mended before Otto could teach you
	if not is_mended() and pearls() == 0 and not Portals.has_found(world_id, "met_otto"):
		Game.message.call_deferred("The Tide Reef: a sea town... with no sea!")


func _own_sky() -> void:
	# Each copy of the world gets its own sky, so the tide coming in here never changes the portal's preview
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		_env = we.environment.duplicate(true) as Environment
		we.environment = _env
		_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_sun = get_node_or_null("Sun") as DirectionalLight3D


func _own_corals() -> void:
	# ...and its own copies of the corals' colours (the builder's "Coral" materials), to fade and bloom
	_corals = []
	var copies := {}
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var m := mi.material_override as StandardMaterial3D
		if m == null or not m.resource_name.begins_with("Coral"):
			continue
		if not copies.has(m):
			var mine := m.duplicate() as StandardMaterial3D
			copies[m] = mine
			_corals.append([mine, m.albedo_color])
		mi.material_override = copies[m]


func is_mended() -> bool:
	return Portals.is_cleared(world_id)


# The tide ------------------------------------------------------------------------------------------------------------
func set_tide(k: float) -> void:
	# From stuck out (0: a dusty sky, pale corals, dry cracked beds) to back in (1: a clear sea-blue sky, the corals in
	# full colour, the pools full, bubbles and fish)
	tide = clampf(k, 0.0, 1.0)
	if _sky:
		_sky.sky_top_color = (DRY.top as Color).lerp(WET.top, tide)
		_sky.sky_horizon_color = (DRY.horizon as Color).lerp(WET.horizon, tide)
		_sky.ground_horizon_color = (DRY.horizon as Color).lerp(WET.horizon, tide)
		_sky.ground_bottom_color = Color(0.7, 0.62, 0.5).lerp(Color(0.25, 0.6, 0.8), tide)
	if _env:
		_env.ambient_light_color = (DRY.ambient as Color).lerp(WET.ambient, tide)
		_env.fog_light_color = (DRY.fog as Color).lerp(WET.fog, tide)
		_env.fog_density = lerpf(DRY.density, WET.density, tide)
	if _sun:
		_sun.light_color = (DRY.light as Color).lerp(WET.light, tide)
		_sun.light_energy = lerpf(DRY.energy, WET.energy, tide)
	for c in _corals:
		var full: Color = c[1]
		(c[0] as StandardMaterial3D).albedo_color = pale(full).lerp(full, tide)
	var pools := get_node_or_null("Tide Pools")
	if pools:
		var level := float(pools.get("water_y"))
		for p in pools.get_children():
			var surface := p.get_node_or_null("Surface") as Node3D
			if surface:
				surface.visible = tide > 0.02
				surface.position.y = lerpf(0.05, level, tide)
			var cracks := p.get_node_or_null("Cracks") as Node3D
			if cracks:
				cracks.visible = tide < 0.5
		# Only once it's right in is it water to wade in (scripts/water.gd reads the outline)
		var outline: Array[Vector4] = []
		if tide >= 0.999:
			for e in pools.get_meta("beds", []):
				outline.append(e)
		pools.set("ellipses", outline)
	var life := get_node_or_null("Sea Life") as Node3D
	if life:
		life.visible = tide > 0.5


static func pale(c: Color) -> Color:
	# A coral's colour when it's drying out: washed nearly to bone
	return c.lerp(Color(0.8, 0.76, 0.68), 0.66)


func in_tide_pool(p: Vector3) -> bool:
	var pools := get_node_or_null("Tide Pools")
	return pools != null and pools.call("covers", p.x, p.z) and p.y - 0.8 < float(pools.get("water_y"))


# The Tide Pearls ---------------------------------------------------------------------------------------------------
func has_pearl(i: int) -> bool:
	return is_mended() or Portals.has_found(world_id, "pearl_%d" % (i + 1))


func pearls() -> int:
	var n := 0
	for i in 3:
		if has_pearl(i):
			n += 1
	return n


func take_pearl(i: int) -> void:
	if has_pearl(i):
		return
	Portals.note_found(world_id, "pearl_%d" % (i + 1))
	var m := get_node_or_null("Pearl%d" % (i + 1)) as Node3D
	var at := m.global_position if m else Vector3.ZERO
	if m:
		for n in ["Tide Pearl", "Spot"]:
			var x := m.get_node_or_null(n)
			if x:
				x.queue_free()
	if i == 1:
		at = (get_node("Hole%d" % (right_hole + 1)) as Node3D).global_position + Vector3(-0.6, 1.2, 0)
		_show_glints()
	Fx.burst(self, at + Vector3(0, 1.0, 0), PEARL, 30, 0.1, 4.0, -1.0, 1.0)
	Juice.blip("sparkle", 1.0 + pearls() * 0.15, -3.0)
	Juice.rumble(0.3, 0.2)
	var n := pearls()
	Game.message(("You've got %s! (%d of 3)%s" % [PEARL_NAMES[i], n, " Now ride one of Otto's bubbles back down!" if i == 2 else ""]) if n < 3
		else "All three Tide Pearls! Something big went GLOOP...")


func _put_pearl(i: int, radius := 2.4) -> void:
	# A pearl to pick up (Interact, or just walk into it)
	var m := get_node_or_null("Pearl%d" % (i + 1)) as Node3D
	if m == null or has_pearl(i) or m.get_node_or_null("Tide Pearl"):
		return
	var p := pearl_model()
	p.name = "Tide Pearl"
	m.add_child(p)
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "" if has_pearl(i) else "pick up the Tide Pearl",
		func() -> void: take_pearl(i), radius, 2.2)
	spot.name = "Spot"
	m.add_child(spot)


func _process_pearls(player: Node3D) -> void:
	for i in [0, 2]:
		if has_pearl(i):
			continue
		var m := get_node_or_null("Pearl%d" % (i + 1)) as Node3D
		if m and m.get_node_or_null("Tide Pearl") and player.global_position.distance_to(m.global_position + Vector3(0, 0.9, 0)) < 1.3:
			take_pearl(i)


# Otto ----------------------------------------------------------------------------------------------------------------
func met_otto() -> bool:
	return Portals.has_found(world_id, "met_otto")


func _add_otto() -> void:
	var m := get_node_or_null("Otto") as Node3D
	if m == null:
		return
	_otto_home = m.global_position
	_otto = Node3D.new()
	_otto.name = "Otto the Octopus"
	add_child(_otto)
	_otto.global_position = _otto_home
	_otto.rotation.y = m.rotation.y
	_otto_model = otto_model()
	_otto_model.name = "Model"
	_otto.add_child(_otto_model)
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "" if riding else "talk to Otto", _talk_otto, 2.6, 2.6)
	spot.name = "Spot"
	_otto.add_child(spot)


func otto_at() -> Vector3:
	return _otto.global_position if _otto else Vector3.ZERO


func otto_near(p: Vector3, reach := OTTO_NEAR) -> bool:
	return _otto != null and Vector2(p.x - _otto.global_position.x, p.z - _otto.global_position.z).length() < reach


func otto_goal(player: Node3D) -> Vector3:
	# Where Otto's bubble wants to be: at the edge of the fight, at the Bubble Pad while he's blowing steps, with you
	# once you've met, and otherwise where he was left when the tide went
	if riptide_awake and not is_mended():
		var perch := get_node_or_null("OttoPerch") as Node3D
		if perch:
			return perch.global_position
	if steps_up:
		var pad := get_node_or_null("BubblePad") as Node3D
		if pad:
			return pad.global_position + Vector3(1.8, 0, 1.4)
	if met_otto() and player:
		var away := _otto.global_position - player.global_position
		away.y = 0.0
		if away.length() < OTTO_GAP + 0.6:
			return _otto.global_position
		var to := player.global_position + away.normalized() * OTTO_GAP
		return Vector3(to.x, 0, to.z)
	return _otto_home


func _otto_step(player: Node3D, delta: float) -> void:
	if _otto == null:
		return
	var goal := otto_goal(player)
	var to := Vector3(goal.x - _otto.global_position.x, 0, goal.z - _otto.global_position.z)
	var d := to.length()
	var moving := d > 0.15
	if moving:
		_otto.global_position += to / d * minf(minf(d * 2.5, OTTO_SPEED) * delta, d)
	if flood > 0.5 and met_otto() and player:
		# Under the sea his bubble floats up and down with you too
		var want := clampf(player.global_position.y - 0.4, _otto_home.y, sea_level() - 1.2)
		_otto.global_position.y = move_toward(_otto.global_position.y, want, OTTO_SPEED * 0.5 * delta)
	else:
		_otto.global_position.y = move_toward(_otto.global_position.y, _otto_home.y, OTTO_SPEED * delta)
	# He looks at whatever he's doing: the Gloop in a fight, otherwise you
	var look := player.global_position if player else Vector3.ZERO
	if riptide_awake and riptide and is_instance_valid(riptide):
		look = riptide.global_position
	var flat := Vector3(look.x - _otto.global_position.x, 0, look.z - _otto.global_position.z)
	if flat.length() > 0.3:
		_otto.rotation.y = lerp_angle(_otto.rotation.y, atan2(flat.x, flat.z), minf(1.0, delta * 5.0))
	_wiggle(_otto_model, _t, 1.0 if moving else 0.5)


func otto_lines() -> Array:
	# Otto's gentle and sure he's no use, until he finds out what eight arms can do
	if is_mended() and not Portals.has_found(world_id, "thanked"):
		Portals.note_found(world_id, "thanked")
		return ["Listen! The sea's coming HOME!",
			"And who held the Gloop still? ME!"]
	if is_mended() and flood > 0.5:
		if lamps_lit() < LAMPS.size():
			return ["Isn't it lovely, being under the sea again? Look at the fish!",
				"Swim up and light the sea lanterns! %d to go!" % (LAMPS.size() - lamps_lit()),
				"{jump} swims up, {dash} dives!"]
		if not chest_open():
			return ["All lit! Is that... the Reef Chest?",
				"Swim down and open it!"]
		return [["Everybody's swimming home!"],
			["You can swim anywhere deep now! Even on Earth!"],
			["Eight arms! Very useful!"]].pick_random()
	if is_mended():
		return [["Listen! The sea's coming HOME!"],
			["Eight arms! Very useful!"],
			["The pools are full! Let's paddle!",
			"The corals went pink again! And purple!"]].pick_random()
	if not met_otto():
		Portals.note_found(world_id, "met_otto")
		return ["Oh! Hello. I'm Otto. This bubble's my chair.",
			"It only moves if a friend comes along.",
			"A Gloop swallowed the sea! Three Tide Pearls bring it back.",
			"You'd take me WITH you? Okay!"]
	if riptide_awake:
		if grabs == 0:
			return ["It's HUGE!",
				"...But I've got eight arms!"]
		return ["When I grab it, pop it!",
			"Jump its waves!"]
	var left: Array = []
	for i in 3:
		if not has_pearl(i):
			left.append(["the Clam Vault",
				"the Kelp Grotto",
				"the Coral Spire"][i])
	if left.size() == 0:
		return ["All three! The Gloop's waking up...",
			"I'll come!"]
	var n := 3 - left.size()
	var first := "Stay close, my bubble follows!"
	if n == 1:
		first = "One pearl! And I HELPED!"
	elif n == 2:
		first = "Two pearls! Nobody ever asked me to help before."
	return [first, "Still to find: %s." % "; and ".join(left)]


func _talk_otto() -> void:
	var spot := get_node_or_null("Otto the Octopus/Spot") as Node3D
	if spot:
		var first := not met_otto()
		Dialogue.say(spot, "Otto", otto_lines().map(func(l: String) -> String: return Settings.fill(l)), "tide_reef_otto")
		if first:
			Juice.blip("chime", 1.2, -6.0)


func _need_otto(p: Vector3, what: String) -> bool:
	# Something only Otto can do: says why not if he isn't here to do it. True when he's ready.
	if not met_otto():
		Game.message(what)
		Audio.play("ui_back", -8.0)
		return false
	if not otto_near(p):
		Game.message("Wait for Otto!")
		return false
	return true


# Otto's long arms -------------------------------------------------------------------------------------------------
func reach(to: Vector3, life := 1.4, follow: Node3D = null) -> void:
	# One of Otto's arms stretches out to a spot (or keeps hold of something), then curls back
	if _otto == null or has_meta("preview"):
		return
	var holder := Node3D.new()
	holder.name = "Otto Reach"
	add_child(holder)
	var skin := _mat(OTTO_ORANGE, 0.0, 0.6)
	for j in 16:
		var r := lerpf(0.17, 0.08, j / 15.0)
		_put(holder, _ball(r, 8), skin, Vector3.ZERO).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reaches.append({"holder": holder, "to": to, "node": follow, "t": 0.0, "life": life, "phase": randf() * TAU})


func _move_reaches(delta: float) -> void:
	for r in _reaches.duplicate():
		r.t += delta
		var holder := r.holder as Node3D
		if r.t >= r.life or not is_instance_valid(holder):
			if is_instance_valid(holder):
				holder.queue_free()
			_reaches.erase(r)
			continue
		var to: Vector3 = r.to
		if r.node != null and is_instance_valid(r.node):
			to = (r.node as Node3D).global_position + r.to
		var from := _otto.global_position + Vector3(0, 1.25, 0)
		var out := clampf(r.t / 0.3, 0.0, 1.0) * clampf((r.life - r.t) / 0.3, 0.0, 1.0)
		var side := (to - from).cross(Vector3.UP).normalized()
		var n := holder.get_child_count()
		for j in n:
			var k := float(j) / (n - 1)
			var p := from.lerp(to, k * out)
			p += side * sin(k * 7.0 + _t * 6.0 + r.phase) * 0.22 * sin(k * PI) * out
			p.y += sin(k * PI) * 0.5 * out
			(holder.get_child(j) as Node3D).global_position = p


# The Clam Vault ------------------------------------------------------------------------------------------------------
func vault_open() -> bool:
	return is_mended() or Portals.has_found(world_id, "vault_open")


func _add_vault() -> void:
	var m := get_node_or_null("Vault") as Node3D
	if m == null:
		return
	var spot := USE_SPOT.make(Vector3.ZERO, _vault_offer, open_vault, 2.6, 2.4)
	spot.name = "Spot"
	m.add_child(spot)
	if vault_open():
		_show_vault(1.0)
		for k in 8:
			_turn_latch(k)
		_put_pearl(0)


func _vault_offer() -> String:
	if vault_open():
		return ""
	return "ask Otto to open the Clam Vault" if met_otto() else "look at the Clam Vault"


func open_vault() -> void:
	if vault_open():
		return
	var m := get_node("Vault") as Node3D
	if not _need_otto(m.global_position, "Eight latches! You've only got two hands..."):
		return
	Portals.note_found(world_id, "vault_open")
	Game.message("Otto: \"Eight latches? I've got eight ARMS!\"")
	# One arm to each latch, then they all turn together and the lid swings up
	var vault := get_node("Clam Vault") as Node3D
	for k in 8:
		var latch := vault.get_node_or_null("Latch%d" % (k + 1)) as Node3D
		if latch:
			reach(latch.global_position, 1.9)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(func() -> void:
		for k in 8:
			_turn_latch(k)
		Juice.blip("tick", 1.4, -3.0)
		Juice.rumble(0.3, 0.2))
	tw.tween_interval(0.5)
	tw.tween_method(_show_vault, 0.0, 1.0, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		Fx.burst(self, vault.global_position + Vector3(1.5, 1.6, 0), PEARL, 26, 0.1, 4.0, -1.0, 1.0)
		Juice.blip("chime", 1.0, -4.0)
		Game.message("CLUNK! It's open! Otto: \"I did that?\""))
	_put_pearl(0)


func _turn_latch(k: int) -> void:
	var latch := get_node_or_null("Clam Vault/Latch%d" % (k + 1)) as MeshInstance3D
	if latch == null:
		return
	var gold := _mat(Color(1.0, 0.82, 0.35), 0.6, 0.4)
	latch.material_override = gold
	latch.rotation.y = PI / 2.0
	var handle := latch.get_node_or_null("Handle") as MeshInstance3D
	if handle:
		handle.material_override = gold


func _show_vault(k: float) -> void:
	var lid := get_node_or_null("Clam Vault/Lid") as Node3D
	if lid:
		lid.rotation.z = k * 1.05


# The Kelp Grotto ---------------------------------------------------------------------------------------------------
func _add_grotto() -> void:
	if not has_pearl(1):
		right_hole = randi() % 3
	_glints = []
	for i in 3:
		var m := get_node_or_null("Hole%d" % (i + 1)) as Node3D
		if m == null:
			continue
		var h := float(m.get_meta("height", 1.15))
		# What you can see in each hole: a pearly glint, or a pair of little eyes
		var glint := Node3D.new()
		glint.name = "Glint"
		glint.position = Vector3(0.05, h, 0)
		_put(glint, _ball(0.1, 8), _mat(PEARL, 3.0, 0.2), Vector3.ZERO)
		var light := OmniLight3D.new()
		light.light_color = PEARL
		light.light_energy = 1.0
		light.omni_range = 2.2
		light.position.x = -0.3
		glint.add_child(light)
		m.add_child(glint)
		var eyes := Node3D.new()
		eyes.name = "Eyes"
		eyes.position = Vector3(0.05, h, 0)
		for s in [-1.0, 1.0]:
			_put(eyes, _ball(0.07, 6), _mat(Color(1.0, 0.9, 0.3), 2.0, 0.3), Vector3(0, 0, s * 0.13))
			_put(eyes, _ball(0.035, 6), _mat(Color(0.05, 0.05, 0.05), 0.0, 0.3), Vector3(-0.05, 0, s * 0.13))
		m.add_child(eyes)
		_glints.append([glint, eyes])
		var spot := USE_SPOT.make(Vector3(-0.6, 0, 0), _hole_offer.bind(i), try_hole.bind(i), 1.5, 2.3)
		spot.name = "Spot"
		m.add_child(spot)
	_show_glints()


func _show_glints() -> void:
	for i in _glints.size():
		(_glints[i][0] as Node3D).visible = i == right_hole and not has_pearl(1)
		(_glints[i][1] as Node3D).visible = i != right_hole or has_pearl(1)


func _hole_offer(_i: int) -> String:
	if has_pearl(1):
		return ""
	return "ask Otto to reach in here" if met_otto() else "peer into the hole"


func try_hole(i: int) -> bool:
	# You pick the hole (you can see what's in each one), Otto reaches in. Says whether he found the pearl.
	if has_pearl(1):
		return false
	var m := get_node("Hole%d" % (i + 1)) as Node3D
	var peek := "Something shines down there. Too deep!" if i == right_hole \
		else "Two little eyes blink back. Not this one!"
	if not _need_otto(m.global_position, peek):
		return false
	var deep := m.global_position + Vector3(1.6, float(m.get_meta("height", 1.15)), 0)
	reach(deep, 1.6)
	if i != right_hole:
		wrong_tries += 1
		Juice.blip("buzz", 1.0, -8.0)
		Game.message("Otto pulls out %s Find the shiny hole!" % JUNK[(wrong_tries - 1) % JUNK.size()])
		return false
	Game.message("Otto: \"I've GOT it!\"")
	take_pearl(1)
	return true


# Otto's bubble steps ---------------------------------------------------------------------------------------------
func _add_steps() -> void:
	_steps = []
	var i := 0
	while true:
		var m := get_node_or_null("Step%d" % (i + 1)) as Node3D
		if m == null:
			break
		var body := StaticBody3D.new()
		body.name = "Bubble"
		body.set_meta("step", i)
		var cs := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 1.2
		c.height = 0.3
		cs.shape = c
		cs.disabled = true
		body.add_child(cs)
		var mesh := _put(body, _ball(1.25, 16), bubble_mat(0.45), Vector3(0, -0.2, 0), Vector3(1, 0.42, 1))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.visible = false
		m.add_child(body)
		_steps.append({"body": body, "shape": cs, "mesh": mesh, "t": -1.0, "back": -1.0, "on": false})
		i += 1
	var pad := get_node_or_null("BubblePad") as Node3D
	if pad:
		var spot := USE_SPOT.make(Vector3.ZERO, _pad_offer, blow_steps, 2.2, 2.2)
		spot.name = "Spot"
		pad.add_child(spot)
	_ride_path = get_node_or_null("BubbleRide") as Path3D


func _pad_offer() -> String:
	if steps_up or riding or flood > 0.5:                # under the sea you can just swim up the spire
		return ""
	return "ask Otto to blow bubble steps" if met_otto() else "look at the Bubble Pad"


func blow_steps(at_once := false) -> void:
	# Otto parks at the Bubble Pad and blows a staircase of big bubbles up the spire, one after another
	if steps_up or riding:
		return
	var pad := get_node("BubblePad") as Node3D
	if not _need_otto(pad.global_position, "Too smooth to climb. A bubble blower could help..."):
		return
	steps_up = true
	_blow_i = 0
	_blow_t = 0.0
	Game.message("Otto: \"Bubble steps! Keep hopping!\"")
	if at_once:
		for i in _steps.size():
			_step_show(i, true)
		_blow_i = _steps.size()


func steps_down() -> void:
	steps_up = false
	for i in _steps.size():
		_step_show(i, false)
		_steps[i].t = -1.0
		_steps[i].back = -1.0


func _step_show(i: int, on: bool) -> void:
	var s: Dictionary = _steps[i]
	if s.on == on:
		return
	s.on = on
	(s.body as Node3D).visible = on
	(s.shape as CollisionShape3D).set_deferred("disabled", not on)
	(s.mesh as Node3D).scale = Vector3(1, 0.42, 1)
	if is_inside_tree() and not has_meta("preview"):
		Fx.burst(self, (s.body as Node3D).global_position, Color(0.8, 0.97, 1.0, 0.8), 8, 0.08, 2.5, -1.0, 0.5)
		Juice.blip("pop", 1.3 + i * 0.06 if on else 0.8, -10.0)


func step_under(player: Node3D) -> int:
	# Which bubble step the player's standing on (-1: none)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(player.global_position, player.global_position + Vector3(0, -1.6, 0))
	q.exclude = [(player as CollisionObject3D).get_rid()] if player is CollisionObject3D else []
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return -1
	var c := hit.collider as Node
	return int(c.get_meta("step")) if c and c.has_meta("step") else -1


func _steps_step(player: CharacterBody3D, delta: float) -> void:
	if not steps_up:
		return
	# He blows them one after another
	if _blow_i < _steps.size():
		_blow_t -= delta
		if _blow_t <= 0.0:
			_blow_t = 0.22
			_step_show(_blow_i, true)
			_blow_i += 1
	for i in _steps.size():
		var s: Dictionary = _steps[i]
		if s.back > 0.0:
			s.back -= delta
			if s.back <= 0.0:
				_step_show(i, true)
		elif s.t > 0.0:
			s.t -= delta
			var k: float = 1.0 - s.t / STEP_HOLD                         # it wobbles harder as it's about to go
			(s.mesh as Node3D).scale = Vector3(1.0 + sin(_t * 22.0) * 0.06 * k, 0.42 - 0.08 * k, 1.0 - sin(_t * 22.0) * 0.06 * k)
			if s.t <= 0.0:
				s.t = -1.0
				s.back = STEP_BACK
				_step_show(i, false)
	if player.is_on_floor():
		var under := step_under(player)
		if under >= 0 and _steps[under].on and _steps[under].t <= 0.0:
			_steps[under].t = STEP_HOLD
		# Wander off along the ground and the steps pop: Otto's bubble comes with you again
		var pad := get_node("BubblePad") as Node3D
		if player.global_position.y < 1.5 and Vector2(player.global_position.x - pad.global_position.x,
				player.global_position.z - pad.global_position.z).length() > STEPS_FAR:
			steps_down()


# The top of the spire, and the bubble ride down --------------------------------------------------------------------
func _add_spire_top() -> void:
	_put_pearl(2, 1.8)
	var top := get_node_or_null("RideTop") as Node3D
	if top == null:
		return
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "" if riding or flood > 0.5 else "ride a bubble down",
		func() -> void: ride_bubble(), 1.6, 2.2)
	spot.name = "Spot"
	top.add_child(spot)
	var b := _put(top, _ball(0.5, 12), bubble_mat(0.4), Vector3(0, 1.0, 0))
	b.name = "Waiting Bubble"
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func ride_bubble() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or riding or _ride_path == null:
		return
	riding = true
	_ride_d = 0.0
	player.set("carried", true)
	Game.hold_controls(&"bubble_ride", true, player)
	player.velocity = Vector3.ZERO
	_ride_bubble = MeshInstance3D.new()
	_ride_bubble.name = "Ride Bubble"
	_ride_bubble.mesh = _ball(1.35, 20)
	_ride_bubble.material_override = bubble_mat(0.35)
	_ride_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ride_bubble)
	Juice.blip("pop", 1.5, -6.0)
	Juice.blip("whoosh", 1.2, -8.0)


func _ride_step(player: CharacterBody3D, delta: float) -> void:
	if not riding or player == null:
		return
	var curve := _ride_path.curve
	var length := curve.get_baked_length()
	_ride_d = minf(_ride_d + RIDE_SPEED * delta, length)
	var at := _ride_path.to_global(curve.sample_baked(_ride_d))
	var ahead := _ride_path.to_global(curve.sample_baked(minf(_ride_d + 0.5, length)))
	at.y += sin(_t * 3.0) * 0.15                                   # a floaty bob
	player.global_position = at
	if is_instance_valid(_ride_bubble):
		_ride_bubble.global_position = at + Vector3(0, 0.1, 0)
		_ride_bubble.scale = Vector3(1.0 + sin(_t * 5.0) * 0.04, 1.0 - sin(_t * 5.0) * 0.04, 1.0 + sin(_t * 5.0) * 0.04)
	var visual := player.get_node_or_null("Visual") as Node3D
	if visual and ahead.distance_to(at) > 0.01:
		visual.rotation.y = atan2(ahead.x - at.x, ahead.z - at.z)
	if _ride_d >= length - 0.05:
		end_ride(player)


func end_ride(player: CharacterBody3D) -> void:
	riding = false
	player.set("carried", false)
	player.velocity = Vector3(0, 1.5, 0)
	if is_instance_valid(_ride_bubble):
		_ride_bubble.queue_free()
	Fx.burst(self, player.global_position, Color(0.8, 0.97, 1.0), 24, 0.1, 4.0, -3.0, 0.8)
	Juice.blip("pop", 0.9, -3.0)
	steps_down()
	if not Portals.has_found(world_id, "rode_bubble"):
		Portals.note_found(world_id, "rode_bubble")
		Game.message("Wheeee... POP!")
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if is_instance_valid(player):
			Game.hold_controls(&"bubble_ride", false, player))


# The Riptide Gloop -------------------------------------------------------------------------------------------------
func _add_riptide() -> void:
	var m := get_node_or_null("RiptideGloop") as Node3D
	if m == null:
		return
	var g := (load("res://scenes/enemies/gloop_king.tscn") as PackedScene).instantiate() as CharacterBody3D
	g.set_script(RIPTIDE)
	g.name = "The Riptide Gloop"                             # not "Gloop …", so finding Gloops by name skips it
	g.set("world", self)
	g.set("size", 2.4)
	g.set("color", SEA)
	g.set("goldness", 0.5)
	g.set("stomps_to_defeat", 10)
	g.set("damage", 2)
	g.set("xp_reward", 45)
	g.set("wander_radius", 5.0)
	g.set("sight_range", 18.0)
	g.set("leash_range", 20.0)
	g.set("wander_speed", 1.0)
	g.set("chase_speed", 2.6)
	g.set("respawns", false)
	g.process_mode = Node.PROCESS_MODE_DISABLED             # fast asleep until the pearls wake it
	add_child(g)
	g.global_position = m.global_position
	riptide = g
	var snore := Label3D.new()
	snore.name = "Snoring"
	snore.text = "z Z z"
	snore.font_size = 96
	snore.pixel_size = 0.012
	snore.outline_size = 14
	snore.modulate = Color(0.8, 0.95, 1.0)
	snore.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	snore.position = Vector3(0.8, 4.4, 0)
	m.add_child(snore)
	var spot := USE_SPOT.make(Vector3(0, -0.3, 4.0), func() -> String: return "" if riptide_awake else "look at the sleeping Gloop",
		_look_at_riptide, 2.8, 3.0)
	spot.name = "Spot"
	m.add_child(spot)


func _look_at_riptide() -> void:
	if riptide_awake:
		return
	var left := 3 - pearls()
	Game.message("A huge sleeping Gloop, full of sea! %s" %
		("The %d Tide Pearl%s would wake it." % [left, "" if left == 1 else "s"]) if left > 0 else "It's stirring...")
	Audio.play("ui_back", -8.0)


func wake_riptide() -> void:
	if riptide_awake or riptide == null or not is_instance_valid(riptide):
		return
	riptide_awake = true
	grabs = 0
	_grab_cd = GRAB_FIRST
	for n in ["RiptideGloop/Snoring", "RiptideGloop/Spot"]:
		var x := get_node_or_null(n)
		if x:
			x.queue_free()
	steps_down()
	riptide.process_mode = Node.PROCESS_MODE_INHERIT
	Fx.burst(self, riptide.global_position + Vector3(0, 2.0, 0), SEA, 40, 0.12, 6.0, -5.0, 1.2)
	Juice.shake(0.35)
	Juice.rumble(0.5, 0.3, 0.5)
	Juice.blip("pop", 0.5, -2.0)
	Game.message("It's awake! Too slippery to pop!")


func grab() -> bool:
	# Otto wraps his arms round the Gloop and holds it still: now it can be popped
	if not riptide_awake or riptide == null or not is_instance_valid(riptide) or riptide.get("defeated") or riptide.get("held"):
		return false
	riptide.call("hold", HOLD_TIME)
	_grab_cd = HOLD_TIME + GRAB_EVERY
	grabs += 1
	for k in 4:
		var a := k * TAU / 4.0
		reach(Vector3(cos(a) * 1.6, 1.2 + (k % 2) * 0.9, sin(a) * 1.6), HOLD_TIME, riptide)
	Juice.blip("chime", 0.9, -5.0)
	Juice.rumble(0.3, 0.2)
	Game.message("Otto: \"I'VE GOT IT! Pop it NOW!\"" if grabs == 1
		else ["Otto: \"GOT it! Now, now, now!\"", "Otto: \"I'm holding on! Pop it!\"", "Otto: \"It's not going ANYWHERE! Go!\""].pick_random())
	return true


func _boss_step(player: Node3D, delta: float) -> void:
	if is_mended() or riptide == null or not is_instance_valid(riptide):
		return
	if not riptide_awake:
		var m := get_node_or_null("RiptideGloop") as Node3D
		if pearls() == 3 and not riding and m and player.global_position.distance_to(m.global_position) < WAKE_NEAR:
			wake_riptide()
		return
	# Otto grabs it every few seconds, once his bubble's at the edge of the basin
	_grab_cd -= delta
	var perch := get_node_or_null("OttoPerch") as Node3D
	if _grab_cd <= 0.0 and perch and otto_near(perch.global_position, 3.0):
		grab()


func mend() -> void:
	# The tide's let go: it comes rushing back in, the pools fill, the corals bloom and the sky clears
	riptide_awake = false
	if riptide and is_instance_valid(riptide):
		for g in riptide.get("_court"):                  # its Splash Gloops wash away with it
			if is_instance_valid(g) and not g.defeated:
				g.shot(99, g.global_position, Vector3.UP)
	for r in _reaches:
		r.life = minf(r.life, r.t + 0.3)
	Portals.clear(world_id)
	var tw := create_tween()
	tw.tween_method(set_tide, tide, 1.0, 6.0).set_trans(Tween.TRANS_SINE)
	var m := get_node_or_null("RiptideGloop") as Node3D
	if m:
		Fx.burst(self, m.global_position + Vector3(0, 2.5, 0), SEA, 60, 0.14, 8.0, -6.0, 1.6)
		Fx.burst(self, m.global_position + Vector3(0, 2.5, 0), Color(1, 1, 1), 40, 0.1, 6.0, -4.0, 1.4)
	Audio.play("splash", 2.0)
	Juice.shake(0.15)
	Juice.rumble(0.3, 0.3)
	Juice.blip("chime", 0.8, -3.0)
	get_tree().create_timer(PROUD_AFTER).timeout.connect(_proud)


func proud_lines() -> Array:
	# The turn in Otto's story: he saved the day, and he knows it
	return ["Did you SEE? I held it! With MY arms!",
		"I thought I was no use. I was wrong!",
		"I still need my chair. And we always need a friend!"]


func _proud(tries := 0) -> void:
	if not is_inside_tree():
		return
	if Dialogue.is_active() and tries < 20:             # wait for a talk to finish first
		get_tree().create_timer(1.0).timeout.connect(_proud.bind(tries + 1))
		return
	Portals.note_found(world_id, "thanked")
	var spot := get_node_or_null("Otto the Octopus/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Otto", proud_lines().map(func(l: String) -> String: return Settings.fill(l)), "tide_reef_proud")
	get_tree().create_timer(TEACH_AFTER).timeout.connect(_teach_swim)


# Slice two: Otto teaches you to swim, and the sea comes right back in -------------------------------------------
func teach_lines() -> Array:
	# Otto's gift: a bubble for your head, so you can go under with him (scripts/swim.gd)
	return ["The sea's coming back. ALL of it!",
		"Hold still... a bubble helmet! You'll never run out of air!",
		"Now swim! {jump} goes up, {dash} goes down.",
		"And Dash's Jelly Mines blueprint. For you!",
		"Here comes the sea! Hold on!"]


func _teach_swim(tries := 0) -> void:
	if not is_inside_tree() or Portals.has_found(world_id, "swim_taught"):
		return
	if Dialogue.is_active() and tries < 30:             # wait for his thank-you to finish first
		get_tree().create_timer(1.0).timeout.connect(_teach_swim.bind(tries + 1))
		return
	teach_swim()
	var spot := get_node_or_null("Otto the Octopus/Spot") as Node3D
	if not Portals.practice:
		Schematics.award("jelly", spot != null)           # (his last line says it; Schematics.LIST "jelly")
	if spot:
		Dialogue.say(spot, "Otto", teach_lines().map(func(l: String) -> String: return Settings.fill(l)), "tide_reef_swim")
	else:
		Game.message("New: Swim! %s up, %s down." % [Settings.prompt("jump"), Settings.prompt("dash")])
	_flood_when_quiet()


func teach_swim() -> void:
	Portals.note_found(world_id, "swim_taught")
	Juice.blip("chime", 1.1, -3.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		Fx.burst(self, player.global_position + Vector3(0, 0.7, 0), Color(0.85, 0.97, 1.0, 0.8), 24, 0.09, 2.0, 0.5, 1.0)


func _flood_when_quiet(tries := 0) -> void:
	if not is_inside_tree():
		return
	if Dialogue.is_active() and tries < 60:
		get_tree().create_timer(0.5).timeout.connect(_flood_when_quiet.bind(tries + 1))
		return
	start_flood()


func start_flood(seconds := FLOOD_TIME) -> void:
	# The sea pours in from the reef walls and rises right over everything
	if flooding or flood >= 1.0:
		return
	flooding = true
	var tw := create_tween()
	tw.tween_method(set_flood, flood, 1.0, seconds).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		flooding = false
		Game.message("The reef's under the sea! Light five sea lanterns."))
	Audio.play("splash", 3.0)
	Juice.rumble(0.35, 0.2, seconds * 0.5)
	if not Settings.reduce_motion:
		Juice.shake(0.12)


func sea_level() -> float:
	var pools := get_node_or_null("Tide Pools")
	var low := float(pools.get("water_y")) if pools else 0.3
	return lerpf(low, SEA_TOP, flood)


func set_flood(k: float) -> void:
	# From the pools full (0) to the whole reef under the sea (1): the sea's surface rises, light shafts come down
	# through it, bubbles stream up from the sea bed and the fish swim about instead of leaping
	flood = clampf(k, 0.0, 1.0)
	var level := sea_level()
	if _sea:
		_sea.set("water_y", level)
		var outline: Array[Vector4] = []
		if flood > 0.02:
			outline.append(Vector4(0, 0, FLOOR_R + 6.0, FLOOR_R + 6.0))
		_sea.set("ellipses", outline)
	if _sea_top:
		_sea_top.visible = flood > 0.02
		_sea_top.position.y = level
	if _rays:
		_rays.visible = flood > 0.6
	if _sky and flood > 0.0:
		_sky.sky_top_color = (WET.top as Color).lerp(Color(0.1, 0.35, 0.65), flood * 0.6)
	var pools := get_node_or_null("Tide Pools")
	if pools:
		for p in pools.get_children():
			var surface := p.get_node_or_null("Surface") as Node3D
			if surface:
				surface.visible = tide > 0.02 and flood < 0.1           # under the sea there's no telling them apart
	_show_lamps()


func _add_sea() -> void:
	# The sea, ready to come in: a water node over the whole reef (scripts/water.gd, so you splash in and swim:
	# scripts/swim.gd), its surface seen from below, and light shafts slanting down through it
	_sea = Node3D.new()
	_sea.name = "The Sea"
	_sea.set_script(load("res://scripts/water.gd"))
	_sea.set("water_y", -5.0)
	_sea.set("speed_scale", 0.85)
	add_child(_sea)
	_sea_top = MeshInstance3D.new()
	_sea_top.name = "Sea Surface"
	_sea_top.mesh = _cyl(FLOOR_R + 8.0, FLOOR_R + 8.0, 0.05, 48)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.85, 0.95, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.3, 0.7, 0.85)
	m.emission_energy_multiplier = 0.35
	m.roughness = 0.05
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sea_top.material_override = m
	_sea_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sea_top.visible = false
	add_child(_sea_top)
	_rays = Node3D.new()
	_rays.name = "Light Shafts"
	add_child(_rays)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.75, 0.95, 1.0, 0.07)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 14:
		var a := rng.randf() * TAU
		var d := rng.randf_range(4.0, FLOOR_R - 8.0)
		var ray := _put(_rays, _cyl(rng.randf_range(0.6, 1.2), rng.randf_range(2.0, 3.4), SEA_TOP, 10), rm,
			Vector3(cos(a) * d, SEA_TOP * 0.5, sin(a) * d), Vector3.ONE, Vector3(0.22, 0, 0.12))
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ray.set_meta("phase", rng.randf() * TAU)
	_rays.visible = false


# The sea lanterns and the Reef Chest -------------------------------------------------------------------------------
func lamp_lit(i: int) -> bool:
	return Portals.has_found(world_id, "lamp_%d" % (i + 1))


func lamps_lit() -> int:
	var n := 0
	for i in LAMPS.size():
		if lamp_lit(i):
			n += 1
	return n


func chest_open() -> bool:
	return Portals.has_found(world_id, "chest")


func _add_lamps() -> void:
	var holder := Node3D.new()
	holder.name = "Sea Lanterns"
	add_child(holder)
	_lamps = []
	for i in LAMPS.size():
		var g := Node3D.new()
		g.name = "Sea Lantern %d" % (i + 1)
		holder.add_child(g)
		g.position = LAMPS[i]
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(LAMP_COLOURS[i], 0.75)
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.emission_enabled = true
		glow.emission = LAMP_COLOURS[i]
		glow.cull_mode = BaseMaterial3D.CULL_DISABLED
		var dome := _put(g, _ball(0.7, 16), glow, Vector3.ZERO, Vector3(1.0, 0.65, 1.0))
		dome.name = "Dome"
		for k in 6:                                          # dangling tentacles, like a jellyfish
			var a := k * TAU / 6.0
			var t := _put(g, _cyl(0.05, 0.02, 1.3, 5), glow, Vector3(cos(a) * 0.4, -0.75, sin(a) * 0.4))
			t.name = "Tentacle"
		var light := OmniLight3D.new()
		light.light_color = LAMP_COLOURS[i]
		light.omni_range = 9.0
		light.shadow_enabled = false
		g.add_child(light)
		_lamps.append([g, glow, light])
	var c := Node3D.new()
	c.name = "Reef Chest"
	add_child(c)
	c.position = CHEST_AT
	var wood := _mat(Color(0.55, 0.36, 0.22), 0.0, 0.8)
	var gold := _mat(Color(1.0, 0.8, 0.3), 0.3, 0.3)
	_put(c, BoxMesh.new(), wood, Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 1.0))
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.9, -0.5)
	c.add_child(lid)
	_put(lid, BoxMesh.new(), wood, Vector3(0, 0.15, 0.5), Vector3(1.65, 0.3, 1.05))
	_put(lid, BoxMesh.new(), gold, Vector3(0, 0.1, 1.03), Vector3(0.3, 0.3, 0.06))
	for x in [-0.6, 0.6]:
		_put(c, BoxMesh.new(), gold, Vector3(x, 0.45, 0), Vector3(0.1, 0.94, 1.04))
	var shine := _put(c, _ball(0.5, 10), _mat(Color(1.0, 0.9, 0.5), 1.5, 0.3), Vector3(0, 0.9, 0), Vector3(1.2, 0.4, 0.7))
	shine.name = "Treasure"
	var spot := USE_SPOT.make(Vector3(0, 0.6, 0), func() -> String: return "" if chest_open() else "open the Reef Chest",
		open_chest, 2.4, 2.4)
	spot.name = "Spot"
	c.add_child(spot)
	_show_lamps()


func _show_lamps() -> void:
	# The lanterns only drift in with the sea, and the chest only once they're all lit
	var under_sea := flood > 0.9
	for i in _lamps.size():
		var g := _lamps[i][0] as Node3D
		g.visible = under_sea
		var lit := lamp_lit(i)
		var glow := _lamps[i][1] as StandardMaterial3D
		glow.emission_energy_multiplier = 2.2 if lit else 0.15
		glow.albedo_color = Color(LAMP_COLOURS[i], 0.8) if lit else Color(0.5, 0.6, 0.7, 0.55)
		(_lamps[i][2] as OmniLight3D).visible = lit
	if _chest == null:
		_chest = get_node_or_null("Reef Chest") as Node3D
	if _chest:
		_chest.visible = under_sea and lamps_lit() == LAMPS.size()
		var lid := _chest.get_node("Lid") as Node3D
		lid.rotation.x = -1.6 if chest_open() else 0.0
		(_chest.get_node("Treasure") as Node3D).visible = not chest_open()


func light_lamp(i: int) -> void:
	if lamp_lit(i):
		return
	Portals.note_found(world_id, "lamp_%d" % (i + 1))
	var g := _lamps[i][0] as Node3D
	Fx.burst(self, g.global_position, LAMP_COLOURS[i], 26, 0.1, 3.0, 0.5, 1.2)
	Juice.blip("chime", 1.0 + i * 0.12, -4.0)
	Juice.squash(g, 0.3, 0.3)
	var n := lamps_lit()
	if n == LAMPS.size():
		Game.message("All five lit! Something glints down deep...")
		Juice.blip("sparkle", 1.0, -2.0)
	else:
		Game.message("Sea lantern lit! %d of %d." % [n, LAMPS.size()])
	_show_lamps()


func _lamps_step(player: Node3D) -> void:
	if flood < 0.9:
		return
	for i in _lamps.size():
		var g := _lamps[i][0] as Node3D
		g.position.y = (LAMPS[i] as Vector3).y + sin(_t * 1.1 + i) * 0.25           # bobbing gently
		var dome := g.get_node("Dome") as Node3D
		dome.scale = Vector3(1.0 + sin(_t * 2.0 + i) * 0.06, 0.65 - sin(_t * 2.0 + i) * 0.05, 1.0 + sin(_t * 2.0 + i) * 0.06)
		if not lamp_lit(i) and player.global_position.distance_to(g.global_position) < LAMP_REACH:
			light_lamp(i)


func open_chest() -> void:
	if chest_open() or lamps_lit() < LAMPS.size():
		return
	Portals.note_found(world_id, "chest")
	Remnants.add(CHEST_REMNANTS, "the Reef Chest")
	Game.add_sparkles(CHEST_SPARKLES, "the Reef Chest")
	Fx.burst(self, CHEST_AT + Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.4), 40, 0.1, 4.0, 0.5, 1.4)
	Juice.blip("sparkle", 1.0, 0.0)
	Juice.rumble(0.3, 0.15)
	if _chest:
		var lid := _chest.get_node("Lid") as Node3D
		var tw := create_tween()
		tw.tween_property(lid, "rotation:x", -1.6, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		(_chest.get_node("Treasure") as Node3D).visible = false
	var spot := get_node_or_null("Otto the Octopus/Spot") as Node3D
	var lines := ["The Reef Chest!",
		"(Inside: %s!)" % [Remnants.words(CHEST_REMNANTS)],
		"We did it! Thank you, {player}!"]
	if spot:
		Dialogue.say(spot, "Otto", lines.map(func(l: String) -> String: return Settings.fill(l)), "tide_reef_chest")


# Bubbles and fish, once the sea's back ---------------------------------------------------------------------------
func _add_sea_life() -> void:
	var holder := Node3D.new()
	holder.name = "Sea Life"
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var beds: Array = []
	var pools := get_node_or_null("Tide Pools")
	if pools:
		beds = pools.get_meta("beds", [])
	_bubbles = []
	var bm := bubble_mat(0.5)
	for i in BUBBLES:
		var b := _put(holder, _ball(rng.randf_range(0.08, 0.2), 8), bm, Vector3.ZERO)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var home := Vector3(rng.randf_range(-36.0, 36.0), 0.3, rng.randf_range(-36.0, 30.0))
		if beds.size() > 0 and i % 2 == 0:
			var e: Vector4 = beds[i % beds.size()]
			home = Vector3(e.x + rng.randf_range(-e.z, e.z) * 0.6, 0.3, e.y + rng.randf_range(-e.w, e.w) * 0.6)
		b.set_meta("home", home)
		b.set_meta("phase", rng.randf() * 6.0)
		_bubbles.append(b)
	# Little fish that leap out of the pools in arcs
	_fish = []
	var colours := [Color(1.0, 0.6, 0.25), Color(0.4, 0.7, 1.0), Color(1.0, 0.85, 0.3), Color(1.0, 0.5, 0.7)]
	for i in FISH:
		if beds.is_empty():
			break
		var e: Vector4 = beds[i % beds.size()]
		var f := Node3D.new()
		f.name = "Fish %d" % (i + 1)
		var m := _mat(colours[i % colours.size()], 0.2, 0.4)
		_put(f, _ball(0.22, 8), m, Vector3.ZERO, Vector3(0.6, 0.8, 1.5))
		_put(f, _cyl(0.0, 0.16, 0.25, 4), m, Vector3(0, 0, -0.4), Vector3(0.3, 1, 1), Vector3(-PI / 2.0, 0, 0))
		_put(f, _ball(0.04, 6), _mat(Color(0.05, 0.05, 0.05)), Vector3(0.11, 0.06, 0.2))
		holder.add_child(f)
		f.set_meta("from", Vector3(e.x - e.z * 0.5, 0.3, e.y + rng.randf_range(-e.w, e.w) * 0.4))
		f.set_meta("to", Vector3(e.x + e.z * 0.5, 0.3, e.y + rng.randf_range(-e.w, e.w) * 0.4))
		f.set_meta("phase", rng.randf() * 5.0)
		_fish.append(f)
	holder.visible = false


func _move_sea_life() -> void:
	if tide <= 0.5:
		return
	var rise := maxf(7.0, sea_level() - 0.5)                    # under the sea they stream all the way up
	for b in _bubbles:
		var n := b as Node3D
		var home: Vector3 = n.get_meta("home")
		var k := fmod(_t * (0.25 if flood < 0.5 else 0.12) + float(n.get_meta("phase")), 1.0)
		n.position = home + Vector3(sin(k * 9.0) * 0.3, k * rise, cos(k * 7.0) * 0.3)
		n.scale = Vector3.ONE * (0.6 + k * 0.8)
	if _rays and _rays.visible:
		for r in _rays.get_children():
			var ph := float(r.get_meta("phase"))
			r.scale = Vector3(1.0 + sin(_t * 0.7 + ph) * 0.15, 1.0, 1.0 + sin(_t * 0.7 + ph) * 0.15)
	for i in _fish.size():
		var n := _fish[i] as Node3D
		if flood > 0.5:
			# Under the sea: they swim in slow loops round the reef, at all heights
			n.visible = true
			var r := 8.0 + i * 3.2
			var a := _t * (0.35 - i * 0.02) * (1.0 if i % 2 == 0 else -1.0) + i
			var h := 1.5 + fmod(i * 1.7, 9.0) + sin(_t * 0.5 + i) * 0.8
			n.position = Vector3(cos(a) * r, h, sin(a) * r)
			var ahead := a + (0.1 if i % 2 == 0 else -0.1)
			n.rotation.y = atan2(cos(ahead) * r - n.position.x, sin(ahead) * r - n.position.z)
			n.rotation.x = 0.0
			continue
		var cycle := fmod(_t * 0.5 + float(n.get_meta("phase")), 3.0)     # a leap, then a rest under the water
		n.visible = cycle < 1.0
		if cycle < 1.0:
			var from: Vector3 = n.get_meta("from")
			var to: Vector3 = n.get_meta("to")
			n.position = from.lerp(to, cycle) + Vector3(0, sin(cycle * PI) * 1.6, 0)
			n.rotation.y = atan2(to.x - from.x, to.z - from.z)
			n.rotation.x = -cos(cycle * PI) * 0.9


# Every frame -------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	_move_sea_life()
	if has_meta("preview"):
		if _otto_model:
			_wiggle(_otto_model, _t, 0.5)
		return
	for i in _glints.size():
		var g := _glints[i][0] as Node3D
		if g.visible:
			g.scale = Vector3.ONE * (0.7 + 0.5 * absf(sin(_t * 2.2)))
		var eyes := _glints[i][1] as Node3D
		eyes.scale.y = 0.1 if fmod(_t + i * 1.3, 3.2) < 0.15 else 1.0       # a blink
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		return
	_ride_step(player, delta)
	_process_pearls(player)
	_steps_step(player, delta)
	_boss_step(player, delta)
	_otto_step(player, delta)
	_move_reaches(delta)
	_lamps_step(player)


# Looks --------------------------------------------------------------------------------------------------------------
static func _ball(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


static func _mat(colour: Color, emit := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = Color(colour.r, colour.g, colour.b)
		m.emission_energy_multiplier = emit
	return m


static func bubble_mat(alpha := 0.35) -> StandardMaterial3D:
	# Soap-bubble glass: see-through, shiny, with a pale blue glow at the rim
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.95, 1.0, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.2
	m.rim_enabled = true
	m.rim = 0.8
	m.emission_enabled = true
	m.emission = Color(0.6, 0.9, 1.0)
	m.emission_energy_multiplier = 0.25
	return m


static func _put(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.scale = scale
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


const BUBBLE_MID := Vector3(0, 0.28, 0)   # the middle of his bubble, from his Body (bubble 1.1 up, body 0.82)
const ARM_ROOM := 1.04                     # how far an arm reaches from there (the bubble's 1.15 round)


static func otto_model() -> Node3D:
	# Otto: a round orange octopus with big kind eyes, a pair of pearl-diver's goggles pushed up on his head and eight
	# curly arms, sitting on a scallop-shell seat inside the bubble he blew for a chair. It floats just off the ground.
	# (My own design: there's no drawing of him yet.) He faces +z.
	var g := Node3D.new()
	var chair := Node3D.new()
	chair.name = "Chair"
	g.add_child(chair)
	var bubble := _put(chair, _ball(1.15, 20), bubble_mat(0.3), Vector3(0, 1.1, 0))     # (big enough for his head too)
	bubble.name = "Bubble"
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shell := _mat(Color(1.0, 0.9, 0.86), 0.0, 0.5)
	var seat := _put(chair, _ball(0.72, 14), shell, Vector3(0, 0.55, 0), Vector3(1.05, 0.4, 1.0))
	seat.name = "Seat"
	var back := _put(chair, _ball(0.7, 14), shell, Vector3(0, 0.95, -0.5), Vector3(1.0, 0.85, 0.16))
	back.name = "Seat Back"
	var ribs := _mat(Color(1.0, 0.72, 0.76), 0.0, 0.5)
	for k in 5:
		var a := lerpf(-0.8, 0.8, k / 4.0)
		_put(chair, _cyl(0.03, 0.04, 0.95, 5), ribs, Vector3(sin(a) * 0.45, 1.0, -0.6), Vector3.ONE, Vector3(0, 0, -a * 0.7))
	_put(chair, _ball(0.5, 12), _mat(Color(0.55, 0.8, 0.95), 0.0, 0.8), Vector3(0, 0.74, 0.02), Vector3(1.0, 0.22, 0.95)).name = "Cushion"
	var body := Node3D.new()
	body.name = "Body"
	body.position = Vector3(0, 0.82, 0.05)
	g.add_child(body)
	var skin := _mat(OTTO_ORANGE, 0.0, 0.55)
	var light := _mat(Color(1.0, 0.8, 0.62), 0.0, 0.55)
	_put(body, _ball(0.5, 18), skin, Vector3(0, 0.62, 0), Vector3(1.0, 1.18, 1.0)).name = "Head"
	_put(body, _ball(0.42, 14), skin, Vector3(0, 0.2, 0), Vector3(1.15, 0.6, 1.15)).name = "Skirt"
	for k in 6:
		var a := k * TAU / 6.0 + 0.4
		_put(body, _ball(0.09, 8), light, Vector3(cos(a) * 0.3, 1.02 + 0.07 * (k % 2), -0.12 + sin(a) * 0.26), Vector3(1, 0.5, 1))
	var white := _mat(Color(1, 1, 1), 0.0, 0.3)
	var dark := _mat(Color(0.12, 0.08, 0.12), 0.0, 0.3)
	for s in [-1.0, 1.0]:
		_put(body, _ball(0.17, 12), white, Vector3(s * 0.2, 0.62, 0.4), Vector3(1, 1.15, 0.8))
		_put(body, _ball(0.095, 10), dark, Vector3(s * 0.2, 0.6, 0.5))
		_put(body, _ball(0.035, 6), white, Vector3(s * 0.2 + 0.04, 0.65, 0.57))
		# A worried little brow
		var brow := _put(body, _ball(0.08, 6), _mat(Color(0.85, 0.4, 0.25), 0.0, 0.6), Vector3(s * 0.2, 0.86, 0.42), Vector3(1.6, 0.3, 0.6), Vector3(0, 0, s * 0.35))
		brow.name = "Brow%s" % ("L" if s < 0.0 else "R")
		_put(body, _ball(0.07, 8), _mat(Color(1.0, 0.45, 0.45), 0.0, 0.7), Vector3(s * 0.36, 0.42, 0.34), Vector3(1, 0.6, 0.5))
	_put(body, _ball(0.07, 8), dark, Vector3(0, 0.36, 0.47), Vector3(1.3, 0.45, 0.5)).name = "Mouth"
	# Goggles pushed up on his forehead
	var strap := _mat(Color(0.25, 0.3, 0.45), 0.0, 0.6)
	var lens := _mat(Color(0.6, 0.9, 1.0, 0.6), 0.3, 0.1)
	lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var band := TorusMesh.new()
	band.inner_radius = 0.44
	band.outer_radius = 0.5
	_put(body, band, strap, Vector3(0, 1.02, 0), Vector3(1, 1, 1), Vector3(0.22, 0, 0))
	for s in [-1.0, 1.0]:
		var rim := TorusMesh.new()
		rim.inner_radius = 0.09
		rim.outer_radius = 0.13
		_put(body, rim, _mat(Color(1.0, 0.82, 0.35), 0.2, 0.4), Vector3(s * 0.15, 1.1, 0.4), Vector3.ONE, Vector3(PI / 2.0 - 0.5, 0, 0))
		_put(body, _cyl(0.09, 0.09, 0.03, 10), lens, Vector3(s * 0.15, 1.1, 0.4), Vector3.ONE, Vector3(PI / 2.0 - 0.5, 0, 0))
	# Eight arms curling out over the seat
	var arms: Array = []
	for i in 8:
		var arm: Array = []
		for j in 7:
			var seg := _put(body, _ball(lerpf(0.13, 0.05, j / 6.0), 8), light if j == 6 else skin, Vector3.ZERO)
			arm.append(seg)
		arms.append(arm)
	g.set_meta("arms", arms)
	_wiggle(g, 0.0, 0.5)
	return g


static func _wiggle(model: Node3D, t: float, lively: float) -> void:
	# His arms curl and sway, more when he's on the move; his head bobs
	if model == null or not model.has_meta("arms"):
		return
	var arms: Array = model.get_meta("arms")
	for i in arms.size():
		var a := i * TAU / arms.size() + TAU / 16.0
		var dir := Vector3(sin(a), 0, cos(a))
		var arm: Array = arms[i]
		for j in arm.size():
			var out := 0.3 + j * 0.15
			var drop := 0.14 - j * j * 0.012 + sin(t * 2.2 + i * 0.9 + j * 0.7) * 0.022 * j * lively
			var curl := dir.cross(Vector3.UP) * sin(t * 1.6 + i * 1.7 + j * 0.5) * 0.02 * j * lively
			var at := dir * out + Vector3(0, drop, 0) + curl
			# Kept inside his bubble (Hayden, 14 Nov 2026: "Otto's arms clip out of the walls of his bubble"): an arm
			# that reaches the wall curls along the inside of it
			var room := ARM_ROOM - lerpf(0.13, 0.05, j / 6.0)
			var from_mid := at - BUBBLE_MID
			if from_mid.length() > room:
				at = BUBBLE_MID + from_mid.normalized() * room
			(arm[j] as Node3D).position = at
	var body := model.get_node_or_null("Body") as Node3D
	if body:
		body.position.y = 0.82 + sin(t * 2.0) * 0.03
	var chair := model.get_node_or_null("Chair") as Node3D
	if chair:
		chair.position.y = sin(t * 2.0) * 0.03


static func pearl_model() -> Node3D:
	# A Tide Pearl: a big glowing pearl sitting in an open scallop shell, with a soft light
	var g := Node3D.new()
	var shell := _mat(Color(0.75, 0.9, 1.0), 0.0, 0.5)
	_put(g, _ball(0.5, 12), shell, Vector3(0, 0.12, 0), Vector3(1.0, 0.3, 0.9))
	_put(g, _ball(0.5, 12), shell, Vector3(0, 0.5, -0.35), Vector3(1.0, 0.85, 0.14), Vector3(-0.3, 0, 0))
	_put(g, _ball(0.3, 16), _mat(PEARL, 1.2, 0.15), Vector3(0, 0.5, 0)).name = "Pearl"
	var light := OmniLight3D.new()
	light.light_color = PEARL
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position.y = 0.9
	g.add_child(light)
	return g


static func sleeping_gloop_model() -> Node3D:
	# A stand-in for the sleeping Riptide Gloop in the portal's preview: a big sea-blue blob with shut eyes
	var g := Node3D.new()
	var goo := _mat(Color(0.25, 0.65, 0.9), 0.2, 0.15)
	_put(g, _ball(2.4, 18), goo, Vector3(0, 1.7, 0), Vector3(1.15, 0.8, 1.1))
	var dark := _mat(Color(0.05, 0.1, 0.2), 0.0, 0.3)
	for s in [-1.0, 1.0]:
		_put(g, _ball(0.3, 8), dark, Vector3(s * 0.8, 2.3, 2.3), Vector3(1.2, 0.15, 0.4))
	return g

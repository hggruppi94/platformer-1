class_name BodyShape
extends SkeletonModifier3D

# Body shape for the character creator (scripts/hero.gd): a bigger or smaller head, and a wider or slimmer build,
# applied to the skeleton after the animation every frame (so running and skating keep the shape). Height is the
# whole model's scale instead (scripts/hero.gd).

@export var head := 1.0                # head size (1 = as drawn)
@export var build := 1.0               # how wide the body is (1 = as drawn)


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	# Wider or slimmer: the hips carry everything above them (spine, chest, arms, head) and the legs, so scaling them
	# widens the whole body. The head then undoes that width, so its own size is just "head".
	_scale(skel, "hips", Vector3(build, 1.0, build))
	_scale(skel, "head", Vector3(head / build, head, head / build))


func _scale(skel: Skeleton3D, bone_name: String, s: Vector3) -> void:
	var i := skel.find_bone(bone_name)
	if i < 0 or s.is_equal_approx(Vector3.ONE):
		return
	skel.set_bone_pose_scale(i, skel.get_bone_pose_scale(i) * s)

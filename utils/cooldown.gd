class_name Cooldown
extends Resource

var cooldown_until = 0.0
var duration = 0.0

func _init(cooldown_duration: float) -> void:
    duration = cooldown_duration

func fire() -> bool:
    var allowed = can_fire()
    if allowed:
        cooldown_until = Time.get_ticks_msec() + duration
    return allowed

func can_fire() -> bool:
    return Time.get_ticks_msec() >= cooldown_until
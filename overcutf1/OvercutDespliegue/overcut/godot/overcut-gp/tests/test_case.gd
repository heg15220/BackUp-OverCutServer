class_name TestCase
extends RefCounted
## Base for headless tests. Assertions record failures instead of aborting,
## so one bad assertion still lets the rest of the test report.

var failures: Array[String] = []
## Set by the runner so tests that need the scene tree can await frames.
var tree: SceneTree


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		_fail("expected true" if msg.is_empty() else msg)


func assert_eq(a: Variant, b: Variant, msg := "") -> void:
	if a != b:
		_fail("%s != %s %s" % [str(a), str(b), msg])


func assert_near(a: float, b: float, tol: float, msg := "") -> void:
	if not (absf(a - b) <= tol):
		_fail("%f not within %f of %f %s" % [a, tol, b, msg])


func assert_between(v: float, lo: float, hi: float, msg := "") -> void:
	if not (v >= lo and v <= hi):
		_fail("%f not in [%f, %f] %s" % [v, lo, hi, msg])


func _fail(text: String) -> void:
	failures.append(text)

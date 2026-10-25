extends SceneTree
## Headless test runner.
## godot --headless --path <project> --script res://tests/run_tests.gd [-- --filter=<substring>]
## Discovers res://tests/**/test_*.gd (except tests/bench), runs every test_* method,
## awaiting the ones that are coroutines, and exits 1 if anything failed.
## Any engine or script error logged while a test runs (a runtime error aborts the
## method silently) fails that test; a script that cannot load fails its file.

var _passed := 0
var _failed := 0
var _log := ErrorLog.new()


## Collects every error the engine logs, so a crashed test cannot pass.
class ErrorLog extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		errors.append("%s (%s:%d %s)" % [rationale if not rationale.is_empty() else code, file.get_file(), line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func count() -> int:
		_mutex.lock()
		var n := errors.size()
		_mutex.unlock()
		return n


func _initialize() -> void:
	OS.add_logger(_log)
	_run.call_deferred()


func _run() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var files: Array[String] = []
	_collect("res://tests", files)
	files.sort()
	for path in files:
		var errors_before := _log.count()
		var script: Script = load(path)
		if script == null or not script.can_instantiate() or _log.count() > errors_before:
			print("FAIL %s — could not load: %s" % [path, "; ".join(_log.errors.slice(errors_before))])
			_failed += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			var id := "%s::%s" % [path.get_file(), name]
			if not filter.is_empty() and not id.contains(filter):
				continue
			var instance: TestCase = script.new()
			instance.tree = self
			var before := _log.count()
			await instance.call(name)
			if _log.count() > before:
				instance.failures.append("engine/script error: " + "; ".join(_log.errors.slice(before)))
			if instance.failures.is_empty():
				_passed += 1
				print("PASS %s" % id)
			else:
				_failed += 1
				print("FAIL %s — %s" % [id, "; ".join(instance.failures)])
	print("%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if dir_path == "res://tests" and sub == "bench":
			continue
		_collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd":
			out.append(dir_path.path_join(file))

extends SceneTree
var Store = load("res://scripts/save_store.gd")
var failures: Array[String] = []
var checks := 0
const ROOT := "user://qa_saves/"
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func store(file: String):
	var s = Store.new()
	s.path = ROOT + file
	return s
func raw(file: String, contents: String) -> void:
	var f = FileAccess.open(ROOT + file, FileAccess.WRITE)
	f.store_string(contents)
	f.close()
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var s = store("missing-%d.cfg" % Time.get_ticks_usec())
	s.load_data()
	check(s.best == 0 and s.muted == false, "missing save uses safe defaults")
	s = store("valid.cfg")
	s.best = 120
	s.muted = true
	check(s.save_data() == OK, "save write succeeds")
	var fresh = store("valid.cfg")
	fresh.load_data()
	check(fresh.best == 120 and fresh.muted, "best and audio preference persist")
	check(not fresh.record_score(20) and fresh.best == 120, "lower score cannot overwrite best")
	check(not fresh.record_score(120) and fresh.best == 120, "equal score preserves best")
	check(fresh.record_score(150) and fresh.best == 150, "new best updates memory")
	var reread = store("valid.cfg")
	reread.load_data()
	check(reread.best == 150 and reread.muted, "new best persists across new object")
	raw("negative.cfg", "[player]\nbest=-120\n[audio]\nmuted=false\n")
	s = store("negative.cfg")
	s.load_data()
	check(s.best == 0 and not s.muted, "negative best clamps to zero")
	raw("huge.cfg", "[player]\nbest=2000000000\n")
	s = store("huge.cfg")
	s.load_data()
	check(s.best >= 0 and s.best <= 1000000, "huge best is bounded")
	raw("wrongtype.cfg", '[player]\nbest="oops"\n[audio]\nmuted="no"\n')
	s = store("wrongtype.cfg")
	s.load_data()
	check(s.best == 0 and not s.muted, "invalid value types retain defaults")
	raw("corrupt.cfg", "This is not a config file [unterminated section")
	s = store("corrupt.cfg")
	s.load_data()
	check(s.best == 0 and not s.muted, "corrupt save does not break startup")
	s = store("nonexistent-parent/save.cfg")
	s.best = 15
	check(s.save_data() != OK, "unwritable destination returns an error")
	check(s.record_score(20) and s.best == 20, "write failure still retains session best without crashing")
	print("INDEPENDENT_SAVE_QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

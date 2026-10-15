extends SceneTree
var Model = load("res://scripts/snake_model.gd")
func _initialize() -> void:
	var m = Model.new()
	m.reset(20261015)
	m.start()
	var cycle: Array[Vector2i] = []
	for x in range(m.size.x): cycle.append(Vector2i(x,0))
	for y in range(1,m.size.y):
		if y % 2 == 1:
			for x in range(m.size.x-1,0,-1): cycle.append(Vector2i(x,y))
		else:
			for x in range(1,m.size.x): cycle.append(Vector2i(x,y))
	for y in range(m.size.y-1,0,-1): cycle.append(Vector2i(0,y))
	m.body.clear()
	for i in range(3,-1,-1): m.body.append(cycle[i])
	m.food = Vector2i(4,0)
	var pos := 3
	var steps := 0
	while m.state == Model.State.RUNNING and steps < cycle.size()*cycle.size():
		var next: int = (pos+1) % cycle.size()
		var requested: Vector2i = cycle[next] - cycle[pos]
		if requested != m.direction:
			if not m.queue_direction(requested):
				push_error("Hamiltonian legal turn rejected")
				quit(1)
				return
		var result: String = m.tick()
		if result == "wall" or result == "self" or result == "idle":
			push_error("Safe cycle failed: " + result)
			quit(1)
			return
		if m.body[0] != cycle[next] or m.score != m.eaten*10 or m.body.size() != 4+m.eaten:
			push_error("Full-game invariant failed")
			quit(1)
			return
		pos = next
		steps += 1
	var ok: bool = m.state == Model.State.WON and m.body.size() == 448 and m.score == 4440 and m.food == Vector2i(-1,-1)
	print("INDEPENDENT_FULL_GAME_QA: steps=", steps, " food=", m.eaten, " final_length=", m.body.size(), " score=",m.score, " won=",ok)
	quit(0 if ok else 1)

extends RefCounted
## Deterministic prototype stone surfaces. Coordinates come from the terrace, never pixels.
static func face(parent: Node2D, points: Array, color: Color) -> void:
	var node := Polygon2D.new()
	node.polygon = PackedVector2Array(points)
	node.color = color
	parent.add_child(node)

static func edge(parent: Node2D, points: Array, color: Color, width: float = 1.0) -> void:
	var node := Line2D.new()
	node.points = PackedVector2Array(points)
	node.default_color = color
	node.width = width
	parent.add_child(node)

static func wall(parent: Node2D, a: Vector2, b: Vector2, height: float, seed_value: int, shade: float = 1.0) -> void:
	var axis := (b-a)/absf(b.x-a.x)
	var length := absf(b.x-a.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	face(parent,[a,b,b+Vector2(0,height),a+Vector2(0,height)],Color("34352e")*Color(shade,shade,shade))
	var row := 0
	var y := 0.0
	while y < height:
		var row_height := minf(rng.randf_range(11,17),height-y)
		var x := -rng.randf_range(0,23)
		while x < length:
			var block_width := rng.randf_range(19,39)
			var left := maxf(0,x)
			var right := minf(length,x+block_width)
			if right-left > 3:
				var origin := a+axis*left+Vector2(0,y)
				var span := axis*(right-left)
				var cut := minf(3,(right-left)*0.2)
				var points := [origin+axis*cut+Vector2(0,1),origin+span-axis*2+Vector2(0,1),origin+span+Vector2(0,3),origin+span-axis*cut+Vector2(0,row_height-1),origin+axis+Vector2(0,row_height-1),origin+Vector2(0,3)]
				var tint := rng.randf_range(0.87,1.13)*shade
				var color := Color("706d5c")*Color(tint,tint,tint)
				face(parent,points,color)
				edge(parent,[points[0],points[1]],color.lightened(0.16),1)
				edge(parent,[points[3],points[4]],color.darkened(0.23),1)
				if rng.randf() < 0.46 and right-left > 12:
					var middle := origin+span*rng.randf_range(0.3,0.7)
					edge(parent,[middle+Vector2(0,2),middle+axis*3+Vector2(0,5),middle+axis+Vector2(0,row_height-2)],color.darkened(0.3))
				if row > 0 and rng.randf() < 0.22:
					var moss := origin+axis*3+Vector2(0,row_height-3)
					edge(parent,[moss,moss+axis*minf(8,right-left-4)],Color("505743")*Color(shade,shade,shade),2)
			x += block_width
		y += row_height
		row += 1
	edge(parent,[a,b],Color("9b9176")*Color(shade,shade,shade),1)

static func stairs(parent: Node2D, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	# Eight real treads and six-pixel risers, contained in the existing stair envelope.
	face(parent,[b,c,c+Vector2(0,8),b+Vector2(0,48)],Color("555346"))
	for band in range(3):
		var upper_fraction := band/3.0
		var lower_fraction := (band+1)/3.0
		var left_top := b.lerp(b+Vector2(0,48),upper_fraction)
		var right_top := c.lerp(c+Vector2(0,8),upper_fraction)
		var left_bottom := b.lerp(b+Vector2(0,48),lower_fraction)
		var right_bottom := c.lerp(c+Vector2(0,8),lower_fraction)
		for block in range(4):
			var u := block/4.0
			var v := (block+1)/4.0
			var p := left_top.lerp(right_top,u)
			var q := left_top.lerp(right_top,v)
			var r := left_bottom.lerp(right_bottom,v)
			var s := left_bottom.lerp(right_bottom,u)
			var color := Color("666350").lightened(float((block+band)%3)*0.035)
			face(parent,[p,q,r,s],color)
			edge(parent,[s,p,q],color.darkened(0.25))
	for i in range(8):
		var t0 := i/8.0
		var t1 := (i+1)/8.0
		var back_left := a.lerp(d,t0)
		var back_right := b.lerp(c,t0)
		var front_left := a.lerp(d,t1)-Vector2(0,6)
		var front_right := b.lerp(c,t1)-Vector2(0,6)
		for j in range(3):
			var u0 := j/3.0
			var u1 := (j+1)/3.0
			var shade := 0.97+float((i*7+j*3)%5)*0.025
			var color := Color("a39a80")*Color(shade,shade,shade)
			var p := back_left.lerp(back_right,u0)
			var q := back_left.lerp(back_right,u1)
			var r := front_left.lerp(front_right,u1)
			var s := front_left.lerp(front_right,u0)
			face(parent,[p,q,r,s],color)
			edge(parent,[p,s],Color("676450"))
			face(parent,[s,r,r+Vector2(0,6),s+Vector2(0,6)],color.darkened(0.3))
			edge(parent,[s,r],color.lightened(0.17))
			if (i+j)%3 == 0:
				var chip := s.lerp(r,0.55)
				edge(parent,[chip,chip+Vector2(2,2),chip+Vector2(5,2)],color.darkened(0.22))

static func rock_wall(parent: Node2D, a: Vector2, b: Vector2, height: float, seed_value: int, shade: float = 1.0) -> void:
	# Shared irregular vertices leave no holes between rock facets; the terrain lip stays exact.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var length := absf(b.x-a.x)
	var axis := (b-a)/length
	var columns := maxi(3,roundi(length/37.0))
	var rows := maxi(2,roundi(height/20.0))
	var vertices: Array[Vector2] = []
	for row in range(rows+1):
		for col in range(columns+1):
			var x := length*col/columns
			var y := height*row/rows
			if col > 0 and col < columns: x += rng.randf_range(-8,8)
			if row > 0 and row < rows: y += rng.randf_range(-5,5)
			if row == rows and col > 0 and col < columns: y += rng.randf_range(0,5)
			vertices.append(a+axis*x+Vector2(0,y))
	for row in range(rows):
		for col in range(columns):
			var p := vertices[row*(columns+1)+col]
			var q := vertices[row*(columns+1)+col+1]
			var r := vertices[(row+1)*(columns+1)+col+1]
			var s := vertices[(row+1)*(columns+1)+col]
			var center := p.lerp(r,rng.randf_range(0.35,0.65))
			var tint := rng.randf_range(0.86,1.1)*shade
			var color := Color("76715e")*Color(tint,tint,tint)
			face(parent,[p,q,r,s],color)
			face(parent,[p,q,q.lerp(r,0.17),center.lerp(p.lerp(q,0.5),0.7),p.lerp(s,0.22)],color.lightened(0.09))
			face(parent,[s,r,r.lerp(q,0.16),s.lerp(p,0.23)],color.darkened(0.19))
			edge(parent,[s,r],color.darkened(0.32),1)
			if rng.randf() < 0.6:
				edge(parent,[s.lerp(p,0.4),center.lerp(p.lerp(q,0.5),0.25),q.lerp(r,0.5)],color.lightened(0.08),1)
			if rng.randf() < 0.4:
				edge(parent,[q,q.lerp(center,0.6),center.lerp(s,0.4)],color.darkened(0.4),1)
			if row == 0 and rng.randf() < 0.45:
				face(parent,[p,p.lerp(q,0.4),p.lerp(center,0.65)],Color("555b3d")*Color(shade,shade,shade))
	# A thin broken soil cap joins the existing dirt top without changing its contour.
	for col in range(columns):
		var p := vertices[col]
		var q := vertices[col+1]
		face(parent,[p,q,q+Vector2(0,2),p.lerp(q,0.5)+Vector2(0,rng.randf_range(3,6)),p+Vector2(0,2)],Color("554331")*Color(shade,shade,shade))

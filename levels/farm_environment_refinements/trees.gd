extends RefCounted
## 調整四株成齡防風木的木段、承托、站立及倒伏資料。採收果樹保留工作高度。
const TARGETS := {Vector2(-42,-66):1.26,Vector2(-43.5,-72):1.15,Vector2(-67,77):1.22,Vector2(55,-53):1.14}
static func install(farm:Node3D) -> Array:
	var out:=[]
	var style:=farm.get_node(^"FarmStyleEnvironment")
	for t:ToyBuild in farm.get_tree().get_nodes_in_group(&"tree"):
		var key:=Vector2(t.position.x,t.position.z)
		if not farm.is_ancestor_of(t) or not TARGETS.has(key) or not t.has_meta(&"farm_style_tree") or t.has_damage(): continue
		var ratio:float=TARGETS[key]
		var base_y:=t._all.position.y
		for i in t.brick_count():
			var xf:=t._xf[i]
			xf.origin.y=base_y+(xf.origin.y-base_y)*ratio
			t._xf[i]=xf
			var size:=t._size[i]
			size.y*=ratio
			t._size[i]=size
			t._bb[i]=xf*AABB(-size*.5,size)
			t._all=t._bb[i] if i==0 else t._all.merge(t._bb[i])
			if t._sidx[i]>=0:
				var sh:=t._shape[t._sidx[i]]
				sh.position=xf.origin
				sh.shape.size=size
		t._grid.clear()
		t._base.clear()
		t._adj.clear()
		t._ensure_adj()
		t._mm=style.tree_mesh(t,PackedInt32Array(range(t.brick_count())),t._xf,true)
		(t.get_child(0) as MultiMeshInstance3D).multimesh=t._mm
		out.append([key.x,key.y,ratio,t._all.end.y])
	return out

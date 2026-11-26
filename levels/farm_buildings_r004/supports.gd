extends RefCounted
## 每個座位至少要有一條著地支承；梁兩端分成兩席。從地面向上求可達，懸空的循環不能自我承托。
var seats := {}
var uses := {}
var anchors := {}
var errors:Array[String]=[]

func index(registry:Node) -> void:
	for key:String in registry.entries:
		var n:Node=registry.entries[key].native
		if not is_instance_valid(n) or not n.has_meta("support_seats"):continue
		var listed:Array=n.get_meta("support_seats")
		if listed.is_empty():
			if n.get_meta("ground_anchor",false):anchors[key]=true
			continue
		seats[key]=[]
		for group:Array in listed:
			var found:Array[String]=[]
			for path:String in group:
				var node:=n.get_parent().get_node_or_null(NodePath(path))
				var parent_key:=str(registry.arena.get_path_to(node)) if node else ""
				if not registry.entries.has(parent_key):
					errors.append(key+" → "+path);continue
				found.append(parent_key)
				if not uses.has(parent_key):uses[parent_key]=[]
				uses[parent_key].append(key)
			seats[key].append(found)

func cascades(registry:Node, patch:Dictionary) -> Dictionary:
	var affected:Dictionary={}
	var queue:Array=[]
	for k:String in patch:
		if patch[k]==0: queue.append(k);affected[k]=true
	while not queue.is_empty():
		var p:String=queue.pop_back()
		for child:String in uses.get(p,[]):
			if not affected.has(child):affected[child]=true;queue.append(child)
	if affected.is_empty():return patch
	# 包含上游備援，判斷最後承座是否仍可追到地面。
	queue=affected.keys()
	var closure:=affected.duplicate()
	while not queue.is_empty():
		var k:String=queue.pop_back()
		for group:Array in seats.get(k,[]):
			for p:String in group:
				if not closure.has(p):closure[p]=true;queue.append(p)
	var live:Dictionary={}
	for k:String in closure:
		if not seats.has(k) and patch.get(k,registry.health.get(k,1))>0:live[k]=true
	var changed:=true
	while changed:
		changed=false
		for k:String in closure:
			if live.has(k) or not seats.has(k) or patch.get(k,registry.health.get(k,1))<=0:continue
			var supported:=true
			for group:Array in seats[k]:
				var ok:=false
				for p:String in group:
					if live.has(p): ok=true;break
				if not ok:supported=false;break
			if supported:live[k]=true;changed=true
	for k:String in affected:
		if seats.has(k) and not live.has(k):patch[k]=0
	return patch

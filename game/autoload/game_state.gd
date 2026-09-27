## Estado do personagem offline: progresso, inventário, equipamento e save.
## Toda regra passa pelo núcleo (core/); aqui só se orquestra e persiste.
extends Node

signal changed
signal leveled(level: int)
signal toast(text: String, color: Color)

const Config = preload("res://core/config.gd")
const Rng = preload("res://core/rng.gd")
const Character = preload("res://core/character_state.gd")
const Stats = preload("res://core/stats.gd")
const Progression = preload("res://core/progression.gd")
const Loot = preload("res://core/loot.gd")
const Salvage = preload("res://core/salvage.gd")
const SaveFile = preload("res://core/save_file.gd")
const Quests = preload("res://core/quests.gd")
const Talents = preload("res://core/talents.gd")

const SAVE_PATH := "user://save_offline.json"
const INVENTORY_SIZE := 40
const SAVE_VERSION := 1

var economy := Config.economy()
var affixes := Config.affixes()
var sets_db := Config.sets()
var items_db := Config.data("items")
var maps_db := Config.data("maps")
var mobs_db := Config.data("mobs")
var skills_db := Config.data("skills")
var visuals := Config.data("visuals")
var themes_db := Config.data("themes")
var quests_db := Config.data("quests")
var quests: Dictionary = Quests.new_state()
var dialogues_db := Config.data("dialogues")
var talents_db := Config.data("talents")
var talents: Dictionary = Talents.new_state()
var talent_bonus: Dictionary = {"stats": {}, "skills": {}}
var tracked_quest := ""
var flags: Dictionary = {}
var discovered: Dictionary = {}   # map_id -> PackedByteArray (1 = célula vista)

var rng = Rng.new()
var character = Character.new()
var xp := 0
var inventory: Array = []
var equipped: Dictionary = {}
var current_map := "bastiao"
var difficulty := "normal"
var stats: Dictionary = {}


func _ready() -> void:
	load_game()
	recompute()


func loot_ctx() -> Dictionary:
	return {"economy": economy, "affixes": affixes, "items": items_db, "sets": sets_db, "character": character, "rng": rng}


func recompute() -> void:
	talent_bonus = Talents.bonuses(talents_db, talents)
	stats = Stats.compute(character.level, equipped.values(), items_db, sets_db, [talent_bonus["stats"]])
	changed.emit()


func equipped_list() -> Array:
	return equipped.values()


func power() -> int:
	return Stats.power(stats)


# --- progresso ---

func add_xp(amount: int) -> void:
	var st := {"level": character.level, "xp": xp}
	var gained := Progression.add_xp(st, amount, economy)
	character.level = st["level"]
	xp = st["xp"]
	if gained > 0:
		recompute()
		leveled.emit(character.level)
		toast.emit("Nível %d! +%d ponto(s) de espírito" % [character.level, gained], Color("#ffd166"))
		for s in skills_db["sentinela"]["skills"]:
			if int(s.get("unlock_level", 1)) > character.level - gained and int(s.get("unlock_level", 1)) <= character.level:
				toast.emit("Nova skill: %s" % s["name"], Color("#7fd1ff"))
	changed.emit()


func xp_needed() -> int:
	return Progression.xp_to_next(character.level, economy)


func complete_challenge(id: String) -> void:
	if character.has_challenge(id):
		return
	character.complete_challenge(id)
	var info: Dictionary = economy["challenges"].get(id, {})
	toast.emit("Desafio concluído: %s" % info.get("name", id), Color("#ff9f1c"))
	save_game()


# --- inventário ---

func add_currency(key: String, amount: int) -> void:
	character.wallet.add(key, amount)
	changed.emit()


func add_item(item: Dictionary) -> bool:
	if inventory.size() >= INVENTORY_SIZE:
		toast.emit("Inventário cheio", Color("#ff6b6b"))
		return false
	inventory.append(item)
	changed.emit()
	return true


func equip(item: Dictionary) -> void:
	var slot: String = item["slot"]
	inventory.erase(item)
	if equipped.has(slot):
		inventory.append(equipped[slot])
	equipped[slot] = item
	recompute()
	save_game()


func unequip(slot: String) -> void:
	if not equipped.has(slot) or inventory.size() >= INVENTORY_SIZE:
		return
	inventory.append(equipped[slot])
	equipped.erase(slot)
	recompute()
	save_game()


func salvage(item: Dictionary) -> Dictionary:
	inventory.erase(item)
	var v := Salvage.salvage(item, character, economy)
	changed.emit()
	save_game()
	return v


func salvage_all_common() -> int:
	var n := 0
	for it in inventory.duplicate():
		if it["rarity"] == "common":
			Salvage.salvage(it, character, economy)
			inventory.erase(it)
			n += 1
	changed.emit()
	save_game()
	return n


## Chamado depois de qualquer ação da Forja sobre um item (refino, giro, Sigilo).
func item_changed(item: Dictionary) -> void:
	if item.get("set_id", "") != "" and int(item["refine"]) > 0 and character.level >= 15:
		complete_challenge("first_ember")
	recompute()
	save_game()


# --- save ---

func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "content_version": economy["content_version"], "character": character.to_dict(),
		"xp": xp, "inventory": inventory, "equipped": equipped, "quests": quests,
		"tracked": tracked_quest, "talents": talents, "flags": flags, "discovered": _pack_discovered()}


func save_game() -> void:
	SaveFile.write(SAVE_PATH, to_dict())


func load_game() -> void:
	var d := SaveFile.read(SAVE_PATH)
	if d.is_empty():
		new_game()
		return
	character = Character.from_dict(d["character"])
	xp = int(d.get("xp", 0))
	inventory = _ints(d.get("inventory", []))
	quests = d.get("quests", Quests.new_state())
	tracked_quest = d.get("tracked", "")
	talents = d.get("talents", Talents.new_state())
	for k in talents["points"]:
		talents["points"][k] = int(talents["points"][k])
	flags = d.get("flags", {})
	discovered = {}
	var disc: Dictionary = d.get("discovered", {})
	for k in disc:
		discovered[k] = Marshalls.base64_to_raw(disc[k])
	equipped = {}
	var eq: Dictionary = d.get("equipped", {})
	for k in eq:
		equipped[k] = _ints([eq[k]])[0]


func new_game() -> void:
	character = Character.new()
	xp = 0
	inventory = []
	equipped = {}
	quests = Quests.new_state()
	tracked_quest = ""
	talents = Talents.new_state()
	flags = {}
	discovered = {}
	character.wallet.add("zen", 5000)
	character.wallet.add("lume", 6)
	character.wallet.add("prisma", 3)
	character.wallet.add("sigilo", 1)
	var ctx := loot_ctx()
	for pair in [["weapon", "common"], ["armor", "common"]]:
		var it := Loot.make_item(ctx, pair[0], 1, pair[1], "")
		equipped[it["slot"]] = it
	save_game()


func reset_save() -> void:
	new_game()
	recompute()


## JSON devolve números como float; o núcleo espera int nesses campos.
func _ints(list: Array) -> Array:
	for it in list:
		for k in ["item_level", "refine"]:
			it[k] = int(it[k])
		for line in it["affixes"]:
			line["tier"] = int(line["tier"])
	return list


# --- missões ---

func quest_status(id: String) -> String:
	return Quests.status(quests_db, quests, id, character.level)


func accept_quest(id: String) -> bool:
	var ok := Quests.accept(quests_db, quests, id, character.level)
	if ok:
		toast.emit("Missão aceita: %s" % Quests.find(quests_db, id)["name"], Color("#ffd166"))
		tracked_quest = id
		save_game()
		changed.emit()
	return ok


func quest_event(ev: Dictionary) -> void:
	for id in Quests.on_event(quests_db, quests, ev):
		var q := Quests.find(quests_db, id)
		var p := Quests.progress(quests_db, quests, id)
		if quests["done"].has(id):
			toast.emit("%s concluída! Volte à Ilse." % q["name"], Color("#3fd67a"))
			save_game()
		elif q["goal"]["type"] != "kill" or p[0] % 5 == 0:
			toast.emit("%s: %d/%d" % [q["name"], p[0], p[1]], Color("#ffe3a0"))
	changed.emit()


func quest_drops(mob_id: String) -> Array:
	return Quests.drops_for_kill(quests_db, quests, mob_id, rng)


## Entrega e aplica a recompensa (XP, moedas, joias e item).
func turn_in_quest(id: String) -> Dictionary:
	var r := Quests.turn_in(quests_db, quests, id)
	if r.is_empty():
		return r
	for k in r:
		if k == "xp":
			continue
		if k == "item":
			var spec: Dictionary = r["item"]
			var it := Loot.make_item(loot_ctx(), spec["slot"], maxi(1, character.level), spec["rarity"], spec.get("set", ""))
			inventory.append(it)
			toast.emit("Recompensa: %s" % it["name"], Color(items_db["rarity_colors"][it["rarity"]]))
		else:
			character.wallet.add(k, int(r[k]))
	add_xp(int(r.get("xp", 0)))
	toast.emit("Missão entregue: %s" % Quests.find(quests_db, id)["name"], Color("#3fd67a"))
	save_game()
	changed.emit()
	return r


## Missões que a HUD acompanha: ativas e prontas.
func tracked_quests() -> Array:
	return quests["active"].keys() + quests["done"]


# --- comparação ---

func compare(item: Dictionary) -> Dictionary:
	return Stats.compare(character.level, equipped, item, items_db, sets_db, [talent_bonus["stats"]])


func is_upgrade(item: Dictionary) -> bool:
	return equipped.get(item["slot"]) != item and compare(item)["power"] > 0


func equip_best() -> int:
	var best := Stats.best_loadout(character.level, equipped, inventory, items_db, sets_db)
	var n := 0
	for slot in best:
		if equipped.get(slot) != best[slot]:
			inventory.erase(best[slot])
			if equipped.has(slot):
				inventory.append(equipped[slot])
			equipped[slot] = best[slot]
			n += 1
	recompute()
	save_game()
	return n



# --- descoberta do mapa (névoa) ---

func _pack_discovered() -> Dictionary:
	var out := {}
	for k in discovered:
		out[k] = Marshalls.raw_to_base64(discovered[k])
	return out


func discovery(map_id: String, size: int) -> PackedByteArray:
	if not discovered.has(map_id) or discovered[map_id].size() != size:
		var b := PackedByteArray()
		b.resize(size)
		discovered[map_id] = b
	return discovered[map_id]


## Revela células num raio em volta; retorna true se algo novo apareceu.
func reveal(map_id: String, w: int, h: int, cell: Vector2i, radius: int) -> bool:
	var b := discovery(map_id, w * h)
	var changed_any := false
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c := cell + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or dx * dx + dy * dy > radius * radius + 1:
				continue
			var i := c.y * w + c.x
			if b[i] == 0:
				b[i] = 1
				changed_any = true
	return changed_any


func npc_quests(npc: String) -> Array:
	var out := []
	for q in quests_db["quests"]:
		if q.get("giver", "mentor") == npc and quest_status(q["id"]) != "locked" and quest_status(q["id"]) != "completed":
			out.append(q)
	return out



# --- espíritos (talentos) ---

func talent_points() -> int:
	return Talents.available(character.level, talents)


func add_talent(id: String) -> String:
	var err := Talents.can_add(talents_db, talents, id, character.level)
	if err == "":
		Talents.add(talents_db, talents, id, character.level)
		recompute()
		save_game()
	return err


func reset_talent_tree(tree_id: String) -> void:
	Talents.reset_tree(talents_db, talents, tree_id)
	recompute()
	save_game()


func spirit() -> Dictionary:
	return Talents.spirit(talents_db, talents)


## Skill com os modificadores dos talentos aplicados (dano, raio, distância, recarga...).
func skill_with_mods(i: int) -> Dictionary:
	var s: Dictionary = skills_db["sentinela"]["skills"][i].duplicate()
	var m: Dictionary = talent_bonus["skills"].get(s["id"], {})
	if s.has("mult"):
		s["mult"] = float(s["mult"]) * (1.0 + m.get("mult_pct", 0.0) / 100.0)
	if s.has("radius"):
		s["radius"] = float(s["radius"]) * (1.0 + m.get("radius_pct", 0.0) / 100.0)
	if s.has("distance"):
		s["distance"] = float(s["distance"]) * (1.0 + m.get("distance_pct", 0.0) / 100.0)
	s["cooldown"] = float(s["cooldown"]) * (1.0 + m.get("cooldown_pct", 0.0) / 100.0)
	for k in ["stun", "heal_pct", "def_bonus_pct", "duration"]:
		if s.has(k):
			s[k] = float(s[k]) + m.get(k, 0.0)
	return s


func skill_unlocked(i: int) -> bool:
	return character.level >= int(skills_db["sentinela"]["skills"][i].get("unlock_level", 1))

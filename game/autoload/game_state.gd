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
	stats = Stats.compute(character.level, equipped.values(), items_db, sets_db)
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
		toast.emit("Nível %d!" % character.level, Color("#ffd166"))
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
		"xp": xp, "inventory": inventory, "equipped": equipped}


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
	equipped = {}
	var eq: Dictionary = d.get("equipped", {})
	for k in eq:
		equipped[k] = _ints([eq[k]])[0]


func new_game() -> void:
	character = Character.new()
	xp = 0
	inventory = []
	equipped = {}
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

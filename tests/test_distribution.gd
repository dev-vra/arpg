## Distribuição de tiers: 100 mil sorteios com semente fixa, dentro de 1 ponto
## percentual da tabela esperada, para cada combinação de tiers liberados,
## com e sem Fortuna. Nunca há resultado fora de T1..T5.
extends "res://tests/test_case.gd"

const Config = preload("res://core/config.gd")
const Rng = preload("res://core/rng.gd")
const TierTable = preload("res://core/tier_table.gd")

const N := 100000
const TOL := 1.0

var eco := Config.economy()

# Os tiers liberam de baixo para cima: T5; T5-T4; ...; todos.
const UNLOCK_SETS := [[5], [4, 5], [3, 4, 5], [2, 3, 4, 5], [1, 2, 3, 4, 5]]


func _run(unlocked: Array, fortune: bool, seed_value: int) -> void:
	var expected := TierTable.chances(eco, unlocked, fortune, 0)
	var rng = Rng.new(seed_value)
	var counts := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	for i in N:
		var t := TierTable.roll_tier(expected, rng)
		check(counts.has(t), "resultado fora de T1..T5: %s" % str(t))
		counts[t] += 1
	for t in counts:
		var pct: float = counts[t] * 100.0 / N
		near(pct, expected[t], TOL, "T%d liberados=%s fortuna=%s" % [t, str(unlocked), str(fortune)])
		if not unlocked.has(t):
			eq(counts[t], 0, "T%d bloqueado saiu" % t)


func test_distribution_all_unlock_sets_no_fortune() -> void:
	for i in UNLOCK_SETS.size():
		_run(UNLOCK_SETS[i], false, 1000 + i)


func test_distribution_all_unlock_sets_with_fortune() -> void:
	for i in UNLOCK_SETS.size():
		_run(UNLOCK_SETS[i], true, 2000 + i)


## Com Piedade a tabela muda a cada giro; o critério é: ela só melhora T1+T2
## em relação à base e nunca produz falha.
func test_distribution_with_pity() -> void:
	var all := [1, 2, 3, 4, 5]
	var rng = Rng.new(3000)
	var stacks := 0
	var top := 0
	for i in N:
		var table := TierTable.chances(eco, all, false, stacks)
		var t := TierTable.roll_tier(table, rng)
		check(t >= 1 and t <= 5, "resultado válido")
		if t <= 2:
			top += 1
		stacks = 0 if t <= 3 else mini(stacks + 1, 20)
	var pct := top * 100.0 / N
	check(pct >= 12.0 - TOL, "Piedade não piora T1+T2 (veio %.2f%%)" % pct)

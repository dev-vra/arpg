## Tabela de tiers: calcula as chances (com desbloqueio, Fortuna e Piedade)
## e sorteia tier e valor. T1 é o melhor e o mais raro; nunca há falha.
extends RefCounted

const TIERS := [1, 2, 3, 4, 5]


## Chances em pontos percentuais (somam 100) só entre os tiers liberados.
## Fortuna e Piedade movem pontos dos doadores (T5, T4) para T1 e T2,
## e só atuam entre os tiers liberados.
static func chances(economy: Dictionary, unlocked: Array, fortune: bool, pity_stacks: int) -> Dictionary:
	var tiers_cfg: Dictionary = economy["tiers"]
	var w := {}
	for t in TIERS:
		w[t] = float(tiers_cfg["chances"][str(t)])

	if fortune:
		var f: Dictionary = economy["fortune"]
		_shift(w, _int_keys(f["gains"], 1.0), f["donors"], unlocked)

	var stacks := mini(pity_stacks, int(economy["pity"]["max_stacks"]))
	if stacks > 0:
		var p: Dictionary = economy["pity"]
		_shift(w, _int_keys(p["gains_per_stack"], float(stacks)), p["donors"], unlocked)

	var total := 0.0
	for t in TIERS:
		if not unlocked.has(t):
			w[t] = 0.0
		total += w[t]
	# O menor tier liberado sempre existe (T5 no nível 1); se a tabela vier vazia, cai nele.
	if total <= 0.0:
		var fallback: int = unlocked.max() if not unlocked.is_empty() else 5
		w[fallback] = 100.0
		total = 100.0
	for t in TIERS:
		w[t] = w[t] * 100.0 / total
	return w


static func _int_keys(d: Dictionary, mult: float) -> Dictionary:
	var out := {}
	for k in d:
		out[int(k)] = float(d[k]) * mult
	return out


static func _shift(w: Dictionary, gains: Dictionary, donors: Array, unlocked: Array) -> void:
	var total_gain := 0.0
	for t in gains:
		if unlocked.has(t):
			total_gain += gains[t]
	var pool := 0.0
	var live_donors := []
	for d in donors:
		var di := int(d)
		if unlocked.has(di) and w[di] > 0.0:
			live_donors.append(di)
			pool += w[di]
	if total_gain <= 0.0 or pool <= 0.0:
		return
	# Nunca tira mais do que os doadores têm.
	var scale := minf(1.0, pool / total_gain)
	for t in gains:
		if unlocked.has(t):
			w[t] += gains[t] * scale
	var taken := total_gain * scale
	var pool_before := pool
	for d in live_donors:
		w[d] -= taken * (w[d] / pool_before)


static func roll_tier(chance_table: Dictionary, rng) -> int:
	return int(rng.weighted_pick(chance_table))


## Posição (0..1) dentro da faixa do atributo, conforme o tier.
## Crítico da Fortuna leva ao topo da faixa do tier.
static func roll_value_pct(economy: Dictionary, tier: int, rng, crit: bool = false) -> float:
	var r: Array = economy["tiers"]["value_pct"][str(tier)]
	if crit:
		return float(r[1])
	return rng.randf_range(float(r[0]), float(r[1]))


static func stat_value(stat_def: Dictionary, pct: float) -> float:
	var lo := float(stat_def["min"])
	var hi := float(stat_def["max"])
	return snappedf(lo + (hi - lo) * pct, 0.01)

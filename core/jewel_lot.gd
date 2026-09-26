## Lotes de joias: pilhas de 10, 20 e 30 ocupam um slot e são negociadas como um item.
## Lume é a unidade de conta dos preços.
extends RefCounted


## Empacota uma quantidade nos maiores lotes possíveis; o resto fica solto.
static func pack(count: int, economy: Dictionary) -> Dictionary:
	var sizes: Array = economy["lot_sizes"].duplicate()
	sizes.sort()
	sizes.reverse()
	var lots := []
	var left := count
	for s in sizes:
		var size := int(s)
		while left >= size:
			lots.append(size)
			left -= size
	return {"lots": lots, "loose": left}


static func price_in_lume(jewel: String, count: int, economy: Dictionary) -> int:
	return int(economy["jewels"][jewel]["price_in_lume"]) * count

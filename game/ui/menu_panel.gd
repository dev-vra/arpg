## Menu: salvar, novo jogo e créditos.
extends "res://game/ui/panel_base.gd"

var confirm := false
var reset_btn: Button


func title() -> String:
	return "Menu"


func build() -> void:
	panel_size = Vector2(620, 520)
	body.add_child(UiTheme.button("Salvar agora", _save))
	reset_btn = UiTheme.button("Novo jogo (apaga o save)", _reset)
	body.add_child(reset_btn)
	body.add_child(rich("\n[color=#8b8f99]MVP de teste · Fase 1\nArte 3D: Quaternius (CC0). Molduras e partículas: Kenney (CC0).\nÍcones: game-icons.net por Lorc, Delapouite, Skoll, Willdabeast, Zeromancer, Felbrigg, Sbed e Carl Olsen (CC BY 3.0).\nModo solo offline; o save fica no aparelho, assinado contra edição.[/color]"))


func _reset() -> void:
	if not confirm:
		confirm = true
		reset_btn.text = "Toque de novo para confirmar"
		return
	GameState.reset_save()
	hud.world.travel("bastiao", "normal")


func _save() -> void:
	GameState.save_game()
	GameState.toast.emit("Jogo salvo", Color("#3fd67a"))

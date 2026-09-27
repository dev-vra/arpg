## Save local assinado por HMAC-SHA256 contra edição casual.
## É barreira de conveniência, não anti-cheat.
extends RefCounted

const KEY := "arpg-save-v1-7f3c9e1a"


static func signature(text: String) -> String:
	var h := HMACContext.new()
	h.start(HashingContext.HASH_SHA256, KEY.to_utf8_buffer())
	h.update(text.to_utf8_buffer())
	return h.finish().hex_encode()


static func write(path: String, data: Dictionary) -> bool:
	var body := JSON.stringify(data)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"body": body, "sig": signature(body)}))
	return true


## Retorna {} se não existe ou se a assinatura não bate.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var wrapper = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(wrapper) != TYPE_DICTIONARY or not wrapper.has("body"):
		return {}
	if signature(wrapper["body"]) != wrapper.get("sig", ""):
		push_warning("Save com assinatura inválida; ignorado.")
		return {}
	var data = JSON.parse_string(wrapper["body"])
	return data if typeof(data) == TYPE_DICTIONARY else {}

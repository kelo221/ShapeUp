extends RefCounted
class_name GodotClipboardUtil


static func set_text(text: String) -> void:
	DisplayServer.clipboard_set(text)


static func get_text() -> String:
	return DisplayServer.clipboard_get()

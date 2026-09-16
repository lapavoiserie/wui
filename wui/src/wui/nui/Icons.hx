package wui.nui;

/**
	The shared icon vocabulary (`nui.Icons`) as Segoe Fluent Icons glyphs.

	Drawn by a `FontIcon` in *Segoe Fluent Icons* (Windows 11), falling back to
	*Segoe MDL2 Assets* (Windows 10): both ship with the system, and most of
	their code points are shared. A name missing here draws its label instead,
	which is also what a received name outside the vocabulary draws.

	**Not yet checked on Windows**, unlike sui's SF Symbols, which were checked
	one by one: the code points below are the documented MDL2/Fluent ones as far
	as they are known here, and `bring-front`/`send-back` borrow the plain up
	and down arrows. The first run on a Windows machine is what confirms them.
**/
class Icons {
	public static final GLYPHS:Map<String, Int> = [
		"add" => 0xE710, "close" => 0xE711, "check" => 0xE73E, "delete" => 0xE74D,
		"edit" => 0xE70F, "search" => 0xE721, "settings" => 0xE713, "home" => 0xE80F,
		"info" => 0xE946, "warning" => 0xE7BA, "error" => 0xEA39, "menu" => 0xE700,
		"more" => 0xE712, "refresh" => 0xE72C, "share" => 0xE72D, "star" => 0xE734,
		"person" => 0xE77B, "lock" => 0xE72E, "unlock" => 0xE785, "mail" => 0xE715,
		"phone" => 0xE717, "save" => 0xE74E,
		"back" => 0xE76B, "forward" => 0xE76C, "up" => 0xE70E, "down" => 0xE70D,
		"play" => 0xE768, "pause" => 0xE769, "stop" => 0xE71A, "record" => 0xE7C8,
		"swap" => 0xE8AB, "broadcast" => 0xE93E,
		"mic" => 0xE720, "mic-off" => 0xEC54, "speaker" => 0xE767, "speaker-off" => 0xE74F,
		"headphones" => 0xE7F6,
		"eye" => 0xE890, "eye-off" => 0xED1A,
		"folder" => 0xE8B7, "document" => 0xE8A5, "image" => 0xE91B, "camera" => 0xE722,
		"video" => 0xE714, "clock" => 0xE917, "display" => 0xE7F4, "window" => 0xE737,
		"globe" => 0xE774, "text" => 0xE8D2, "palette" => 0xE790, "grid" => 0xF0E2,
		"layers" => 0xE81E, "bring-front" => 0xE74A, "send-back" => 0xE74B,
		"crop" => 0xE7A8, "move" => 0xE7C2, "rotate" => 0xE7AD,
	];

	/** The families a FontIcon is given, in order. **/
	public static inline var FONT = "Segoe Fluent Icons, Segoe MDL2 Assets";

	/** The glyph for a name, as text, or null when there is none. **/
	public static function glyphOf(name:Null<String>):Null<String> {
		if (name == null) return null;
		var code = GLYPHS.get(name);
		return code == null ? null : String.fromCharCode(code);
	}
}

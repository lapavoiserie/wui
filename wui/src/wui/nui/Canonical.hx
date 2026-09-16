package wui.nui;

/**
	The canonical node names `wui` accepts and what it builds for them.

	A tree that crosses between backends speaks the canonical vocabulary —
	`Toggle`, `TextInput`, `ProgressView`, `Button`/`label` (see
	`cui.nui.Describe`, the reference) — while `wui`'s own controls are named
	after WinUI's. `WinUISink` translates at the door, and
	`wui.macros.NodeValidator` must accept exactly what it translates: a node
	written with a canonical name was refused at compile time while the sink
	would have built it, which is how `vui`'s level meter fallback, a
	`ProgressView`, failed to compile on a Windows panel.

	One table, read at macro time and at runtime, so the two cannot disagree.
**/
class Canonical {
	/** The canonical names that are not `wui` control names. **/
	public static final aliases:Array<String> = ["Toggle", "TextInput", "ProgressView", "Picker"];

	/** Whether `type` is a canonical name this backend translates. **/
	public static function isAlias(type:String):Bool
		return aliases.indexOf(type) >= 0;

	/**
		The control a canonical type becomes, when its name alone decides. For
		`ProgressView` it does not — a value makes a bar, no value a ring — so
		this answers the ring, and `WinUISink.nativeTypeOf` looks at the props.
	**/
	public static function type(t:String):String {
		return switch (t) {
			case "Toggle": "ToggleSwitch";
			case "TextInput": "TextBox";
			case "Picker": "ComboBox";
			case "ProgressView": "ProgressRing";
			case _: t;
		}
	}

	/**
		Keys a canonical node carries that the wui control of the same name does
		not declare, because the sink translates them.

		An `Icon` is the case: the canon names the glyph (`name`, `label`), the
		control takes the character (`glyph`), and `WinUISink` looks one up from
		the other. Without this the validator refused the canonical node written
		under the control's own name. Found by the Farceur session.
	**/
	public static function translatedKeys(type:String):Array<String> {
		return switch (type) {
			case "Icon": ["name", "label"];
			case _: [];
		}
	}

	/** A canonical key, as the control spells it. **/
	public static function key(type:String, key:String):String {
		return switch [type, key] {
			case ["Button", "label"]: "text";
			case _: key;
		}
	}
}

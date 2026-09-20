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
	public static final aliases:Array<String> = ["Toggle", "TextInput", "ProgressView", "Picker", "ScrollView",
		"SecretInput", "Tabs", "Tab"];

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
			case "SecretInput": "PasswordBox";
			case "Picker": "ComboBox";
			case "ScrollView": "ScrollViewer";
			case "ProgressView": "ProgressRing";
			// The canon's tabs. Only the selected `Tab` carries its page, which
			// is what a `TabViewItem` with no content already is.
			case "Tabs": "TabView";
			case "Tab": "TabViewItem";
			case _: t;
		}
	}

	/**
		The canonical name of a `wui` control, when the two differ.

		The inverse of `type`, written out rather than derived, because it is
		not a function: `ProgressBar` and `ProgressRing` are both a canonical
		`ProgressView`, and which one gets built is decided by the props in
		`WinUISink.nativeTypeOf`. A loop over `aliases` would have had to pick
		one and would have picked the wrong one half the time.

		`wui.nui.Vocabulary` reads this so the vocabulary markup checks against
		says `Toggle` rather than `ToggleSwitch`. Until it did, the two halves
		of this backend disagreed about the name of the same thing: the sink
		translated `Toggle` at the door and the schema refused it at compile
		time, so a tree that would have rendered could not be written.
	**/
	public static function canonOf(control:String):Null<String> {
		return switch (control) {
			case "ToggleSwitch": "Toggle";
			case "TextBox": "TextInput";
			case "PasswordBox": "SecretInput";
			case "ComboBox": "Picker";
			case "ScrollViewer": "ScrollView";
			case "ProgressRing" | "ProgressBar": "ProgressView";
			case "TabView": "Tabs";
			case "TabViewItem": "Tab";
			case _: null;
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
			// A `Tab`'s icon is a glyph name, like a `Button`'s; the control
			// takes the character, and the sink looks one up from the other.
			case "Tab": ["icon"];
			case "Text": ["scale"];
			case _: [];
		}
	}

	/** A canonical key, as the control spells it. **/
	public static function key(type:String, key:String):String {
		return switch [type, key] {
			case ["Button", "label"]: "text";
			// A tab's label is its header.
			case ["Tab", "label"]: "header";
			// The canon calls a text's step its `scale`; this backend's control
			// calls it `font`, and takes it with a capital.
			case ["Text", "scale"]: "font";
			case _: key;
		}
	}
}

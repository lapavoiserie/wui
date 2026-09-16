package wui.mui;

/**
	`wui`'s conformance for `mui.ui.Icon`: a name from the shared vocabulary,
	drawn as its Segoe Fluent Icons glyph (`wui.nui.Icons`).
**/
class Icon extends wui.ui.Icon {
	public function new(name:mui.ui.IconName, ?label:String) {
		var glyph = wui.nui.Icons.glyphOf(name);
		super(glyph == null ? "" : glyph);
		properties.set("name", (name : String));
		if (label != null && label != "") properties.set("label", label);
	}
}

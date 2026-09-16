package wui.ui;

import wui.View;

/**
	A glyph from Segoe Fluent Icons: `mui.ui.Icon` on wui.

	The node carries the glyph, already looked up (`wui.nui.Icons`): the node
	runtime only ever sees a character and a font. Coloured by `foregroundColor`
	like text; its size is `size`, in points.
**/
@:winuiType("FontIcon")
@:build(wui.macros.ControlBuilder.build())
class Icon extends View {
	@:winrt("Glyph") public var glyph:Null<String>;
	@:winrt("FontFamily") @:defaultValue("Segoe Fluent Icons, Segoe MDL2 Assets") public var font:Null<String>;
	@:winrt("Foreground") public var foregroundColor:Null<String>;
	@:winrt("FontSize") public var size:Null<Float>;

	public function new(glyph:String) {
		super("Icon");
		this.glyph = glyph;
	}
}

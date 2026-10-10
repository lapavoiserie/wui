package wui.ui;

import wui.View;

/**
	A `Button` inside a `Toolbar`: built by `WinUISink.nativeTypeIn` for a
	button whose parent is a `CommandBar`, never written as such.

	Keyed like a `Button` -- the sink translates the canon's `label` to `text`
	before it looks at the control -- so a toolbar button takes the same
	properties wherever it is described. Its icon is a glyph, as a `Button`'s
	is; the label names it for UI Automation.
**/
@:winuiType("AppBarButton")
@:build(wui.macros.ControlBuilder.build())
class AppBarButton extends Control {
	@:winrt("Label")
	public var text:String;

	@:winrt("AppBarIcon")
	public var icon:Null<String>;

	@:winrt("Click")
	public var onClick:Null<Void->Void>;

	public function new(label:String, ?icon:String) {
		super("AppBarButton");
		this.text = label;
		if (icon != null) this.icon = icon;
	}
}

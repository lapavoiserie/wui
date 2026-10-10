package wui.ui;

import wui.View;

/** A `Menu` inside a menu: built by `WinUISink.nativeTypeIn`, never written. **/
@:winuiType("MenuFlyoutSubItem")
@:build(wui.macros.ControlBuilder.build())
class MenuFlyoutSubItem extends View {
	@:winrt("Text") public var label:String;

	public function new(label:String, ?items:Array<View>) {
		super("MenuFlyoutSubItem", items);
		this.label = label;
	}
}

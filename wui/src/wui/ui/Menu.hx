package wui.ui;

import wui.View;

/**
	The canon's `Menu`: a label, and its items behind it -- a
	`DropDownButton` with a `MenuFlyout`, made with the button
	(`menuSetup`).

	Its children take the flyout's kinds (`WinUISink.nativeTypeIn`): a
	`Button` a `MenuFlyoutItem`, whose act is the button's `onClick`; a
	`Divider` a `MenuFlyoutSeparator`; a nested `Menu` a
	`MenuFlyoutSubItem`.
**/
@:winuiType("DropDownButton")
@:build(wui.macros.ControlBuilder.build())
class Menu extends Control {
	@:winrt("Content") public var label:String;

	public function new(label:String, ?items:Array<View>) {
		super("Menu", items);
		this.label = label;
	}
}

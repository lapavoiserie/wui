package wui.ui;

import wui.View;

/** A `Divider` in a menu: built by `WinUISink.nativeTypeIn`, never written. **/
@:winuiType("MenuFlyoutSeparator")
@:build(wui.macros.ControlBuilder.build())
class MenuFlyoutSeparator extends View {
	public function new() {
		super("MenuFlyoutSeparator");
	}
}

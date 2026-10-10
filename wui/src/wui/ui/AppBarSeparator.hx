package wui.ui;

import wui.View;

/** A `Divider` in a toolbar: built by `WinUISink.nativeTypeIn`, never written. **/
@:winuiType("AppBarSeparator")
@:build(wui.macros.ControlBuilder.build())
class AppBarSeparator extends View {
	public function new() {
		super("AppBarSeparator");
	}
}

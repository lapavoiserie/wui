package wui.ui;

import wui.View;

/**
	The canon's `Divider`: a line between what comes before and after.

	On a page, a Border one pixel high in the theme's divider colour
	(`dividerSetup`). In a menu it is a `MenuFlyoutSeparator`, in a toolbar
	an `AppBarSeparator` -- `WinUISink.nativeTypeIn` chooses.

	`@:noWinuiAlias`: a Border like `Border` itself, which keeps the name.
**/
@:winuiType("Border")
@:noWinuiAlias
@:build(wui.macros.ControlBuilder.build())
class Divider extends View {
	public function new() {
		super("Divider");
	}
}

package wui.ui;

import wui.View;

/**
	The canon's `Toolbar`: a screen's commands, in the bar WinUI keeps for them.

	Drawn where the node stands, at the head of the page: `title` on the left
	as the bar's content, the commands on the right as primary commands, with
	their labels beside their icons. A child takes the command it can be
	(`WinUISink.nativeTypeIn`): a `Button` an `AppBarButton`, a `Toggle` an
	`AppBarToggleButton`. Anything else -- a picker, a primary button -- is
	wrapped as it is in an `AppBarElementContainer` when it is inserted.
**/
@:winuiType("CommandBar")
@:build(wui.macros.ControlBuilder.build())
class CommandBar extends Control {
	/** The screen's name, in the person's language. **/
	@:winrt("CommandBarTitle")
	public var title:Null<String>;

	public function new(?title:String, ?commands:Array<View>) {
		super("CommandBar", commands);
		if (title != null) this.title = title;
	}
}

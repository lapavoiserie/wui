package wui.ui;

import wui.View;

/**
	The canon's `ReorderList`: rows in an order the person sets by hand, in a
	`ListView` whose items can be dragged.

	The list reports a move and never performs it: a row dropped elsewhere
	is put back where it was, and `onMove` says `"from,to"`; the next tree
	shows the order the application's data now has. Never only by dragging:
	with `moveUpLabel` and `moveDownLabel` a row's context menu offers the
	two moves one step at a time, and Alt+Up / Alt+Down move the focused
	row -- the labels are the application's words, the only ones there are.
	`onMove` is canonical (`Canonical.canonKeys`).
**/
@:winuiType("ListView")
@:build(wui.macros.ControlBuilder.build())
class ReorderList extends Control {
	@:winrt("ReorderUpLabel") public var moveUpLabel:Null<String>;
	@:winrt("ReorderDownLabel") public var moveDownLabel:Null<String>;

	public function new(?rows:Array<View>) {
		super("ReorderList", rows);
	}
}

package wui.ui;

import wui.View;

/**
	A column that shares the height it is given, as a surface's root does: a
	Grid tagged `column`, one row per child, `Auto` for content and `*` for
	what fills (a ScrollView, tabs, a sidebar). See `wui_node_insert`.

	For wui's own wrappers rather than for applications: `mui.App` puts the
	menu bar above the application's tree in one. In a `VStack` -- a
	StackPanel, which gives its children all the height they ask for -- a
	sidebar under the menu bar stopped where its page did.

	Not every `VStack`: see the note there on the day that was tried.
**/
@:winuiType("Grid")
@:build(wui.macros.ControlBuilder.build())
class Column extends View {
	public function new(children:Array<View>) {
		super("Column", children);
	}
}

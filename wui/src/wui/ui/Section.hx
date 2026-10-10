package wui.ui;

import wui.View;

/**
	The canon's `Section`: a group of rows under an optional heading.

	A vertical StackPanel whose first child is always its heading, collapsed
	while there is no title, so the children's indices are shifted by one in
	`wui_node_insert` rather than by a count that changes. Inside a `Form` the
	sink tags it `formsection` when it is made, and its children become the
	form's rows; untitled, it is only the gap between groups.
**/
@:winuiType("StackPanel")
@:noWinuiAlias
@:build(wui.macros.ControlBuilder.build())
class Section extends View {
	@:winrt("SectionTitle") public var title:Null<String>;
	@:winrt("Spacing") public var spacing:Float = 8;
	@:winrt("Tag") public var kind:String = "section";

	public function new(?title:String, rows:Array<View>) {
		super("Section", rows);
		if (title != null) this.title = title;
	}
}

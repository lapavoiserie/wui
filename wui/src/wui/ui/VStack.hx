package wui.ui;

import wui.View;

/**
	Vertical stack layout. A WinUI Grid with one row per child.

	```haxe
	new VStack([
	    new Text("Top"),
	    new Text("Bottom")
	], 8)
	```

	## A Grid, for the same two reasons `HStack` is one

	It was a vertical StackPanel, and a StackPanel measures its children with an
	**unbounded** height: it hands each one the size that child asks for and
	lays them end to end. Two things follow, and both were reported from a
	Windows screen rather than found here.

	A `ScrollViewer` inside one never scrolls. Given all the height it asks for,
	it has nothing left over to scroll, so a received panel taller than its
	window was simply cut off. `wui_node_insert` already knew the answer — a
	surface's root is a Grid whose ScrollViewer row is sized `*` — but only the
	root was one, so the limit was written down instead: *put the ScrollView at
	the surface's root*. A rule an application has to remember is the shape of
	defect this backend keeps removing.

	A vertical `Spacer` comes out zero high, which is exactly what `HStack`
	found in the other direction: a panel with no leftover room has none to give
	away. The `column` branch sizes a spacer's row `*` too, so the spacers share
	what the column does not use.

	## What changed with it

	`Spacing` is a StackPanel member and a Grid does not have one — asking for
	it does not compile, which is the sort of thing worth learning from MSVC
	rather than from a blank column. `RowSpacing` is the Grid's own, and means
	the same thing.

	`Orientation` went with the StackPanel. It was the only thing telling the
	two stacks apart while both were one; now each names its own WinRT type and
	its own tag.
**/
@:winuiType("Grid")
@:build(wui.macros.ControlBuilder.build())
class VStack extends View {
	/** A Grid's own, and what `Spacing` meant on the panel this replaces. **/
	@:winrt("RowSpacing") public var spacing:Float = 0;

	// The ones a Grid actually has, declared rather than inherited -- see
	// `HStack`, which says why asking a Grid for a StackPanel's member is a
	// compile error worth having.
	@:winrt("Padding") public var padding:Null<Float>;
	@:winrt("Background") public var background:Null<String>;
	@:winrt("BorderBrush") public var borderBrush:Null<String>;
	@:winrt("BorderThickness") public var borderThickness:Null<Float>;
	@:winrt("CornerRadius") public var cornerRadius:Null<Float>;

	/**
		What kind of Grid this is, for code that only sees a control.

		`wui_node_insert` receives a handle, not a node type, and three of this
		backend's shapes are a Grid: a row queues its children in columns, a
		column in rows, and a `ZStack` means them to overlap. The tag is how
		they are told apart at the moment a child arrives — and `column` is
		already what a surface's root is tagged, so the branch that gives a
		ScrollViewer its `*` row is one that was already written.
	**/
	@:winrt("Tag") public var kind:String = "column";

	public function new(children:Array<View>, ?spacing:Float) {
		// The class name, not the WinRT type. The push sink keys every branch
		// it generates -- `create` included -- on the name a node reports, and
		// a shared name puts two controls on one merged branch, which can only
		// carry one of the two sets of defaults. While both stacks were a
		// StackPanel that came out as every stack in the tree being horizontal.
		super("VStack", children);
		if (spacing != null) this.spacing = spacing;
	}
}

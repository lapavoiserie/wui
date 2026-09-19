package wui.ui;

import wui.View;

/**
	Vertical stack layout. Maps to WinUI StackPanel with Vertical orientation.

	```haxe
	new VStack([
	    new Text("Top"),
	    new Text("Bottom")
	], 8)
	```

	## A ScrollView inside one does not scroll

	A StackPanel measures its children with an **unbounded** height: it hands
	each one the size that child asks for and lays them end to end. So a
	`ScrollViewer` inside a `VStack` is given all the height it asks for and has
	nothing left over to scroll, and a vertical `Spacer` -- an empty Border
	asking for no height -- comes out zero high. Put the ScrollView at the
	surface's root, whose Grid gives it a `*` row.

	**This was made a Grid tagged `column` on 2026-09-19 and put back the same
	day.** `HStack` is one, for the mirror-image reasons, and the change looked
	like the same move; the Farceur pupitre came back **entirely black** under
	it. Everything was laid out -- UIA reported sane, stacked rectangles for
	every control -- and nothing was painted. That is not a layout failure, so
	the cause is not understood yet, and a limit that costs scrolling is worth
	less than a panel that draws.
**/
@:winuiType("StackPanel")
@:build(wui.macros.ControlBuilder.build())
class VStack extends Stack {
	// Declared with its default, so the generated `create` applies it: both
	// stacks are a StackPanel and only this tells them apart.
	@:winrt("Orientation") public var orientation:String = "Vertical";

	public function new(children:Array<View>, ?spacing:Float) {
		// The class name, not the WinRT type. The push sink keys every branch
		// it generates -- `create` included -- on the name a node reports, and
		// orientation is applied there from the declared default rather than
		// pushed as a property. Reporting "StackPanel" put both stacks on one
		// merged branch, which can only carry one of the two defaults: every
		// stack in the tree came out horizontal, and a screenful of rows
		// collapsed onto a single line.
		super("VStack", children);
		// orientation carries its declared default
		if (spacing != null) this.spacing = spacing;
	}
}

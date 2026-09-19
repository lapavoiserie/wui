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

	## It was made a Grid on 2026-09-19 and put back the same day

	`HStack` is a Grid, for the mirror-image reasons, and this looked like the
	same move. The Farceur pupitre came back **entirely black** under it: not
	one pixel, no text, no button chrome, no thumbnails. Everything was laid
	out -- UIA reported sane, stacked rectangles for every control, the
	ScrollViewer 784x1827, `IsOffscreen` false, and it scrolled -- and nothing
	was painted. Tout est placé, rien n'est peint: not a layout failure, so
	**the cause is still unknown**, and a limit that costs a nested ScrollView
	is worth less than a panel that draws.

	What the tree that went black actually was, measured rather than guessed,
	so whoever reopens this starts with facts:

	- `ScrollView` tagged `scroll` > one `VStack` (spacing 10) > a `VStack` per
	  section. Under the change, every one of those was a Grid tagged `column`,
	  nested inside another.
	- **No `Spacer` anywhere in it**, so no row was ever sized `*`: every row
	  was `Auto`, which is the case where a column Grid and a vertical
	  StackPanel should agree.
	- **No container carried a background.** The only `backgroundColor` in the
	  tree is on three Buttons inside `HStack`s, so nothing opaque could have
	  been drawn over the rest.
	- The last child of the root column is an ordinary `VStack` with no
	  modifier at all.

	Which rules out the two readings that would have been comfortable: a
	container painting over its siblings, and children piling into row 0 for
	want of a `Grid::SetRow` -- the rectangles were stacked, so the rows worked.
	It has to be found at the image on Windows.
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

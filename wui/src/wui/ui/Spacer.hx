package wui.ui;

/**
	Flexible space between siblings.

	A `Border` with nothing in it: WinUI has no spacer. Given a `minSize` it
	holds at least that much.

	## It is a node type of its own

	It reports `Spacer` and builds a `Border`, like every other control here
	whose WinRT name is not its own. It used to report `Border` and set a
	property, which worked for a tree built in Haxe and not at all for one that
	**arrived**: the canon has a `Spacer`, `wui_node_create` had no branch for
	it, and a received spacer was drawn as the text `?Spacer`. `pui`'s own
	fallback for a missing video monitor sends two.

	## `Tag`, under a second name

	`Border` already names that member `tag`, and a Haxe field cannot be
	redeclared in a subclass -- so this is a second name for the same member,
	carrying the default. That is what makes a spacer recognisable at the moment
	a child arrives: by then it is a WinRT control like any other, with nothing
	left to say about what it was meant to be, and `wui_node_insert` gives a
	tagged one the row or the column that shares the leftover room.
**/
@:winuiType("Border")
@:build(wui.macros.ControlBuilder.build())
class Spacer extends Border {
	/** `Border.tag`, with the value that makes this one a spacer. **/
	@:winrt("Tag") @:defaultValue("spacer") public var kind:Null<String>;

	public function new(?minSize:Float) {
		super("Spacer");
		// Set here as well as declared: the declared default is applied by the
		// generated `create`, which only runs for a node that arrived.
		this.tag = "spacer";
		if (minSize != null) {
			this.height = minSize;
			this.width = minSize;
		}
	}
}

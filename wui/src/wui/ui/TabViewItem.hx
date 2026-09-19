package wui.ui;

/**
	One tab: a header, and the view behind it.

	A `TabView` in WinUI does not hold contents directly — it holds items, and
	each item holds one. `mui`'s vocabulary has no such thing, and should not:
	a tab is a label and a view, which is what `TabView`'s constructor turns
	into these.

	The canon calls this a `Tab` and its label a `label`; `wui.nui.Canonical`
	translates both at the door.
**/
@:winuiType("TabViewItem")
@:build(wui.macros.ControlBuilder.build())
class TabViewItem extends Control {
	@:winrt("Header") public var header:Null<String>;

	/**
		The glyph shown beside the header.

		The canon names an icon (`nui.Icons`); this takes the character, and
		`WinUISink` looks one up from the other exactly as it does for a
		`Button`. A name nothing knows leaves the tab without an icon rather
		than with a box.
	**/
	@:winrt("TabIconGlyph") public var icon:Null<String>;

	/**
		Whether the person can close this tab. Off unless an application says so.

		The tabs are the tree: closing one would remove a tab the sender still
		holds, and the next tree would put it back.
	**/
	@:winrt("IsClosable") @:defaultValue(false) public var closable:Null<Bool>;

	public function new(header:String, content:View, ?icon:String) {
		super("TabViewItem", [content]);
		this.header = header;
		if (icon != null) this.icon = icon;
	}
}

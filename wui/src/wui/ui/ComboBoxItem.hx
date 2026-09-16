package wui.ui;

/**
	One option of a `ComboBox`.

	Its text is `Content`, boxed: a `ComboBoxItem` is a content control, and the
	closed list shows the selected item's content. A bare `TextBlock` inserted
	as an item would be one element needed in two places — the list and the
	selection box — and WinUI parents an element once.
**/
@:winuiType("ComboBoxItem")
@:build(wui.macros.ControlBuilder.build())
class ComboBoxItem extends Control {
	@:winrt("Content") public var text:Null<String>;

	public function new(text:String) {
		super("ComboBoxItem");
		this.text = text;
	}
}

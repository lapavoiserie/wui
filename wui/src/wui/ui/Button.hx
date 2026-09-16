package wui.ui;

import wui.View;
import wui.state.StateAction;

/**
	A clickable button.

	`text` rather than `label`: the transpiled path called it `label` while the
	node path called it `text`, for the same thing. `nui` settled that naming in
	B2 — text is an ordinary property — so the declaration follows it and the
	generator accepts both while the old name is still in the wild.
**/
@:winuiType("Button")
@:build(wui.macros.ControlBuilder.build())
class Button extends Control {
	@:winrt("Content")
	public var text:String;

	/**
		An icon beside the text: a name from the shared vocabulary (`nui.Icons`),
		drawn as its Segoe Fluent glyph. The node runtime composes the content --
		a glyph and the text in a row, or the glyph alone -- and names the button
		for UI Automation by its text, or by the icon's name when it has none.
	**/
	@:winrt("ButtonIcon")
	public var icon:Null<String>;

	/** The icon's name, for UI Automation. Set by the sink with `icon`. **/
	@:winrt("ButtonIconName")
	public var iconName:Null<String>;

	/** The handler. A var like any other property -- see `View`. **/
	@:winrt("Click")
	public var onClick:Null<Void->Void>;

	public function new(label:String, ?icon:Dynamic, ?action:StateAction) {
		super("Button");
		this.text = label;
		if (icon != null) this.icon = Std.string(icon);
		if (action != null) properties.set("action", action);
	}
}

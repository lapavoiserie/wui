package wui.ui;

import wui.View;

/**
	A `Toggle` inside a `Toolbar`: built by `WinUISink.nativeTypeIn` for a
	toggle whose parent is a `CommandBar`, whatever its style -- in a bar, a
	switch would be out of place and a pressed button is the platform's own
	answer. Its label is the button's.

	A `ToggleButton` underneath, so it reports through `Click` like one.
**/
@:winuiType("AppBarToggleButton")
@:build(wui.macros.ControlBuilder.build())
class AppBarToggleButton extends Control {
	@:winrt("Label")
	public var label:String;

	@:winrt("IsChecked")
	public var isOn:Bool = false;

	/** Read by `nativeTypeOf` outside a bar; nothing to apply here. **/
	@:winrt("ToggleStyle")
	public var style:Null<String>;

	public function new(label:String, ?isOn:Bool) {
		super("AppBarToggleButton");
		this.label = label;
		if (isOn != null) this.isOn = isOn;
	}
}

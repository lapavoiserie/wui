package wui.ui;

import wui.View;

/**
	A button that stays pressed while on: what the canon's `Toggle` asks for
	with `style="button"`, a weekday in a row of seven or a filter.

	`WinUISink.nativeTypeOf` builds one for that style; a `Toggle` without it
	stays a `ToggleSwitch`. WinUI keeps the control in `Primitives`, hence the
	qualified name, which the generator splices after `winrt_controls::`.

	Its value reports through `Click`, not `Checked`/`Unchecked`: a click is
	the person's alone, so a value the runtime sets is never reported back as
	an edit, with no guard needed.
**/
@:winuiType("Primitives::ToggleButton")
@:build(wui.macros.ControlBuilder.build())
class ToggleButton extends Control {
	@:winrt("Content")
	public var label:String;

	@:winrt("IsChecked")
	public var isOn:Bool = false;

	/** Read by `nativeTypeOf` to choose this control; nothing to apply. **/
	@:winrt("ToggleStyle")
	public var style:Null<String>;

	public function new(label:String, ?isOn:Bool) {
		super("ToggleButton");
		this.label = label;
		if (isOn != null) this.isOn = isOn;
	}
}

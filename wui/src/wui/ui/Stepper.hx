package wui.ui;

import wui.View;

/**
	The canon's `Stepper`: a whole number between bounds, in a `NumberBox`
	with its spin buttons inline.

	The bounds are part of what the value means, so they are not a hint: the
	NumberBox coerces to them, and a value typed in is rounded to a whole
	number before it is reported. Neither the bounds nor the value the
	application sets are reported back to it as an edit. `onValue` is
	canonical (`Canonical.canonKeys`), an `Int`.
**/
@:winuiType("NumberBox")
@:build(wui.macros.ControlBuilder.build())
class Stepper extends Control {
	@:winrt("Header") public var label:String;
	@:winrt("StepperValue") public var value:Int = 0;
	@:winrt("StepperMin") public var min:Int;
	@:winrt("StepperMax") public var max:Int;
	@:winrt("SmallChange") public var step:Null<Int>;

	public function new(label:String, value:Int, min:Int, max:Int) {
		super("Stepper");
		this.label = label;
		this.value = value;
		this.min = min;
		this.max = max;
	}
}

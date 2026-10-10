package wui.ui;

import wui.View;

/**
	The canon's `DateInput`: a day, in a `CalendarDatePicker`.

	The value crosses as `YYYY-MM-DD`, a day and not an instant. It is shown
	from noon UTC on that day, which is the same day in every time zone a
	person can be in, and read back as the day the picker shows. An empty
	value is no day. `min` and `max` bound what the calendar offers.
	`onValue` is canonical (`Canonical.canonKeys`), a `String`.
**/
@:winuiType("CalendarDatePicker")
@:build(wui.macros.ControlBuilder.build())
class DateInput extends Control {
	@:winrt("Header") public var label:String;
	@:winrt("DateValue") public var value:Null<String>;
	@:winrt("DateMin") public var min:Null<String>;
	@:winrt("DateMax") public var max:Null<String>;

	public function new(label:String, ?value:String) {
		super("DateInput");
		this.label = label;
		if (value != null) this.value = value;
	}
}

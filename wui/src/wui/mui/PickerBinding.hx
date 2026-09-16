package wui.mui;

/**
	`wui`'s conformance for `mui.ui.PickerBinding`: the cell holding the chosen
	option's index, `-1` for none.
**/
abstract PickerBinding(wui.state.State<Int>) {
	public inline function new(v:wui.state.State<Int>) this = v;

	@:from static inline function fromState(s:wui.state.State<Int>):PickerBinding
		return new PickerBinding(s);

	public inline function unwrap():wui.state.State<Int> return this;
}

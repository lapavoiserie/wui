package wui.ui;

/**
	A horizontal progress bar, determinate when given a value.

	The bar is WinUI's answer to "how far along is this": `ProgressRing` is its
	answer to "something is happening". `mui.ui.ProgressView` needs both — a
	value draws a bar, no value a ring, which is what the other backends draw —
	and until this class existed a determinate progress on Windows was a ring
	filling up, and a received tree's `ProgressView` showed as `?ProgressView`.
	Asked for by the Farceur session, whose meters need a bar.

	`max` defaults to 1: `mui.ui.ProgressView` takes a fraction, as every other
	backend does, and WinUI's own default of 100 would draw 0.4 as nothing.
**/
@:winuiType("ProgressBar")
@:build(wui.macros.ControlBuilder.build())
class ProgressBar extends Control {
	@:winrt("Value") public var value:Null<Float>;
	@:winrt("Maximum") public var max:Null<Float> = 1;
	@:winrt("IsIndeterminate") public var isIndeterminate:Null<Bool>;

	public function new(?value:Float) {
		super("ProgressBar");
		if (value != null) {
			this.max = 1;
			this.value = value;
			this.isIndeterminate = false;
		} else {
			this.isIndeterminate = true;
		}
	}
}

package wui.mui;

/**
	`wui`'s conformance for `mui.ui.ProgressView`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `wui`.

	## A bar or a ring

	With a value it is a `ProgressBar`; without one, a `ProgressRing`. That is
	what the platform means by each — a bar says how far, a ring says busy — and
	it is what the other backends draw for the same two calls. It used to be a
	ring in both cases, filling up like a pie for a download.

	It extends the bar and swaps its node type for the ring when there is no
	value, rather than being two classes: `mui.Contract` names one type, and
	`wui.macros.PushCoverage` judges a class by the nearest ancestor the sink
	knows, which a plain `Control` is not. The properties set are the same keys
	on both controls. The label is not drawn: neither WinUI control has one.
**/
class ProgressView extends wui.ui.ProgressBar {
    public function new(?label:String, ?value:Float) {
        super(value);
        if (value == null)
            viewType = "ProgressRing";
    }
}

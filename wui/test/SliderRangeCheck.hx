/**
	A slider's range edges are applied under the echo guard. Run with:

	    haxe -cp src -cp test -lib rui -lib nui -lib mui -lib kui -main SliderRangeCheck --interp

	## The defect this exists for

	The Farceur régie carries a "Durée" slider, `{min: 0.2, max: 5, value: 1}`.
	Every time a pupitre attached, the engine received an action carrying
	`0.2` — nobody had touched anything — and the transition length in the
	user's saved project was rewritten from 1 s to 0.2 s.

	A range edge moves the VALUE when it crosses it, and a fresh WinUI Slider
	holds 0. So applying `Minimum(0.2)` raises the value from 0 to 0.2 and
	raises `ValueChanged` with it. Attaching is exactly when a received tree
	first applies its props, and that application was not under the guard the
	edited properties use — the guard was written for values pushed at a
	control AFTERWARDS.

	A slider whose minimum is 0 can never show it, which is why every panel
	built before this one was fine.

	The control itself is proven on Windows, not here: this reads the C++ the
	generator emits, which is where the guard is or is not.
**/
class SliderRangeCheck {
	static var failures = 0;

	static function check(label:String, ok:Bool, ?got:Dynamic) {
		if (!ok) failures++;
		Sys.println((ok ? "ok   " : "FAIL ") + label + (ok || got == null ? "" : '  (got: $got)'));
	}

	/** The statement the generated runtime uses for one prop of one control. **/
	static function setterFor(runtime:String, type:String, prop:String):String {
		var head = 't == "$type" && k == "$prop"';
		var at = runtime.indexOf(head);
		if (at < 0) return "";
		var stop = runtime.indexOf("return;", at);
		return stop < 0 ? runtime.substr(at) : runtime.substring(at, stop);
	}

	static function main() {
		var runtime = SliderRangeVocabulary.runtime();
		check("the node runtime was generated", runtime.length > 0);

		var min = setterFor(runtime, "Slider", "min");
		var max = setterFor(runtime, "Slider", "max");
		check("a Slider's min is applied by the runtime", min != "", min);

		// The guard: the event the clamp raises happens inside the call, so
		// `g_setting` is what makes it ours rather than an edit.
		check("and under the echo guard", min.indexOf("g_setting[h] = true") > 0
			&& min.indexOf("g_setting[h] = false") > 0, min);
		check("marking what the control settled on", min.indexOf("g_doubleMark[h] = c.Value()") > 0, min);
		check("the same for max", max.indexOf("g_setting[h] = true") > 0
			&& max.indexOf("g_doubleMark[h] = c.Value()") > 0, max);

		// The value itself keeps its own setter: it holds a value back while
		// the user is dragging, which a range edge must not do.
		var value = setterFor(runtime, "Slider", "value");
		check("the value still goes through setSlider", value.indexOf("setSlider(c, h,") > 0, value);

		// A control with no range is untouched by any of this.
		var toggle = setterFor(runtime, "ToggleSwitch", "isOn");
		check("a toggle still goes through setToggle", toggle.indexOf("setToggle(c, h,") > 0, toggle);

		Sys.println(failures == 0 ? "\nall good" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}

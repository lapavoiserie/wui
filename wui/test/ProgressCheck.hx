import nui.Node;
import nui.PropValue;

/**
	A progress is a bar when it has a value and a ring when it has none, on
	both paths, on a scale of one. Run with:

	    haxe -cp src -cp test -lib rui -lib nui -lib mui -main ProgressCheck --interp

	Three places had to agree, and none of them could see the others: the view
	an app builds (`wui.mui.ProgressView`), the control a received tree becomes
	(`wui.nui.WinUISink`), and the vocabulary the C++ node factory is generated
	from (`wui.nui.Vocabulary`, read here at macro time, the only time it runs).
	Before, a local progress was always a ring, and a received `ProgressView`
	was drawn as the text "?ProgressView".
**/
class ProgressCheck {
	static var failures = 0;

	static function check(label:String, ok:Bool) {
		if (!ok)
			failures++;
		Sys.println((ok ? "ok   " : "FAIL ") + label);
	}

	static function main() {
		// --- A received tree ---
		var withValue = new Node("ProgressView").prop("value", PFloat(0.4)).prop("label", PString("export"));
		var without = new Node("ProgressView").prop("label", PString("busy"));
		check("a received ProgressView with a value becomes a ProgressBar", wui.nui.WinUISink.nativeTypeOf(withValue) == "ProgressBar");
		check("and without one, a ProgressRing", wui.nui.WinUISink.nativeTypeOf(without) == "ProgressRing");
		check("the other renames still apply", wui.nui.WinUISink.nativeTypeOf(new Node("Toggle")) == "ToggleSwitch");
		check("and a native name passes through", wui.nui.WinUISink.nativeTypeOf(new Node("ProgressRing")) == "ProgressRing");

		// --- A view built here ---
		var bar = new wui.mui.ProgressView("export", 0.4);
		check("a local ProgressView with a value is a ProgressBar", bar.viewType == "ProgressBar");
		// Read from `properties`, which is what the push path describes: the
		// generated setters write there and nowhere else.
		check("on a scale of one", bar.properties.get("max") == 1 && bar.properties.get("value") == 0.4 && bar.properties.get("isIndeterminate") == false);
		var ring = new wui.mui.ProgressView("busy");
		check("without a value, a ProgressRing", ring.viewType == "ProgressRing");
		check("that spins", ring.properties.get("isIndeterminate") == true && !ring.properties.exists("value"));

		// --- The vocabulary the C++ factory is generated from ---
		var v:String = ProgressVocabulary.read();
		check("the node factory knows ProgressBar, created on a scale of one", v.indexOf("ProgressBar:true:1") >= 0);
		check("and a ProgressRing is created on a scale of one too", v.indexOf("ProgressRing:true:1") >= 0);
		if (failures > 0)
			Sys.println("     vocabulary: " + v);

		Sys.println(failures == 0 ? "\nall checks passed" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}

import nui.Node;
import nui.PropValue;

/**
	How a text is set, on both ways a tree reaches the node runtime. Run with:

	    haxe -cp src -cp test -lib rui -lib nui -lib mui -lib kui -main TextStyleCheck --interp

	The Windows end is proven there; what is checked here is that the canon's
	props reach the setters, and that a text built here crosses as the canon.
**/
class TextStyleCheck {
	static var failures = 0;

	static function check(label:String, ok:Bool, ?got:Dynamic) {
		if (!ok) failures++;
		Sys.println((ok ? "ok   " : "FAIL ") + label + (ok || got == null ? "" : '  (got: $got)'));
	}

	static function main() {
		// --- Built here ---
		var heading = new wui.mui.Text("Sources", Title);
		var counter = new wui.mui.Text("00:12:34", Body, {family: mui.ui.FontFamily.fromString("Inter"), weight: 600, numbers: Tabular});
		check("a text keeps the step it was given", heading.properties.get("font") == "Title");
		check("and a family, a weight and tabular digits", counter.properties.get("family") == "Inter"
			&& counter.properties.get("weight") == 600 && counter.properties.get("numbers") == "tabular"
			&& !counter.properties.exists("italic"));

		var canonical = wui.mui.FromViews.describeCanonical(new wui.ui.VStack([heading, counter]));
		var sentHeading = canonical.children[0];
		var sentCounter = canonical.children[1];
		check("on the wire a text is a Text, not this backend's TextBlock", sentHeading.type == "Text", sentHeading.type);
		check("on the wire a step is the canon's `scale`, in lower case",
			PropValueTools.asString(sentHeading.props.get("scale")) == "title" && !sentHeading.props.exists("font"),
			sentHeading.props.exists("font") ? "font" : PropValueTools.asString(sentHeading.props.get("scale")));
		check("and the rest cross as they are", PropValueTools.asString(sentCounter.props.get("family")) == "Inter"
			&& PropValueTools.asInt(sentCounter.props.get("weight")) == 600
			&& PropValueTools.asString(sentCounter.props.get("numbers")) == "tabular");
		check("a bold with no weight crosses as the weight it means",
			PropValueTools.asInt(wui.mui.FromViews.describeCanonical(bolded()).props.get("weight")) == 700);

		// --- Received ---
		check("the validator accepts a canonical Text", wui.nui.Canonical.translatedKeys("Text").indexOf("scale") >= 0);
		check("and the sink asks the control for its own name for it", wui.nui.Canonical.key("Text", "scale") == "font");

		// --- Generated ---
		var cpp:String = PickerVocabulary.runtime();
		check("a family is looked up in a table the build wrote", cpp.indexOf("g_fontFiles") > 0
			&& cpp.indexOf("void textFamily(") > 0);
		check("and one this application does not ship is asked for as it stands",
			cpp.indexOf("found == g_fontFiles.end() ? std::wstring(name.c_str()) : found->second") > 0);
		check("a weight crosses as a number, not as a flag",
			cpp.indexOf("winrt::Windows::UI::Text::FontWeight{ (uint16_t)") > 0);
		check("italic is a font style", cpp.indexOf("winrt::Windows::UI::Text::FontStyle::Italic") > 0);
		check("and tabular digits are the typography WinUI has for them",
			cpp.indexOf("Typography::SetNumeralAlignment") > 0 && cpp.indexOf("FontNumeralAlignment::Tabular") > 0);
		// The HELPER above is emitted unconditionally, so it says nothing about
		// whether anything calls it. That blind spot is how a real regression
		// got through: `numbers` typed as an abstract was not recognised as a
		// string, `eachProp` skipped the field in silence, and both dispatch
		// branches vanished from 3977 lines of C++ while every check here still
		// passed. The Farceur session found it by diffing the file.
		check("and something actually dispatches to it",
			cpp.indexOf("t == \"Text\" && k == \"numbers\"") > 0
			&& cpp.indexOf("t == \"TextBlock\" && k == \"numbers\"") > 0);

		Sys.println(failures == 0 ? "\nall checks passed" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}

	static function bolded():wui.View {
		var t = new wui.mui.Text("Sources");
		t.properties.set("bold", true);
		return t;
	}
}

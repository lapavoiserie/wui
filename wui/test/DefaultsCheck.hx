/**
	No default is emitted as a bare expression. Run with:

	    haxe -cp src -cp test -lib rui -lib nui -lib mui -lib kui -main DefaultsCheck --interp

	## The defect this exists for

	A clean clone could not build the Farceur pupitre:

	    WuiNodes.cpp(642,11): error C2039: 'FontItalic': is not a member of
	    'winrt::Microsoft::UI::Xaml::Controls::TextBlock'

	`wui.ui.Text` declares `italic = false`, so a default is emitted when the
	control is materialised. `nodeSetter` answers the bare member name for the
	keys a helper applies — which in the edited path means only "this key is
	handled", the statement itself coming from `reassertGuard`. The defaults
	loop read that marker as a call and wrote `c.FontItalic;`.

	One value meaning two things. The second meaning now has a name,
	`appliedByHelper`, and this reads the emitted C++ to say so.
**/
class DefaultsCheck {
	static var failures = 0;

	static function check(label:String, ok:Bool, ?got:Dynamic) {
		if (!ok) failures++;
		Sys.println((ok ? "ok   " : "FAIL ") + label + (ok || got == null ? "" : '  (got: $got)'));
	}

	static function main() {
		var runtime = SliderRangeVocabulary.runtime();
		check("the node runtime was generated", runtime.length > 0);

		// Every line of the create function is a statement. A bare `c.Member;`
		// is the shape MSVC refused, and the one to keep out.
		var bare = [];
		for (line in runtime.split("\n")) {
			var t = StringTools.trim(line);
			if (!StringTools.startsWith(t, "c.")) continue;
			// A call, an assignment or a chain is fine; `c.Name;` is not.
			var rest = t.substr(2);
			if (rest.indexOf("(") < 0 && rest.indexOf("=") < 0 && StringTools.endsWith(rest, ";"))
				bare.push(t);
		}
		check("no default is emitted as a bare member expression",
			bare.length == 0, bare.join(" | "));

		check("and FontItalic in particular is not", runtime.indexOf("c.FontItalic;") < 0);

		// It is skipped, not mis-spelled: the key is still handled when a tree
		// sets it, through the helper that knows how.
		check("italic still reaches the control when a tree sets it",
			runtime.indexOf("FontStyle") > 0);

		Sys.println(failures == 0 ? "\nall good" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}

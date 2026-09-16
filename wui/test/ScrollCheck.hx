import nui.Node;
import nui.PropValue;

/**
	A received tree taller than its window scrolls. Run with:

	    haxe -cp src -cp test -lib rui -lib nui -lib mui -lib kui -main ScrollCheck --interp

	Asked for by the Farceur session: its switcher, received over dui, was cut
	off at the bottom of the window. Three things were missing: the canonical
	name, a place for more than one child, and a root that gives a ScrollViewer
	a height to scroll within. Scrolling itself is proven on Windows, not here.
**/
class ScrollCheck {
	static var failures = 0;

	static function check(label:String, ok:Bool, ?got:Dynamic) {
		if (!ok) failures++;
		Sys.println((ok ? "ok   " : "FAIL ") + label + (ok || got == null ? "" : '  (got: $got)'));
	}

	static function main() {
		// --- Received ---
		check("a received ScrollView is a ScrollViewer",
			wui.nui.WinUISink.nativeTypeOf(new Node("ScrollView")) == "ScrollViewer");
		check("and the validator knows the canonical name", wui.nui.Canonical.isAlias("ScrollView"));

		// --- Built here ---
		var scroll = new wui.mui.ScrollView([new wui.ui.Text("a"), new wui.ui.Text("b")]);
		var sent = wui.mui.FromViews.describeCanonical(scroll);
		check("on the wire a ScrollView is the canonical name", sent.type == "ScrollView", sent.type);

		// --- Generated ---
		var cpp:String = PickerVocabulary.runtime();
		check("a ScrollViewer's children go into its column, at their index",
			cpp.indexOf("auto column = scrollColumn(scroll, true);") >= 0
			&& cpp.indexOf("column.Children().InsertAt(i, c);") >= 0);
		check("before the single-content fallback, where each child replaced the last",
			cpp.indexOf("p.try_as<winrt_controls::ScrollViewer>()") >= 0
			&& cpp.indexOf("p.try_as<winrt_controls::ScrollViewer>()") < cpp.indexOf("holder.Content(c)"));
		check("the column is made once, tagged, scrolling vertically only",
			cpp.indexOf("made.Tag(winrt::box_value(L\"scroll\"));") >= 0
			&& cpp.indexOf("ScrollBarVisibility::Auto") >= 0 && cpp.indexOf("ScrollBarVisibility::Disabled") >= 0);
		check("a removal leaves the column and takes only the child",
			cpp.indexOf("if (auto column = scrollColumn(scroll, false))") >= 0);
		check("a column root gives a ScrollViewer the rest of the height, and content its own",
			cpp.indexOf("row.Height(c.try_as<winrt_controls::ScrollViewer>() != nullptr") >= 0
			&& cpp.indexOf("grid.RowDefinitions().InsertAt(i, row);") >= 0);
		check("rows follow their children after an insert or a removal",
			cpp.indexOf("columnRenumber(grid, i);") >= 0 && cpp.indexOf("columnRenumber(grid, index);") >= 0);
		check("an auxiliary window's root is a column", cpp.indexOf("winrt_controls::Grid root;") >= 0
			&& cpp.indexOf("root.Tag(winrt::box_value(L\"column\"));") >= 0
			&& cpp.indexOf("winrt_controls::StackPanel root;") < 0);

		var main = sys.io.File.getContent("src/wui/macros/UIBuilder.hx");
		check("and so is the main window's", main.indexOf("winrt_controls::Grid root;") >= 0
			&& main.indexOf("winrt_controls::StackPanel root;") < 0);

		Sys.println(failures == 0 ? "\nall checks passed" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}

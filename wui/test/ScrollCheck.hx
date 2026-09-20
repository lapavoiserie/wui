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
		check("a column gives a ScrollViewer the rest of the height, and content its own",
			cpp.indexOf("bool share = c.try_as<winrt_controls::ScrollViewer>() != nullptr") >= 0
			&& cpp.indexOf("grid.RowDefinitions().InsertAt(i, row);") >= 0);

		// Only a surface's root is a column. Making every `VStack` one -- so a
		// nested ScrollView would scroll -- drew the Farceur pupitre entirely
		// black, laid out and unpainted, and was put back the same day.
		check("a VStack is still a vertical StackPanel",
			cpp.indexOf("if (t == \"VStack\") {\n        winrt_controls::StackPanel c;") >= 0);

		// Carried is not drawn: a `Spacer` reported `Border` and set a
		// property, so it existed on the transpiled path and nowhere else, and
		// an arriving `Spacer` -- `pui`'s own monitor fallback sends two -- was
		// drawn as the text `?Spacer`.
		check("and a received Spacer builds a tagged Border rather than ?Spacer",
			cpp.indexOf("if (t == \"Spacer\") {\n        winrt_controls::Border c;") >= 0);
		// --- the canon's `clip` ---
		//
		// WinUI has no property for it: a Grid and a StackPanel do not clip,
		// and every container in this backend is one. So it is a geometry on
		// `UIElement.Clip` -- and a geometry does NOT follow its element. One
		// set before layout stays 0x0 for good, which is why this is not a
		// one-liner and why the SizeChanged is the whole of it.
		check("a clip is a real geometry, sized to the element",
			cpp.indexOf("winrt::Microsoft::UI::Xaml::Media::RectangleGeometry geometry;") >= 0
			&& cpp.indexOf("(float)fe.ActualWidth(), (float)fe.ActualHeight()") >= 0);
		check("and it follows the element, instead of freezing at its first size",
			cpp.indexOf("g_clipTokens[h] = fe.SizeChanged(") >= 0
			&& cpp.indexOf("if (g_clipTokens.find(h) != g_clipTokens.end()) return;") >= 0);
		// An element owning a handler owning the element is a cycle WinRT has
		// no collector to break -- the same rule the window's Closed follows.
		check("the handler holds nothing: it takes its element from the sender",
			cpp.indexOf("auto e = sender.template try_as<winrt_xaml::FrameworkElement>();\n            if (e != nullptr) clipApply(e);") >= 0);
		// `wui_node_modifier` used to route three colours and report the rest
		// to the debugger. This one is not a property under another name.
		check("and the chain reaches it rather than reporting it ignored",
			cpp.indexOf("if (kind == \"clip\") {") >= 0
			&& cpp.indexOf("if (kind == \"clip\") {") < cpp.indexOf("[wui] modifier ignored"));

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

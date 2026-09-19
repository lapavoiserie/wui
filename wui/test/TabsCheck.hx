import nui.Node;
import nui.PropValue;

/**
	The canon's tabs on wui, the three ways they reach the screen. Run with:

	    haxe -cp src -cp test -lib rui -lib nui -lib mui -lib kui -main TabsCheck --interp

	- **Translated**: `Tabs` is a `TabView`, `Tab` a `TabViewItem`, and a tab's
	  `label` is a `Header`. Without that a canonical tree was refused at
	  compile time while the sink would have built it — the defect
	  `wui.nui.Canonical` exists for.
	- **Declared**: the selection is a member named for this control, because
	  the one WinUI calls `SelectedIndex` is spoken for by the ComboBox.
	- **Generated**: an index this runtime applies is not reported back as a
	  choice, a tab arriving late can still be the selected one, and a glyph
	  becomes an IconSource.

	The tabs themselves are proven on Windows, not here.
**/
class TabsCheck {
	static var failures = 0;

	static function check(label:String, ok:Bool, ?got:Dynamic) {
		if (!ok) failures++;
		Sys.println((ok ? "ok   " : "FAIL ") + label + (ok || got == null ? "" : '  (got: $got)'));
	}

	static function main() {
		// --- Translated at the door ---
		var tabs = new Node("Tabs").prop("selectedIndex", PInt(1));
		var tab = new Node("Tab").prop("label", PString("Transitions"));
		check("a received Tabs becomes a TabView", wui.nui.WinUISink.nativeTypeOf(tabs) == "TabView",
			wui.nui.WinUISink.nativeTypeOf(tabs));
		check("and a Tab a TabViewItem", wui.nui.WinUISink.nativeTypeOf(tab) == "TabViewItem",
			wui.nui.WinUISink.nativeTypeOf(tab));
		check("the sink knows both canonical names",
			wui.nui.WinUISink.knows("Tabs") && wui.nui.WinUISink.knows("Tab"));
		check("the validator knows them too",
			wui.nui.Canonical.isAlias("Tabs") && wui.nui.Canonical.isAlias("Tab"));
		check("a tab's label is its header", wui.nui.Canonical.key("Tab", "label") == "header",
			wui.nui.Canonical.key("Tab", "label"));
		check("and its icon is a key the control does not declare under that name",
			wui.nui.Canonical.translatedKeys("Tab").indexOf("icon") >= 0);

		// --- Declared ---
		var v:String = TabsVocabulary.props();
		check("TabView is a control the factory builds", v.indexOf("TabView?true") >= 0, v);
		// Not `SelectedIndex`: that member's generated setter is the ComboBox's,
		// and it takes a ComboBox. A TabView passed to it would not compile.
		check("its selection is a member named for it, not the ComboBox's",
			v.indexOf("TabView:selectedIndex=TabSelectedIndex") >= 0, v);
		check("a TabViewItem carries a header and a glyph",
			v.indexOf("TabViewItem:header=Header") >= 0
			&& v.indexOf("TabViewItem:icon=TabIconGlyph") >= 0, v);

		// --- Generated ---
		var cpp:String = PickerVocabulary.runtime();
		check("a TabView is created with WinUI's add-tab button off",
			cpp.indexOf("winrt_controls::TabView c;\n        c.IsAddTabButtonVisible(false);") >= 0);
		check("and a tab is not closable: the tabs are the tree",
			cpp.indexOf("winrt_controls::TabViewItem c;\n        c.IsClosable(false);") >= 0);
		check("selecting goes through tabSelect, which remembers what was wanted",
			cpp.indexOf("tabSelect(c, h, value);") >= 0
			&& cpp.indexOf("void tabSelect(winrt_controls::TabView const& c, int h, int want)") >= 0);
		// The defect the ComboBox found on a Windows screen: applying a received
		// index reported onSelect back, so a tree overwrote the person's choice.
		check("an index this runtime applies is not reported as a choice",
			cpp.indexOf("if (tabProgrammatic(h, index)) return;") >= 0);
		check("a tab arriving after the selection can still be the selected one",
			cpp.indexOf("tabApply(tabs, parent);") >= 0);
		check("a glyph becomes an IconSource, and an empty one no icon at all",
			cpp.indexOf("void tabIcon(winrt_controls::TabViewItem const& c") >= 0
			&& cpp.indexOf("if (glyph.empty()) { c.IconSource(nullptr); return; }") >= 0);

		Sys.println(failures == 0 ? "\nall checks passed" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}

import nui.Node;
import nui.PropValue;

/**
	A picker on wui, both ways a tree reaches the node runtime. Run with:

	    haxe -cp src -cp test -lib rui -lib nui -lib mui -lib kui -main PickerCheck --interp

	- **Built here**: `mui.ui.Picker` is a `ComboBox` of `ComboBoxItem`s, and a
	  bound cell describes as `selectedIndex` plus an `onSelect` that writes it.
	- **Received**: a canonical `Picker` with `Text` children becomes a
	  `ComboBox`, each `Text` under it a `ComboBoxItem`; a choice comes home as
	  the string an inflated action takes.
	- **Generated**: the C++ applies an index only when the option exists and
	  the list is closed, inserts options in `Items`, and reports a position.

	The control itself is proven on Windows, not here.
**/
class PickerCheck {
	static var failures = 0;

	static function check(label:String, ok:Bool, ?got:Dynamic) {
		if (!ok) failures++;
		Sys.println((ok ? "ok   " : "FAIL ") + label + (ok || got == null ? "" : '  (got: $got)'));
	}

	static function main() {
		// --- Built here ---
		var transition = new wui.state.State(1, "transition");
		var picker = new wui.mui.Picker("Transition", ["Cut", "Fade", "Wipe"], transition);
		check("a Picker is a ComboBox", picker.viewType == "ComboBox", picker.viewType);
		check("its options are ComboBoxItem children, in order", picker.children.length == 3
			&& picker.children[2].viewType == "ComboBoxItem" && picker.children[2].properties.get("text") == "Wipe");
		check("its label is the header", picker.properties.get("label") == "Transition");

		var described = wui.mui.FromViews.describe(picker);
		check("described, the bound cell is the selected index, as an Int",
			described.props.get("selectedIndex") != null && Type.enumEq(described.props.get("selectedIndex"), PInt(1)));
		switch (described.props.get("onSelect")) {
			case PCallbackInt(fn):
				fn(2);
				check("and choosing writes the position into the cell", transition.get() == 2);
			case other:
				check("onSelect is an Int callback", false, other);
		}
		check("the option nodes carry their text", described.children.length == 3
			&& Type.enumEq(described.children[0].props.get("text"), PString("Cut")));

		var canonical = wui.mui.FromViews.describeCanonical(new wui.mui.Picker("", ["A", "B"], new wui.state.State(0, "choice")));
		check("on the wire it is a canonical Picker of Text options", canonical.type == "Picker"
			&& canonical.children.length == 2 && canonical.children[1].type == "Text");
		check("an empty label is no header at all", !canonical.props.exists("label"));

		// --- Received ---
		var received = new Node("Picker").prop("selectedIndex", PInt(0));
		var option = new Node("Text").prop("text", PString("Cut"));
		check("a received Picker becomes a ComboBox", wui.nui.WinUISink.nativeTypeOf(received) == "ComboBox");
		check("a Text under a ComboBox is a ComboBoxItem", wui.nui.WinUISink.nativeTypeIn(option, "ComboBox") == "ComboBoxItem");
		check("and a Text anywhere else stays a text", wui.nui.WinUISink.nativeTypeIn(option, "StackPanel") == "Text"
			&& wui.nui.WinUISink.nativeTypeIn(option, null) == "Text");
		check("the sink knows the canonical name", wui.nui.WinUISink.knows("Picker"));
		check("its value and change keys are the index and onSelect",
			wui.nui.Bindings.valueKey("ComboBox") == "selectedIndex" && wui.nui.Bindings.changeKey("ComboBox") == "onSelect");

		// --- Declared ---
		var v:String = PickerVocabulary.props();
		check("ComboBox is a control the factory builds, with Header and SelectedIndex",
			v.indexOf("ComboBox?true") >= 0 && v.indexOf("ComboBox:label=Header") >= 0 && v.indexOf("ComboBox:selectedIndex=SelectedIndex") >= 0, v);
		check("ComboBoxItem carries its text as Content", v.indexOf("ComboBoxItem:text=Content") >= 0, v);
		check("NavigationView's index is its own lookup, not ComboBox's member",
			v.indexOf("NavigationView:selectedIndex=SelectedMenuIndex") >= 0, v);

		// --- Generated ---
		var cpp:String = PickerVocabulary.runtime();
		check("the setter keeps the wanted index", cpp.indexOf("comboSelect(c, h, value);") >= 0);
		check("it is applied only when the option exists and the list is closed",
			cpp.indexOf("c.IsDropDownOpen()") >= 0 && cpp.indexOf("want >= (int)c.Items().Size()") >= 0);
		check("and again when the list closes", cpp.indexOf("c.DropDownClosed(") >= 0);
		check("options are inserted in Items, retrying the index",
			cpp.indexOf("combo.Items().InsertAt(i, item);") >= 0 && cpp.indexOf("comboApply(combo, parent);") >= 0);
		check("and removed from it", cpp.indexOf("combo.Items().RemoveAt(index);") >= 0);
		check("a choice reports its position, never -1",
			cpp.indexOf("int index = b.SelectedIndex();") >= 0 && cpp.indexOf("if (index >= 0) wui_bridge_invoke_node_int(callbackId, index);") >= 0);
		check("NavigationView still selects through its menu items", cpp.indexOf("c.MenuItems().IndexOf(c.SelectedItem(), cur)") >= 0);

		Sys.println(failures == 0 ? "\nall checks passed" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}

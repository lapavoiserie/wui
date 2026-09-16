package wui.ui;

import wui.View;

/**
	A drop-down list: one choice among several. `mui.ui.Picker` on wui.

	```haxe
	new ComboBox(["Cut", "Fade", "Wipe"], transition_, "Transition")
	```

	The options are **children**, one `ComboBoxItem` each — the canonical
	`Picker` carries them as `Text` children, and `WinUISink` builds a
	`ComboBoxItem` for a `Text` placed in a `ComboBox`. A child rather than an
	`options` array: a node that is data about its children is still a tree, and
	an option can become more than a word later without a second encoding.

	## Selection is an index

	`selectedIndex` is the position of the chosen option, `-1` for none, and
	`onSelect` reports a position. The node runtime applies an index only when
	that option exists — WinUI refuses one past the end — and **not while the
	list is open**: a tree arriving from elsewhere must not move the highlight
	under the user's pointer. What arrived meanwhile is applied when the list
	closes.

	Bound to a cell (`binding`), both halves are described by
	`wui.mui.FromViews`: the cell's value as `selectedIndex`, and an `onSelect`
	that writes it back.
**/
@:winuiType("ComboBox")
@:build(wui.macros.ControlBuilder.build())
class ComboBox extends Control {
	@:winrt("Header") public var label:Null<String>;
	@:winrt("SelectedIndex") public var selectedIndex:Null<Int>;

	public function new(options:Array<String>, ?binding:Dynamic, ?label:String) {
		super("ComboBox", [for (option in options) new ComboBoxItem(option)]);
		if (label != null && label != "") this.label = label;
		if (binding != null) properties.set("binding", binding);
	}
}

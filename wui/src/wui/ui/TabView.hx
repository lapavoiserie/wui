package wui.ui;

import wui.View;

/**
	A tabbed interface. Maps to WinUI TabView.

	```haxe
	new TabView([
	    { label: "Tab 1", content: view1 },
	    { label: "Tab 2", content: view2 }
	])
	```

	## The canon's `Tabs` is this

	`nui` says `Tabs` carries `selectedIndex` and `onSelect`, its children are
	`Tab`s, and **only the selected tab carries its page**. WinUI holds a page
	per item, so an unselected tab is simply an item with no content -- which is
	what the canon's structural guarantee amounts to here: a `SecretInput` in a
	tab nobody chose is not in the tree, so there is nothing on this side to
	redact or forget to redact.

	One frame of it is visible and worth saying: tapping a tab reports the index
	and the application answers with a tree in which that tab has the page. Until
	that tree arrives the newly selected tab is empty, because the page was never
	sent.
**/
@:winuiType("TabView")
@:build(wui.macros.ControlBuilder.build())
class TabView extends Control {
	/**
		Which tab is open.

		A WinUI TabView has a real `SelectedIndex`, but the generated setter for
		a member of that name belongs to `ComboBox` -- it goes through
		`comboSelect`, which takes a ComboBox and would not compile with this.
		So the member is named for this control and the generator has its own
		branch, the way `SelectorBar`'s `SelectedItemIndex` does.

		It guards the same trap `ComboBox` found on a Windows screen: an index
		this runtime applies must not be reported back as a choice the person
		made, or a received tree sends `onSelect` at every attach.
	**/
	@:winrt("TabSelectedIndex") public var selectedIndex:Null<Int>;

	/**
		Whether WinUI offers its "+" button. Off unless an application says so.

		A pushed tree has no way to answer a new tab -- the tabs are the tree --
		so a "+" that adds one would produce a tab the sender does not know
		about, and the next tree would take it away again.
	**/
	@:winrt("IsAddTabButtonVisible") @:defaultValue(false) public var canAddTabs:Null<Bool>;

	public function new(tabs:Array<TabItem>) {
		// WinUI holds items, not contents. The tabs become children here so a
		// host that inserts children generically -- the push sink does -- builds
		// the same thing the transpiled path builds from the `tabs` property,
		// which is kept for it.
		super("TabView", [for (t in tabs) new TabViewItem(t.label, t.content, t.icon)]);
		properties.set("tabs", tabs);
	}
}

typedef TabItem = {
	label:String,
	?icon:String,
	content:View
};

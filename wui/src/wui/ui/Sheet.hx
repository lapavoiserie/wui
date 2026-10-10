package wui.ui;

import wui.View;

/**
	The canon's `Sheet`: a task over the window, in a `ContentDialog`.

	Drawn nowhere where it stands -- `wui_node_insert` leaves an empty spot,
	as for a `Notice` -- and shown while `presented`, its children in the
	dialog's content, one under the other. No buttons of its own: the
	application puts its acts in the content, and Escape is the way out,
	reported to `onPresented` (canonical, `Canonical.canonKeys`).

	One dialog at a time: WinUI shows one ContentDialog per window, so a
	second waits until the first has closed. See `dialogPump`.
**/
@:winuiType("ContentDialog")
@:noWinuiAlias
@:build(wui.macros.ControlBuilder.build())
class Sheet extends Control {
	@:winrt("DialogPresented") public var presented:Bool = false;
	@:winrt("DialogTitle") public var title:Null<String>;

	public function new(?title:String, ?content:Array<View>) {
		super("Sheet", content);
		if (title != null) this.title = title;
	}
}

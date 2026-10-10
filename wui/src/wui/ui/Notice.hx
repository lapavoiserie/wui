package wui.ui;

import wui.View;

/**
	The canon's `Notice`: a word about what just happened, in an `InfoBar`.

	Drawn nowhere where it stands. `wui_node_insert` leaves an empty spot in
	its place, so its siblings keep their indices, and shows the InfoBar over
	the head of the page: across the content the notice is in, inset from a
	navigation pane rather than over it. One per screen is what the canon
	expects; two would sit on each other.

	`kind` is the severity -- `success`, `info`, `warning`, `error` -- and a
	`success` or `info` notice closes itself after a few seconds. Closed by the
	person, by its act or by its timer, it reports `false` to `onPresented`
	(a canonical key, `Canonical.canonKeys`, so it takes a `Bool`).
	`dismissLabel` names the close button for UI Automation.
**/
@:winuiType("InfoBar")
@:build(wui.macros.ControlBuilder.build())
class Notice extends Control {
	@:winrt("NoticePresented") public var presented:Bool = false;
	@:winrt("Message") public var message:String;
	@:winrt("NoticeKind") public var kind:Null<String>;
	@:winrt("NoticeAction") public var actionLabel:Null<String>;
	@:winrt("NoticeDismiss") public var dismissLabel:String;

	/** Its act. Doing it closes the notice. **/
	@:winrt("NoticeOnAction") public var onAction:Null<Void->Void>;

	public function new(message:String, dismissLabel:String) {
		super("Notice");
		this.message = message;
		this.dismissLabel = dismissLabel;
	}
}

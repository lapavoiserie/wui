package wui.ui;

import wui.View;

/**
	The canon's `ConfirmDialog`: a question with one act and a way out, in a
	`ContentDialog`.

	`confirmLabel` is the primary button, `cancelLabel` the close button --
	both the application's words. Answering either way closes it and reports
	`false` to `onPresented`; `onConfirm` runs for the act only, before.
	`destructive` makes the way out the default button, so Enter does not
	destroy: WinUI has no destroying style for a dialog's button, and the
	words still say what it does.

	Drawn nowhere where it stands and queued behind any other dialog, as a
	`Sheet` is.
**/
@:winuiType("ContentDialog")
@:noWinuiAlias
@:build(wui.macros.ControlBuilder.build())
class ConfirmDialog extends Control {
	@:winrt("DialogPresented") public var presented:Bool = false;
	@:winrt("DialogTitle") public var title:String;
	@:winrt("DialogMessage") public var message:Null<String>;
	@:winrt("PrimaryButtonText") public var confirmLabel:String;
	@:winrt("CloseButtonText") public var cancelLabel:String;
	@:winrt("DialogDestructive") public var destructive:Null<Bool>;

	/** The act. **/
	@:winrt("DialogOnConfirm") public var onConfirm:Null<Void->Void>;

	public function new(title:String, confirmLabel:String, cancelLabel:String) {
		super("ConfirmDialog");
		this.title = title;
		this.confirmLabel = confirmLabel;
		this.cancelLabel = cancelLabel;
	}
}

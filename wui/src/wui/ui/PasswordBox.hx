package wui.ui;

import wui.View;

/**
	A value that is typed in and never enters the tree: `nui`'s `SecretInput`.

	A stream key, a token, a password. The canon states the type and what a
	renderer owes it — masked, no clipboard, cleared after submitting, nothing
	reported per keystroke — and `PasswordBox` gives three of those for free.

	## What is NOT declared here, and why that is the design

	There is no `@:winrt` var for the value. `wui.nui.Vocabulary` reads this
	class to decide what a node of this type may carry, so a tree cannot set a
	password **because there is no property to set**: the guarantee is the
	declaration, not a rule somebody has to remember when writing a sink.

	`Password` is written once, by the runtime, to clear it after submitting.

	## Reveal is off, and it is a declared default

	WinUI's default `PasswordRevealMode` is `Peek`: a button appears in the box
	while it has focus and content, and holding it shows the value in clear.
	That is exactly what a secret typed in front of a screen capture must not
	offer — the one thing the canon's "masked" would otherwise not cover — so
	`Hidden` is declared here rather than left to whoever places the control.
**/
@:winuiType("PasswordBox")
@:build(wui.macros.ControlBuilder.build())
class PasswordBox extends Control {
	@:winrt("PlaceholderText")
	public var placeholder:Null<String>;

	/** `Hidden`, and not the platform's `Peek`. See the class doc. **/
	@:winrt("PasswordRevealMode")
	public var revealMode:String = "hidden";

	public function new(?placeholder:String) {
		super("PasswordBox");
		if (placeholder != null) this.placeholder = placeholder;
	}
}

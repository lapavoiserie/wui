package wui.ui;

import wui.View;

/**
	Read-only text.

	## One declaration

	The fields below are the only place this control's properties are named.
	`Vocabulary` reads them at compile time, the generated C++ node runtime is
	emitted from them, and `@:winrt` says which WinRT call applies each one —
	the one thing a Haxe type cannot express (`Text` does not follow from
	`text`).

	## Two names, on purpose and for now

	The class name is the **nui** type; `@:winuiType` gives the **transpiled
	path's**, which is WinUI's own (`TextBlock`). The two rendering paths grew
	separate vocabularies, and rather than pretend otherwise the divergence is
	stated here, in one place, until the transpiled path is retired or aligned.
**/
@:winuiType("TextBlock")
@:build(wui.macros.ControlBuilder.build())
class Text extends View {
	@:winrt("Text")
	public var text:String;

	// TextBlock is a FrameworkElement, not a Control: these are its own members,
	// which is why they are declared here rather than on a shared base.
	@:winrt("Padding") public var padding:Null<Float>;
	@:winrt("Foreground") public var foregroundColor:Null<String>;
	@:winrt("FontSize") public var fontSize:Null<Float>;

	// A typographic step, not a XAML Style. It used to map to `Style`, which the
	// emitter could not produce, so `font = "Title"` compiled, validated, and did
	// nothing -- the whole scale silently lost. It becomes a real FontSize now.
	@:winrt("FontScale") public var font:Null<String>;

	@:winrt("FontWeight") public var bold:Bool = false;

	/**
		What the canon lets a text say beyond its scale (`nui.TextStyle`): a
		family the application ships, a weight of 100 to 900, italic, and digits
		of one width.

		A family is a **name**, and WinUI wants a file for one that is not
		installed. The node runtime holds the table that turns one into the
		other, written by the build from what it can read -- see
		`BridgeGenerator`.
	**/
	@:winrt("FontFamilyName") public var family:Null<String>;

	@:winrt("FontWeightValue") public var weight:Null<Int>;

	@:winrt("FontItalic") public var italic:Bool = false;

	@:winrt("Numerals") public var numbers:Null<nui.Numbers>;

	public function new(content:Dynamic) {
		super("TextBlock");
		this.text = Std.string(content);
	}
}

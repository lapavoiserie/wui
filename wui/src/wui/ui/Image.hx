package wui.ui;

import wui.View;

/**
	A picture: `mui.ui.Image` on wui.

	```haxe
	new Image("asset:logo.png", "Farceur", {width: 120})
	```

	`src` names where the picture lives, by scheme (`nui.ImageSource`): `https:`,
	`file:`, `asset:` (the `assets` directory beside the executable), `data:`
	(PNG or JPEG). `alt` is drawn in the picture's place when it cannot be:
	refused, not found, not a PNG or a JPEG, failed to load.

	The node runtime builds a `Grid` holding a WinUI `Image` and a `TextBlock`
	for the alt, and shows one of the two. `width` and `height` size the grid;
	with one of them the picture keeps its ratio. `fit` is `contain`, `cover` or
	`fill`.

	The first argument is still what the transpiled path reads as `source`.
**/
@:winuiType("Grid")
@:build(wui.macros.ControlBuilder.build())
class Image extends View {
	@:winrt("ImageSource") public var src:Null<String>;
	@:winrt("ImageAlt") public var alt:Null<String>;
	@:winrt("ImageFit") public var fit:Null<String>;

	public function new(src:String, ?alt:String, ?options:{?width:Float, ?height:Float, ?fit:String}) {
		super("Image");
		properties.set("source", src);
		this.src = src;
		this.alt = alt == null ? "" : alt;
		if (options != null) {
			if (options.width != null) this.width = options.width;
			if (options.height != null) this.height = options.height;
			if (options.fit != null) this.fit = options.fit;
		}
	}
}

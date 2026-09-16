package wui.mui;

/**
	`wui`'s conformance for `mui.ui.Image`: the canonical picture, `src` and
	`alt`. See `wui.ui.Image`.
**/
class Image extends wui.ui.Image {
	public function new(src:String, alt:String, ?options:mui.ui.ImageOptions) {
		super(src, alt, options == null ? null : {
			width: options.width,
			height: options.height,
			fit: options.fit == null ? null : (options.fit : String)
		});
	}
}

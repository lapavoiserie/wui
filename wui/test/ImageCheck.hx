import nui.Node;
import nui.PropValue;

/**
	Pictures and icons on wui, both ways a tree reaches the node runtime. Run with:

	    haxe -cp src -cp test -lib rui -lib nui -lib mui -lib kui -main ImageCheck --interp

	The controls themselves are proven on Windows, not here.
**/
class ImageCheck {
	static var failures = 0;

	static function check(label:String, ok:Bool, ?got:Dynamic) {
		if (!ok) failures++;
		Sys.println((ok ? "ok   " : "FAIL ") + label + (ok || got == null ? "" : '  (got: $got)'));
	}

	static function main() {
		// --- The vocabulary's glyphs ---
		var missing = [for (name in nui.Icons.NAMES) if (wui.nui.Icons.glyphOf(name) == null) name];
		check("every name of the shared vocabulary has a glyph", missing.length == 0, missing);
		check("and nothing else does", Lambda.count(wui.nui.Icons.GLYPHS) == nui.Icons.NAMES.length);

		// --- Built here ---
		var image = new wui.mui.Image("asset:logo.png", "Farceur", {width: 120, fit: Cover});
		check("an Image carries src, alt, width and fit", image.viewType == "Image"
			&& image.properties.get("src") == "asset:logo.png" && image.properties.get("alt") == "Farceur"
			&& image.properties.get("width") == 120 && image.properties.get("fit") == "cover");
		var icon = new wui.mui.Icon(MicOff, "Muted");
		check("an Icon carries its glyph, looked up here", icon.properties.get("glyph") == String.fromCharCode(0xEC54));

		var panel = new wui.ui.VStack([image, icon]);
		var canonical = wui.mui.FromViews.describeCanonical(panel);
		var sentImage = canonical.children[0];
		check("on the wire an Image is src and alt, without the transpiled path's copy", sentImage.type == "Image"
			&& Type.enumEq(sentImage.props.get("src"), PString("asset:logo.png"))
			&& Type.enumEq(sentImage.props.get("alt"), PString("Farceur"))
			&& !sentImage.props.exists("source"));
		var sentIcon = canonical.children[1];
		check("and an Icon is its name and label, not the glyph", sentIcon.type == "Icon"
			&& Type.enumEq(sentIcon.props.get("name"), PString("mic-off"))
			&& Type.enumEq(sentIcon.props.get("label"), PString("Muted"))
			&& !sentIcon.props.exists("glyph"));

		// --- Received ---
		check("a received Icon with a known name is a glyph control",
			wui.nui.WinUISink.nativeTypeIn(new Node("Icon").prop("name", PString("mic")), null) == "Icon");
		check("one with a name wui has no glyph for is its label, as text",
			wui.nui.WinUISink.nativeTypeIn(new Node("Icon").prop("name", PString("cut")), null) == "Text");
		check("a received Image is the Image control", wui.nui.WinUISink.nativeTypeOf(new Node("Image")) == "Image");

		// --- Declared ---
		var v:String = ImageVocabulary.props();
		check("Image is built on a Grid, with src, alt and fit applied by the runtime",
			v.indexOf("Image>Grid") >= 0 && v.indexOf("Image:src=ImageSource") >= 0
			&& v.indexOf("Image:alt=ImageAlt") >= 0 && v.indexOf("Image:fit=ImageFit") >= 0 && v.indexOf("Image:width=Width") >= 0, v);
		check("Icon is a FontIcon with a glyph, in Segoe Fluent Icons by default",
			v.indexOf("Icon>FontIcon") >= 0 && v.indexOf("Icon:glyph=Glyph") >= 0
			&& v.indexOf("Icon:default:FontFamily=Segoe Fluent Icons, Segoe MDL2 Assets") >= 0, v);

		// --- Generated ---
		var cpp:String = PickerVocabulary.runtime();
		check("the three Image keys reach their helpers", cpp.indexOf("imageSource(c, h, text);") >= 0
			&& cpp.indexOf("imageAlt(c, h, text);") >= 0 && cpp.indexOf("imageFit(c, h, std::string(value));") >= 0);
		check("an opened picture shows, a failed one shows the alt",
			cpp.indexOf("p.image.ImageOpened(") >= 0 && cpp.indexOf("p.image.ImageFailed(") >= 0);
		check("https: and file: load by URI, asset: from the assets beside the executable",
			cpp.indexOf("startsWith(src, L\"https://\") || startsWith(src, L\"file:///\")") >= 0
			&& cpp.indexOf("exeDirectory() + L\"\\\\assets\\\\\" + path") >= 0);
		check("a data: picture is PNG or JPEG by its own bytes before it is used",
			cpp.indexOf("!decodeBase64(src.substr(comma + 1), bytes) || !pngOrJpeg(bytes)") >= 0);
		check("anything else -- refused:, blob:, unknown -- shows the alt",
			cpp.indexOf("if (uri.empty()) { p.image.Source(nullptr); imageShow(p, false); return; }") >= 0);
		check("cover and fill are the matching stretches", cpp.indexOf("media::Stretch::UniformToFill") >= 0
			&& cpp.indexOf("media::Stretch::Fill") >= 0);
		check("an icon's family is a FontFamily object",
			cpp.indexOf("c.FontFamily(winrt::Microsoft::UI::Xaml::Media::FontFamily(") >= 0);

		Sys.println(failures == 0 ? "\nall checks passed" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}

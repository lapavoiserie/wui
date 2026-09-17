/**
	The generated node runtime, as text, for the slider-range check. Its own
	class for the reason `PickerVocabulary` gives: a macro beside `@:build`
	views is refused.
**/
class SliderRangeVocabulary {
	/** The generated `WuiNodes.cpp`, as text. **/
	public static macro function runtime():haxe.macro.Expr {
		// Outside the repository: the generator writes a whole file, and a test
		// has no business leaving one in the working tree.
		var tmp = Sys.getEnv("TMPDIR");
		var dir = (tmp == null || tmp == "" ? "/tmp" : tmp) + "/wui-slider-runtime";
		if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
		@:privateAccess wui.macros.BridgeGenerator.generateNodeRuntime(dir);
		var text = "";
		for (file in sys.FileSystem.readDirectory(dir))
			if (StringTools.endsWith(file, ".cpp")) text += sys.io.File.getContent(dir + "/" + file);
		return macro $v{text};
	}
}

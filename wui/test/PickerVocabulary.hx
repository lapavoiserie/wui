/**
	What `wui.nui.Vocabulary` and the generated node runtime say about the
	picker, computed while compiling. Its own class for the reason
	`ProgressVocabulary` gives: a macro beside `@:build` views is refused.
**/
class PickerVocabulary {
	/** Declared props of the two controls, as `type:name=winrt` pairs. **/
	public static macro function props():haxe.macro.Expr {
		var out = [];
		for (type in ["ComboBox", "ComboBoxItem", "NavigationView"]) {
			out.push(type + "?" + wui.nui.Vocabulary.knows(type));
			for (p in wui.nui.Vocabulary.propsFor(type))
				out.push(type + ":" + p.name + "=" + p.winrt);
		}
		return macro $v{out.join(",")};
	}

	/** The generated `WuiNodes.cpp`, as text. **/
	public static macro function runtime():haxe.macro.Expr {
		// Outside the repository: the generator writes a whole file, and a test
		// has no business leaving one in the working tree.
		var tmp = Sys.getEnv("TMPDIR");
		var dir = (tmp == null || tmp == "" ? "/tmp" : tmp) + "/wui-picker-runtime";
		if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
		@:privateAccess wui.macros.BridgeGenerator.generateNodeRuntime(dir);
		var text = "";
		for (file in sys.FileSystem.readDirectory(dir))
			if (StringTools.endsWith(file, ".cpp")) text += sys.io.File.getContent(dir + "/" + file);
		return macro $v{text};
	}
}

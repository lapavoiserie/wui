/**
	What `wui.nui.Vocabulary` and the generated node runtime say about the
	secret field, computed while compiling. Its own class for the reason
	`PickerVocabulary` gives: a macro beside `@:build` views is refused.
**/
class SecretVocabulary {
	/** Declared props of `PasswordBox`, as `name=winrt` pairs. **/
	public static macro function props():haxe.macro.Expr {
		var out = [];
		for (p in wui.nui.Vocabulary.propsFor("PasswordBox"))
			out.push(p.name + "=" + p.winrt);
		return macro $v{out.join(",")};
	}

	/** The generated `WuiNodes.cpp`, as text. **/
	public static macro function runtime():haxe.macro.Expr {
		var tmp = Sys.getEnv("TMPDIR");
		var dir = (tmp == null || tmp == "" ? "/tmp" : tmp) + "/wui-secret-runtime";
		if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
		@:privateAccess wui.macros.BridgeGenerator.generateNodeRuntime(dir);
		var text = "";
		for (file in sys.FileSystem.readDirectory(dir))
			if (StringTools.endsWith(file, ".cpp")) text += sys.io.File.getContent(dir + "/" + file);
		return macro $v{text};
	}
}

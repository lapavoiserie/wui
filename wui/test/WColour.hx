class WColour {
	public static macro function runtimeHeader():haxe.macro.Expr {
		var dir = (Sys.getEnv("TMPDIR") == null ? "/tmp" : Sys.getEnv("TMPDIR")) + "/wui-colour";
		if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
		@:privateAccess wui.macros.BridgeGenerator.generateRuntime(dir);
		var text = "";
		for (f in sys.FileSystem.readDirectory(dir)) text += sys.io.File.getContent(dir + "/" + f);
		return macro $v{text};
	}

	static var failures = 0;
	static function check(what:String, ok:Bool):Void {
		Sys.println((ok ? "ok   " : "FAIL ") + what);
		if (!ok) failures++;
	}

	static function main() {
		var header:String = runtimeHeader();
		var nodes:String = PickerVocabulary.runtime();

		check("the role resolver is emitted", header.indexOf("brushFromRole") > 0);
		check("and reads the accent from the system", header.indexOf("UIColorType::Accent") > 0);
		// A real newline inside a C++ literal is C2001, and MSVC stops there.
		check("its trace escapes its newline", header.indexOf("role + \"\\n\"") > 0);
		check("and no literal contains a real newline",
			~/"\[wui\][^"\n]*$/m.match(header) == false);

		// The chain reached nothing at all: a TAKE carrying role:accent stayed grey.
		check("a colour modifier is routed to the property that draws it",
			nodes.indexOf("kind == \"backgroundColor\"") > 0
			&& nodes.indexOf("wui_node_prop_string(h, type, \"background\", s0)") > 0);
		check("and so are the foreground and the border",
			nodes.indexOf("\"foregroundColor\", s0") > 0 && nodes.indexOf("\"borderBrush\", s0") > 0);

		Sys.println(failures == 0 ? "\nall checks passed" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}

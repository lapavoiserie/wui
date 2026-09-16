/**
	The generated `.vcxproj`, with and without an application's `assets/`,
	computed while compiling -- `wui.macros.ProjectGenerator` runs at macro time
	and nowhere else. Its own class, for the reason `ProgressVocabulary` gives.
**/
class AssetsProbe {
	public static macro function project(shipping:Bool):haxe.macro.Expr {
		var tmp = Sys.getEnv("TMPDIR");
		if (tmp == null || tmp == "") tmp = "/tmp";
		var work = tmp + "/wui-assets-probe-" + (shipping ? "shipping" : "bare");
		remove(work);
		sys.FileSystem.createDirectory(work);
		if (shipping) {
			sys.FileSystem.createDirectory(work + "/assets");
			sys.io.File.saveContent(work + "/assets/logo.png", "not really a picture");
		}
		var was = Sys.getCwd();
		Sys.setCwd(work);
		wui.macros.ProjectGenerator.generate("Panel", "build/winui");
		var text = sys.io.File.getContent("build/winui/Panel.vcxproj");
		Sys.setCwd(was);
		remove(work);
		return macro $v{text};
	}

	#if macro
	static function remove(path:String) {
		if (!sys.FileSystem.exists(path)) return;
		if (!sys.FileSystem.isDirectory(path)) {
			sys.FileSystem.deleteFile(path);
			return;
		}
		for (entry in sys.FileSystem.readDirectory(path)) remove(path + "/" + entry);
		sys.FileSystem.deleteDirectory(path);
	}
	#end
}

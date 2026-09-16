/**
	What an application ships reaches the build. Run with:

	    haxe -cp src -cp test -lib rui -lib nui -lib mui -lib kui -main AssetsCheck --interp

	The copy itself is MSBuild's, and proven on Windows; what is checked here is
	that the project asks for it, and only when there is something to copy.
**/
class AssetsCheck {
	static var failures = 0;

	static function check(label:String, ok:Bool, ?got:Dynamic) {
		if (!ok) failures++;
		Sys.println((ok ? "ok   " : "FAIL ") + label + (ok || got == null ? "" : '  (got: $got)'));
	}

	static function main() {
		var bare:String = AssetsProbe.project(false);
		check("with no assets directory the project asks for no copy", bare.indexOf("<Content Include=") < 0);

		var shipping:String = AssetsProbe.project(true);
		check("with one, the whole directory is content", shipping.indexOf("assets\\**\\*") > 0);
		check("copied beside the executable, under assets",
			shipping.indexOf("<Link>assets\\%(RecursiveDir)%(Filename)%(Extension)</Link>") > 0);
		check("and only when it changed", shipping.indexOf("<CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>") > 0);
		check("which is where the runtime looks it up",
			PickerVocabulary.runtime().indexOf("exeDirectory() + L\"\\\\assets\\\\\" + path") > 0);

		Sys.println(failures == 0 ? "\nall checks passed" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}

}

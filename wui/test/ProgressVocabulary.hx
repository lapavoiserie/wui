/**
	What `wui.nui.Vocabulary` says about the progress controls, computed while
	compiling. Its own class: a macro in `ProgressCheck` would drag the
	`@:build` views that check constructs into the macro context, which Haxe
	refuses.
**/
class ProgressVocabulary {
	public static macro function read():haxe.macro.Expr {
		var out = [];
		for (type in ["ProgressBar", "ProgressRing"]) {
			var max = [for (d in wui.nui.Vocabulary.defaultsFor(type)) if (d.winrt == "Maximum") d.value];
			out.push(type + ":" + wui.nui.Vocabulary.knows(type) + ":" + max.join(""));
		}
		return macro $v{out.join(",")};
	}
}

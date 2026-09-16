/**
	What `wui.nui.Vocabulary` says about Image and Icon, computed while
	compiling — its own class, for the reason `ProgressVocabulary` gives.
**/
class ImageVocabulary {
	public static macro function props():haxe.macro.Expr {
		var out = [];
		for (type in ["Image", "Icon"]) {
			out.push(type + ">" + wui.nui.Vocabulary.winuiFor(type));
			for (p in wui.nui.Vocabulary.propsFor(type))
				out.push(type + ":" + p.name + "=" + p.winrt);
			for (d in wui.nui.Vocabulary.defaultsFor(type))
				out.push(type + ":default:" + d.winrt + "=" + d.value);
		}
		return macro $v{out.join(",")};
	}

	public static macro function buttonProps():haxe.macro.Expr {
		return macro $v{[for (p in wui.nui.Vocabulary.propsFor("Button")) "Button:" + p.name + "=" + p.winrt].join(",")};
	}
}

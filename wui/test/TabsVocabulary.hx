/**
	What `wui.nui.Vocabulary` says about the two tab controls, computed while
	compiling. Its own class for the reason `PickerVocabulary` gives: a macro
	beside `@:build` views is refused.
**/
class TabsVocabulary {
	/** Declared props of the two controls, as `type:name=winrt` pairs. **/
	public static macro function props():haxe.macro.Expr {
		var out = [];
		for (type in ["TabView", "TabViewItem"]) {
			out.push(type + "?" + wui.nui.Vocabulary.knows(type));
			for (p in wui.nui.Vocabulary.propsFor(type))
				out.push(type + ":" + p.name + "=" + p.winrt);
		}
		return macro $v{out.join(",")};
	}
}

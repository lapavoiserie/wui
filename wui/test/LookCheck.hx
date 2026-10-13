import mui.macros.Markup.ui;
import nui.Node;
import nui.PropValue;
import wui.mui.Look;
import wui.nui.WinUISink;

/**
	The two layers: wui's core draws the Windows way, and `wui.mui.Look`
	sets wui's own options so a mui application looks the same everywhere.
	Run with:

	    haxe -cp src -cp test -lib rui -lib nui -lib mui -D mui_backend=wui --macro "mui.macros.Bind.all()" --macro "wui.nui.Vocabulary.registerWithMui()" -main LookCheck --interp

	What this pins:

	- `standardize` sets each option on the node it is about -- a Toggle's
	  label inline, a Notice at the foot, a stack's alignment leaving
	  stretching children their width -- however deep, deferred children
	  included, and touches nothing else;
	- an option already on a node is kept;
	- a mui application's tree (`nuiBody`) carries them, and the same view
	  described the plain way (`FromViews.describe`, a wui application's
	  path) carries none: those keep the Windows look.
**/
class LookCheck {
	static var failures = 0;

	static function check(label:String, actual:Dynamic, expected:Dynamic) {
		var ok = Std.string(actual) == Std.string(expected);
		if (!ok) failures++;
		trace((ok ? "ok   " : "FAIL ") + label + " = " + actual + (ok ? "" : " (expected " + expected + ")"));
	}

	static function option(node:Node, key:String):String {
		var v = node.props.get(key);
		return v == null ? "none" : switch (v) {
			case PString(s): s;
			case PBool(b): Std.string(b);
			case _: Std.string(v);
		}
	}

	static function wuiKeys(node:Node):Int {
		var n = 0;
		for (k in node.props.keys()) if (StringTools.startsWith(k, "wui.")) n++;
		for (c in node.resolveChildren()) if (c != null) n += wuiKeys(c);
		return n;
	}

	static function find(node:Node, type:String):Null<Node> {
		if (node.type == type) return node;
		for (c in node.resolveChildren()) if (c != null) {
			var f = find(c, type);
			if (f != null) return f;
		}
		return null;
	}

	static function main() {
		// ---- standardize, on a hand-built tree ----
		var toggle = new Node("Toggle").prop("label", PString("Muet"));
		var notice = new Node("Notice").prop("message", PString("Fait"));
		var text = new Node("Text").prop("text", PString("Bonjour"));
		var row = new Node("HStack").child(text);
		var deferredToggle = new Node("Toggle");
		var list = new Node("VStack");
		list.childrenThunk = () -> [deferredToggle];
		var root = new Node("ZStack").child(new Node("VStack").child(row).child(toggle).child(list)).child(notice);

		var out = Look.standardize(root);
		check("the same tree comes back", out == root, true);
		check("a Toggle's label goes inline", option(toggle, WinUISink.LABEL_PLACEMENT), "inline");
		check("a Notice goes to the foot", option(notice, WinUISink.PLACEMENT), "bottomCenter");
		check("a VStack leaves stretching children their width", option(root.children[0], WinUISink.ALIGN_STRETCHING), "true");
		check("so does an HStack", option(row, WinUISink.ALIGN_STRETCHING), "true");
		check("a Text gets nothing", wuiKeys(text), 0);
		check("a ZStack gets nothing", option(root, WinUISink.ALIGN_STRETCHING), "none");
		list.resolveChildren();
		check("a deferred child is standardized when produced", option(deferredToggle, WinUISink.LABEL_PLACEMENT), "inline");

		var chosen = new Node("Toggle").prop(WinUISink.LABEL_PLACEMENT, PString("header"));
		Look.standardize(chosen);
		check("an option already set is kept", option(chosen, WinUISink.LABEL_PLACEMENT), "header");
		check("null stays null", Look.standardize(null), null);

		// ---- a mui application, and the same view the plain way ----
		var app = new LookApp();
		var muiTree = app.nuiBody();
		check("a mui app's Toggle is inline", option(find(muiTree, "Toggle"), WinUISink.LABEL_PLACEMENT), "inline");
		check("a mui app's Notice is at the foot", option(find(muiTree, "Notice"), WinUISink.PLACEMENT), "bottomCenter");
		check("the plain description carries no wui option", wuiKeys(wui.mui.FromViews.describe(app.body())), 0);

		trace(failures == 0 ? "all checks passed" : failures + " failed");
		if (failures > 0) Sys.exit(1);
	}
}

class LookApp extends mui.App {
	@:state var on:Bool = false;
	@:state var shown:Bool = false;

	override function body():mui.View
		return ui(<ZStack>
			<VStack alignment="leading">
				<Toggle label="Muet" isOn={on_}/>
			</VStack>
			<Notice presented={shown_} message="Fait" dismissLabel="Fermer"/>
		</ZStack>);
}

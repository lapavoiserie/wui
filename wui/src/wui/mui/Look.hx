package wui.mui;

import nui.Node;
import nui.PropValue;
import wui.nui.WinUISink;

/**
	A mui application's look on Windows: the same as on every other platform.

	`wui`'s core draws things the Windows way. Where that differs from the
	look every mui application shares (`mui/docs/look.md`), the core offers
	an option -- a `wui.` property, outside the canon, Windows' answer by
	default -- and this sets it on the tree a mui application describes:

	- a Toggle carries its label beside it, the switch at the trailing edge
	  (`wui.labelPlacement` "inline"; Windows puts a header above it);
	- a Notice sits at the foot of the screen, centred (`wui.placement`
	  "bottomCenter"; Windows puts an InfoBar across the head);
	- in a stack, a child that stretches keeps its width whatever the
	  alignment (`wui.alignStretching`; Windows aligns every child).

	A plain `wui` or `nui` application never comes through here, and keeps
	the Windows look. An option already on a node is left as it is.

	Stateless: it sets the options on the tree it is given -- built afresh
	on every pass -- and returns it. Deferred children are standardized when
	they are produced.
**/
class Look {
	public static function standardize(node:Null<Node>):Null<Node> {
		if (node == null) return null;
		switch (node.type) {
			case "Toggle" | "ToggleSwitch":
				setDefault(node, WinUISink.LABEL_PLACEMENT, PString("inline"));
			case "Notice":
				setDefault(node, WinUISink.PLACEMENT, PString("bottomCenter"));
			case "VStack" | "HStack":
				setDefault(node, WinUISink.ALIGN_STRETCHING, PBool(true));
			case _:
		}
		if (node.children != null)
			for (child in node.children) standardize(child);
		var deferred = node.childrenThunk;
		if (deferred != null)
			node.childrenThunk = () -> {
				var produced = deferred();
				if (produced != null) for (child in produced) standardize(child);
				produced;
			};
		return node;
	}

	/** A mui view, described and standardized: what a mui surface renders. **/
	public static function surface(view:wui.View):Node
		return standardize(FromViews.describe(view));

	static function setDefault(node:Node, key:String, value:PropValue):Void {
		if (!node.props.exists(key)) node.prop(key, value);
	}
}

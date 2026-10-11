package wui.mui;

/**
	`wui`'s conformance for `mui.View`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `wui`.

	An abstract over `wui.View` rather than a typedef, for one conversion: what
	`ui()` builds here is a `nui.Node` -- `wui` is in push mode and its sink
	draws nodes -- so markup returned from `body()`, or from a surface closure
	typed `mui.View`, used to be refused with "nui.Node should be mui.View".
	The node now stands in the view tree as a `NodeView`, and `FromViews`
	hands it on as it was built.
**/
@:forward
abstract View(wui.View) from wui.View to wui.View {
	@:from static inline function fromNode(node:nui.Node):View
		return new NodeView(node);

	/**
		And back: a view an application computed -- `{avatar(id)}`, a list of
		rows -- spliced into markup, which builds nodes here. A `NodeView`
		hands back the node it holds; null stays null, as a conditional child
		(`{shown ? row : null}`) means nothing to draw.
	**/
	@:to function toNode():nui.Node
		return this == null ? null : FromViews.describe(this);
}

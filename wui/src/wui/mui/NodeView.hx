package wui.mui;

/**
	A tree `ui()` built, standing where a `mui.View` is expected.

	Not a control: `FromViews` returns `node` in its place, and `PushCoverage`
	exempts it the way it exempts `ForEach` and `ConditionalView`. Markup has
	already checked the node against the vocabulary, keys, picker options and
	decorations included, so nothing is described twice.
**/
class NodeView extends wui.View {
	public final node:nui.Node;

	public function new(node:nui.Node) {
		super("NodeView");
		this.node = node;
	}
}

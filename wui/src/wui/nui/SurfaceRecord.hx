package wui.nui;

import rui.Signal.Effect;

/**
	Everything one mounted surface owns: the per-surface record the surfaces
	chantier converges on -- {driver, effect, lifetime} plus the registered
	root handle the tree reconciles into.

	This is what used to be four statics on `HaxeBridge` (`nuiSink`,
	`nuiReconciler`, `nuiTree`, `nuiEffect`). Statics were fine while exactly
	one tree ever mounted; a second surface would have fought over all four.
	Every surface declares its `keep` keys in the application's one
	`rui.Lifetime`, and one pass rebuilds them all (`HaxeBridge.rebuild`), as
	on sui: a pass per surface would sweep the keys the others declared. The
	Primary's record holds that lifetime, and releases it when the
	application ends; the others hold none.

	`dispose` is idempotent by the same contract as `mui`'s MountedSurface:
	container loss and application release overlap, and both call it. It
	releases the effect and the lifetime; the native controls die with their
	window, and their handles become permanent holes in the handle table.
**/
class SurfaceRecord {
	/** The registered root handle this surface's tree reconciles into. **/
	public final root:Int;

	public final sink:WinUISink;
	public final reconciler:Reconciler<Int>;
	/** The application's lifetime on the Primary, which releases it; null
		on every other surface, whose `keep` keys live in that same lifetime
		and are swept by the one pass that rebuilds them all. **/
	public final lifetime:Null<rui.Lifetime>;

	/** What this surface shows, asked again on every pass. **/
	public var content:Null<() -> nui.Node> = null;

	/** The window's own name, read on every pass; null keeps the one it
		was made with. **/
	public var title:Null<() -> String> = null;

	/** The name last put on the window, so an unchanged one is not set again. **/
	public var shownTitle:Null<String> = null;

	/** A width to fit the window to once its tree first exists; 0 = none. **/
	public var fitWidth:Float = 0;

	/** The mounted tree, replaced on every reconcile. **/
	public var tree:Null<Mounted<Int>> = null;

	/** The render effect; set once the first render is wired. **/
	public var effect:Null<Effect> = null;

	var disposed = false;

	public function new(root:Int, sink:WinUISink, reconciler:Reconciler<Int>, lifetime:Null<rui.Lifetime>) {
		this.root = root;
		this.sink = sink;
		this.reconciler = reconciler;
		this.lifetime = lifetime;
	}

	public function dispose():Void {
		if (disposed) return;
		disposed = true;
		if (effect != null) effect.dispose();
		if (lifetime != null) lifetime.release();
	}
}

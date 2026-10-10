import wui.bridge.HaxeBridge;

/**
	The Auxiliary window host, end to end minus WinRT. Run with:

	    haxe -cp src -cp test -lib rui -lib nui -lib mui -D mui_backend=wui --macro "mui.macros.Bind.all()" -main AuxiliaryCheck --interp

	A real mui application (the whole chain: Bind, `@:surface` collection, the
	hook `wui.mui.App`'s constructor installs) is driven through `install` and
	`renderNui`, with the one native act — creating a winrt Window — replaced
	at the injectable seam by a counting function. What this pins:

	- every Auxiliary declaration gets a window, in declaration order, titled
	  from its id;
	- one pass rebuilds every surface, the Status label included, in the
	  application's one lifetime -- as on sui: a write that one surface reads
	  rebuilds them all, and a `keep` key a surface declares outside body()
	  survives the Primary's rebuilds;
	- closing one disposes exactly that record -- the keys it alone declared
	  go at the end of the next pass -- while the Primary, the sibling and
	  the label live on;
	- application release disposes whatever is still mounted and releases
	  the lifetime, and every overlap (a second Closed, a Closed after
	  release) is a no-op.
**/
class AuxiliaryCheck {
	static var failures = 0;

	static function check(label:String, actual:Dynamic, expected:Dynamic) {
		var ok = Std.string(actual) == Std.string(expected);
		if (!ok) failures++;
		trace((ok ? "ok   " : "FAIL ") + label + " = " + actual + (ok ? "" : " (expected " + expected + ")"));
	}

	static function main() {
		// The seam: count and hand out handles the way the native table would.
		var created:Array<String> = [];
		var nextHandle = 100;
		HaxeBridge.windowCreator = function(title) {
			created.push(title);
			return nextHandle++;
		};

		var installed = HaxeBridge.install("AuxApp");
		check("install found the app", installed >= 0, true);
		HaxeBridge.renderNui(0);

		// ---- mounting: one window per declaration, titled from its id ----
		check("every declaration got a window", created.length, 2);
		check("titles come from the ids, prettified", created.join(","), "Inspector,Metrics");
		check("the first record is reachable by its handle", HaxeBridge.auxiliaryRecord(100) != null, true);
		check("each build ran once", Probe.builtA + "," + Probe.builtB, "1,1");

		// ---- one pass: a write rebuilds every surface ----
		var lifetime = AuxApp.last.lifetime;
		check("A keeps its key", lifetime.keeping("a"), true);
		check("the label keeps its key", lifetime.keeping("s"), true);
		AuxApp.last.bumpA();
		check("A rebuilt", Probe.builtA, 2);
		check("B rebuilt in the same pass", Probe.builtB, 2);
		check("the label was read in it", Probe.labelled, 2);
		check("A's key survived the pass", lifetime.keeping("a"), true);
		check("the label's key survived the pass", lifetime.keeping("s"), true);

		// ---- closing one touches nothing else ----
		HaxeBridge.surfaceClosed(100);
		check("its record is gone", HaxeBridge.auxiliaryRecord(100) == null, true);
		check("its key went at the end of the next pass", lifetime.keeping("a"), false);
		check("the label's key stayed", lifetime.keeping("s"), true);

		var before = Probe.builtA;
		AuxApp.last.bumpA();
		check("a closed surface is built no more", Probe.builtA, before);
		var siblings = Probe.builtB;
		AuxApp.last.bumpB();
		check("the sibling still lives", Probe.builtB, siblings + 1);

		HaxeBridge.surfaceClosed(100);
		check("a second Closed for the same window is a no-op", HaxeBridge.auxiliaryRecord(101) != null, true);

		// ---- application release disposes what is still mounted ----
		HaxeBridge.disposePrimary();
		check("release released the lifetime", lifetime.keeping("s"), false);
		check("a Closed arriving after release is a no-op", HaxeBridge.auxiliaryRecord(101) == null, true);
		HaxeBridge.surfaceClosed(101);
		var after = Probe.builtB;
		AuxApp.last.bumpB();
		check("nothing rebuilds after release", Probe.builtB, after);

		trace(failures == 0 ? "\nall checks passed" : '\n$failures failed');
		#if sys
		Sys.exit(failures == 0 ? 0 : 1);
		#end
	}
}

/** Build counters, on a class of their own: a view method may not read its
	app's mutable fields (the view rule), and these are bookkeeping about the
	test, not state the view depends on. **/
class Probe {
	public static var builtA = 0;
	public static var builtB = 0;
	public static var labelled = 0;
}

/** A real mui application: the hook is installed by wui.mui.App's own
	constructor, the declarations are collected by the real macro. **/
class AuxApp extends mui.App {
	public static var last:AuxApp;

	@:state var countA:Int = 0;
	@:state var countB:Int = 0;

	public function new() {
		super();
		last = this;
	}

	// The cells stay private after the @:state rewrite; the test writes
	// through these, the way any outside caller would.
	public function bumpA() countA += 1;
	public function bumpB() countB += 1;

	@:surface(Auxiliary)
	function inspector():mui.View {
		Probe.builtA++;
		lifetime.keep("a", () -> () -> {});
		return new mui.ui.Text('A $countA');
	}

	@:surface(Auxiliary)
	function metrics():mui.View {
		Probe.builtB++;
		return new mui.ui.Text('B $countB');
	}

	// A key declared by the label, outside body(): the timer the client keeps.
	@:surface(Status)
	function status():mui.surface.Labelled {
		Probe.labelled++;
		lifetime.keep("s", () -> () -> {});
		return new mui.surface.Labelled({title: "Aux"}, () -> new mui.ui.Text('S'));
	}
}

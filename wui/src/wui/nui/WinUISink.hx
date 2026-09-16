package wui.nui;

import nui.Modifier;
import nui.Node;
import nui.NodeSink;
import nui.PropValue;
import wui.bridge.Callbacks;

/**
	Drives WinUI through [nui's push contract](https://lapavoiserie.github.io/nui/#/push-mode).

	WinUI 3 is retained-mode: a tree of XAML controls is built once and mutated.
	It diffs nothing, so it has to be told what changed — the push side of the
	model, with `qui` as the reference implementation and this as the **second**.

	## `Native` is an `Int`, and that is the interesting part

	`qui` holds a `ui.Item` in Haxe because Silica items are visible to it. A
	WinRT control is not visible to hxcpp at all: it lives in the C++/WinRT world
	the generated project compiles. So the tree lives on the C++ side, and what
	Haxe holds is an **index into a handle table** — the same discipline that
	already governs callbacks here, where an id crosses and a closure never does.

	A sink whose `Native` is opaque is worth noting for the contract: nothing in
	`NodeSink` requires the handle to be inspectable, and this proves it, because
	`applyProp` receives the node `type` rather than asking the handle what it
	is. That parameter was added for `qui`, whose Silica items carry no type
	name. It turns out to be load-bearing for a second, unrelated reason.

	## What this settles about the three gaps left open in B4

	`qui` could not honour three of the contract's assumptions, and they were
	deliberately **not** softened — softening for a sample of one would have
	crippled the next adopter. WinUI is that next adopter, and it honours all
	three:

	| Assumption | `qui` | `wui` |
	|---|---|---|
	| `create` and `insert` are separable | no — QML instantiates into a parent | **yes** |
	| the insertion index is choosable | no — positioners append | **yes**, `Children().InsertAt` |
	| `destroy` frees | no — it only hides, and leaks | **yes**, releasing the last reference |

	So the decision to leave them alone was right, and the contract is not
	over-specified: it was `qui` that was under-capable.

	## Why the native calls are behind a define

	`wui_node_*` lives in the generated `WuiNodes.cpp`, on the WinUI side of the
	build. A binary that links this library without that project — a test, a tool
	— has nothing to call, and a direct extern would fail to link. The generator
	sets `wui_winui`; without it the sink compiles to no-ops, which is exactly
	what a test driving a recording sink needs. The library stays linkable on its
	own, which is what its documentation claimed before it was true.

	## Granularity

	`bindReactive` is the one hook. Left at its default a property is applied
	immediately; set to wrap each application in a `rui` effect and a write
	re-applies exactly one property, with no tree walk — the fine-grained path
	`qui` validated on device.

	```haxe
	sink.bindReactive = fn -> { var e = new rui.Signal.Effect(fn); () -> e.dispose(); };
	```
**/
#if (cpp && wui_winui)
// Declared, not included: these live in the generated WuiNodes.cpp, on the
// WinUI side of the build. This library must keep compiling without it -- a
// test binary links the sink and simply has no controls to talk to.
@:cppFileCode('
extern "C" int  wui_node_create(const char* type, int parent);
extern "C" void wui_node_prop_string(int h, const char* type, const char* key, const char* value);
extern "C" void wui_node_prop_int(int h, const char* type, const char* key, int value);
extern "C" void wui_node_prop_float(int h, const char* type, const char* key, double value);
extern "C" void wui_node_prop_bool(int h, const char* type, const char* key, bool value);
extern "C" void wui_node_prop_callback(int h, const char* type, const char* key, int callbackId);
extern "C" void wui_node_modifier(int h, const char* type, const char* modType, double f0, const char* s0);
extern "C" void wui_node_insert(int parent, int child, int index);
extern "C" void wui_node_remove(int parent, int child);
extern "C" void wui_node_destroy(int h);
extern "C" bool wui_node_knows(const char* type);
')
#end
@:keep
class WinUISink implements NodeSink<Int> {
	var _bind:(Void->Void)->Null<Void->Void> = function(fn) { fn(); return null; };

	/**
		How to undo every binding made against a handle, so `destroy` can.

		Kept here rather than by the reconciler because this is where a binding
		is made and where the handle is known. The reconciler disposes the effect
		that owns a *list*; these are the effects that own a single property, and
		they are subscribed to signals that routinely outlive the node — a write
		after the node is gone would otherwise apply a property to a freed
		handle.
	**/
	var _bindings:Map<Int, Array<Void->Void>> = new Map();

	public var bindReactive(get, set):(Void->Void)->Null<Void->Void>;

	function get_bindReactive()
		return _bind;

	function set_bindReactive(v) {
		_bind = v;
		return v;
	}

	/**
		Which id carries the handler for a given (node, property).

		Allocated once and reused. A re-render hands a fresh closure for the same
		button every time — they can never compare equal, so the property is
		always re-applied — and minting an id per application would grow the
		registry for the life of the app.
	**/
	final callbackIds = new Map<String, Int>();

	public function new() {}

	/**
		Materialise a control — and nothing else.

		`parent` is ignored, and that is the point: WinUI can build a control
		before it has anywhere to live, so mounting belongs to `insert`. The
		first adopter had no such freedom.
	**/
	/**
		Whether a node of this type can be built here: a declared control, or a
		native component registered with the node runtime. Asked by a panel that
		must replace what it cannot build with a fallback before rendering —
		`vui.Fallback.substitute` — rather than draw "?Type". False where there is
		no WinUI side to ask.
	**/
	public static function knows(type:String):Bool {
		if (Canonical.isAlias(type))
			return true;
		#if (cpp && wui_winui)
		return untyped __cpp__("wui_node_knows({0}.utf8_str())", canonType(type));
		#else
		return false;
		#end
	}

	public function create(node:Node, parent:Null<Int>):Int {
		var native = nativeTypeIn(node, parent == null ? null : built.get(parent));
		var handle = nativeCreate(native, parent == null ? -1 : parent);
		built.set(handle, native);
		if (native != canonType(node.type))
			chosen.set(handle, native);
		return handle;
	}

	/** The control every handle was built as. **/
	final built = new Map<Int, String>();

	/** Icons drawn as text that were given a label, which wins over the name. **/
	final labelled = new Map<Int, Bool>();

	/**
		The control a handle was built as, when the node's type alone did not
		say. A property arrives later with the node's own type, and the native
		setter matches on the control's: a value sent as `ProgressView` to a
		handle built as `ProgressBar` would find no case and vanish.
	**/
	final chosen = new Map<Int, String>();

	function typeAt(target:Int, type:String):String {
		var native = chosen.get(target);
		return native != null ? native : canonType(type);
	}

	/**
		Which WinUI control a node becomes.

		Mostly a rename (`canonType`). `ProgressView` is the one type whose
		control depends on its properties: a value draws a bar, no value a ring
		— what `wui.mui.ProgressView` does for a local view, applied to a
		received one. Decided when the control is made; a progress that gains a
		value later keeps the control it started with.
	**/
	/**
		Which control a node becomes under a parent built as `parentType`.

		An option of a picker is the one case the node alone cannot decide: a
		canonical `Picker` carries its options as `Text` children, and a ComboBox
		holds ComboBoxItems. Only the parent says this Text is an option.
	**/
	public static function nativeTypeIn(node:Node, parentType:Null<String>):String {
		if (node.type == "Text" && parentType == "ComboBox")
			return "ComboBoxItem";
		// An icon with a name this platform has no glyph for -- received, or
		// added to the vocabulary without a line in `wui.nui.Icons` -- is its
		// label, as text.
		if (node.type == "Icon" && !node.props.exists("glyph")
			&& Icons.glyphOf(PropValueTools.asString(node.props.get("name"))) == null)
			return "Text";
		return nativeTypeOf(node);
	}

	public static function nativeTypeOf(node:Node):String {
		if (node.type == "ProgressView")
			return node.props.exists("value") ? "ProgressBar" : "ProgressRing";
		return canonType(node.type);
	}

	/**
		The register's canonical vocabulary, translated at the door.

		A tree that arrives over the Companion wire speaks the canonical
		names — `Button`/`label`, `Toggle`/`isOn`, `TextInput`/`text` (see
		`cui.nui.Describe`, the reference) — while this sink's native runtime
		is generated from wui's own control declarations, where the same
		things are called `text`, `ToggleSwitch` and `TextBox`. Without the
		translation the native setter has no case for `label` and drops it
		silently: a wired Button renders 24 pixels wide with nothing on it.

		wui-native trees (the menu bar, anything out of `FromViews`) pass
		through unchanged: the aliases only name types and keys that do not
		exist in wui's own schema.
	**/
	static function canonType(t:String):String {
		// ProgressView is decided by its props in nativeTypeOf; by name alone it
		// passes through here so a handle's remembered choice stays authoritative.
		return t == "ProgressView" ? t : Canonical.type(t);
	}

	static function canonKey(type:String, key:String):String
		return Canonical.key(type, key);

	/**
		Apply one property, through `bindReactive` so the binding can own an
		effect.

		The value may be `PReactive`, so it is resolved rather than switched on
		directly — and resolved *inside* the bound function, so that re-running
		the effect re-reads it.
	**/
	public function applyProp(target:Int, type:String, key:String, value:PropValue):Void {
		key = canonKey(type, key);
		var nodeType = type;
		type = typeAt(target, type);
		// A canonical Icon names its glyph; the control takes the character. As
		// text (no glyph for the name), the label is the text, or the name spoken.
		if (nodeType == "Icon") {
			var word = PropValueTools.asString(PropValueTools.resolve(value));
			if (type == "Icon") {
				if (key == "label") return;
				if (key == "name") {
					var glyph = Icons.glyphOf(word);
					if (glyph == null) return;
					key = "glyph";
					value = PString(glyph);
				}
			} else if (type == "Text") {
				if (key == "label" && word != "") {
					labelled.set(target, true);
					key = "text";
				} else if (key == "name" && !labelled.exists(target)) {
					key = "text";
					value = PString(nui.Icons.spoken(word));
				} else {
					return;
				}
			}
		}
		remember(target, _bind(function() {
			var resolved = PropValueTools.resolve(value);
			if (resolved == null) return;

			switch (resolved) {
				case PString(v):
					nativePropString(target, type, key, v == null ? "" : v);
				case PInt(v):
					nativePropInt(target, type, key, v);
				case PFloat(v):
					nativePropFloat(target, type, key, v);
				case PBool(v):
					nativePropBool(target, type, key, v);

				// An id crosses, never the closure: a closure held only by native
				// code is invisible to the hxcpp GC, which is the wall both
				// sibling backends hit before this one.
				//
				// The four value-carrying forms register exactly like the plain
				// one. Nothing here has to know which of them it is holding: the
				// id names a slot, and it is the generated C++ -- which knows
				// what event the control has -- that decides whether to call
				// back with a string, a number or a switch position.
				case PCallback(fn): registerHandler(target, type, key, fn);
				// A selection reports an index. A tree that crossed a wire carries
				// every action as a string callback (`nui.Snapshot.inflate`), so
				// the index is handed over as the text it parses back from.
				case PCallbackString(fn) if (key == "onSelect"):
					registerHandler(target, type, key, function(index:Int) fn(Std.string(index)));
				case PCallbackString(fn): registerHandler(target, type, key, fn);
				case PCallbackFloat(fn): registerHandler(target, type, key, fn);
				case PCallbackInt(fn): registerHandler(target, type, key, fn);
				case PCallbackBool(fn): registerHandler(target, type, key, fn);

				case PReactive(_):
					// resolve() is a fixed point, so this cannot happen. Saying so
					// beats a silent default branch.
					trace('[wui] $type.$key: PReactive survived resolution');
			}
		}));
	}

	/** Keep how to undo a binding, if the hook gave one. **/
	function remember(target:Int, stop:Null<Void->Void>):Void {
		if (stop == null) return;
		var made = _bindings.get(target);
		if (made == null) {
			made = [];
			_bindings.set(target, made);
		}
		made.push(stop);
	}

	/**
		Give a (node, property) slot an id, or point its existing id at a new
		closure.

		Ids are allocated once per slot and reused. A re-render hands fresh
		closures -- each one closing over what the app just read -- and allocating
		a new id for every one of them would grow the table for as long as the app
		runs. The control keeps pointing at the same id; only what the id means
		changes, so it is never told again.
	**/
	function registerHandler(target:Int, type:String, key:String, fn:Dynamic):Void {
		var slot = target + ":" + key;
		if (callbackIds.exists(slot)) {
			Callbacks.setNode(callbackIds.get(slot), fn);
			return;
		}
		var id = Callbacks.registerNode(fn);
		callbackIds.set(slot, id);
		nativePropCallback(target, type, key, id);
	}

	/** Apply the ordered chain. Order is significant, so it is not sorted. **/
	public function applyModifiers(target:Int, type:String, modifiers:Array<Modifier>):Void {
		if (modifiers == null) return;
		type = typeAt(target, type);

		for (m in modifiers) {
			var f0 = (m.floats != null && m.floats.length > 0) ? m.floats[0] : 0.0;
			var s0 = (m.strings != null && m.strings.length > 0) ? m.strings[0] : "";
			nativeModifier(target, type, m.type, f0, s0);
		}
	}

	public function insert(parent:Int, child:Int, index:Int):Void {
		nativeInsert(parent, child, index);
	}

	public function remove(parent:Int, child:Int):Void {
		nativeRemove(parent, child);
	}

	public function destroy(target:Int):Void {
		chosen.remove(target);
		// Bindings first, handle second. A binding stopped after the handle is
		// freed is one that may still fire against it in between.
		var made = _bindings.get(target);
		if (made != null) {
			_bindings.remove(target);
			for (stop in made)
				try stop() catch (e:Dynamic) trace("[wui] binding teardown: " + e);
		}
		// Retire the node's callback ids too. The registry is monotonic and
		// never wiped (a wipe would take another surface's handlers with it),
		// so retirement happens here, where the node's death is known: each id
		// becomes a hole, and a late event against it is reported, never
		// routed to a stranger's closure.
		var prefix = target + ":";
		var dead = [for (slot in callbackIds.keys()) if (StringTools.startsWith(slot, prefix)) slot];
		for (slot in dead) {
			Callbacks.clearNode(callbackIds.get(slot));
			callbackIds.remove(slot);
		}
		nativeDestroy(target);
	}

	// ---- the crossing itself ----

	static function nativeCreate(type:String, parent:Int):Int {
		#if (cpp && wui_winui)
		var handle:Int = 0;
		untyped __cpp__("{0} = wui_node_create({1}.utf8_str(), {2})", handle, type, parent);
		return handle;
		#else
		return -1;
		#end
	}

	static function nativePropString(h:Int, type:String, key:String, value:String):Void {
		#if (cpp && wui_winui)
		untyped __cpp__("wui_node_prop_string({0}, {1}.utf8_str(), {2}.utf8_str(), {3}.utf8_str())",
			h, type, key, value);
		#end
	}

	static function nativePropInt(h:Int, type:String, key:String, value:Int):Void {
		#if (cpp && wui_winui)
		untyped __cpp__("wui_node_prop_int({0}, {1}.utf8_str(), {2}.utf8_str(), {3})", h, type, key, value);
		#end
	}

	static function nativePropFloat(h:Int, type:String, key:String, value:Float):Void {
		#if (cpp && wui_winui)
		untyped __cpp__("wui_node_prop_float({0}, {1}.utf8_str(), {2}.utf8_str(), {3})", h, type, key, value);
		#end
	}

	static function nativePropBool(h:Int, type:String, key:String, value:Bool):Void {
		#if (cpp && wui_winui)
		untyped __cpp__("wui_node_prop_bool({0}, {1}.utf8_str(), {2}.utf8_str(), {3})", h, type, key, value);
		#end
	}

	static function nativePropCallback(h:Int, type:String, key:String, id:Int):Void {
		#if (cpp && wui_winui)
		untyped __cpp__("wui_node_prop_callback({0}, {1}.utf8_str(), {2}.utf8_str(), {3})", h, type, key, id);
		#end
	}

	static function nativeModifier(h:Int, type:String, modType:String, f0:Float, s0:String):Void {
		#if (cpp && wui_winui)
		untyped __cpp__("wui_node_modifier({0}, {1}.utf8_str(), {2}.utf8_str(), {3}, {4}.utf8_str())",
			h, type, modType, f0, s0);
		#end
	}

	static function nativeInsert(parent:Int, child:Int, index:Int):Void {
		#if (cpp && wui_winui)
		untyped __cpp__("wui_node_insert({0}, {1}, {2})", parent, child, index);
		#end
	}

	static function nativeRemove(parent:Int, child:Int):Void {
		#if (cpp && wui_winui)
		untyped __cpp__("wui_node_remove({0}, {1})", parent, child);
		#end
	}

	static function nativeDestroy(h:Int):Void {
		#if (cpp && wui_winui)
		untyped __cpp__("wui_node_destroy({0})", h);
		#end
	}
}

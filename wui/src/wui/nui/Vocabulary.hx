package wui.nui;

#if macro
import haxe.macro.Context;
import haxe.macro.Type;

using haxe.macro.Tools;
#end

/**
	What `wui` can render, read from the controls themselves.

	Everything is derived, including the properties every element has: `View`
	declares `width`, `height`, `visible` and `enabled` as vars, so the
	hand-written `UNIVERSAL` table that used to sit here is gone.

	## Two readers, one source

	The knowledge has two audiences, and trying to serve both with one generated
	table failed outright: **Haxe forbids a type carrying `@:build` from being
	used inside a macro**, and this is consumed at macro time by
	`wui.macros.NodeValidator` and by `mui.macros.Backend`.

	So there is no table. This reads the `wui.ui.*` classes **on demand**, at
	macro time, which is the only moment its callers need an answer. The other
	audience — the reconciler, at runtime, wanting to know what an absent
	property becomes — is served by `wui.nui.Defaults`, a small generated map.

	Two views, one place they are derived from: a class carrying `@:winuiType` is
	a node type — named after itself — and its `@:winrt` vars are its properties, and their Haxe declarations give the name,
	the kind, the nullability and the default.

	## Why it is not in `nui`

	Nobody writes against a common core: `mui` picks its target at compile time,
	so the vocabulary that matters while authoring is the *target backend's*, and
	the useful error is "`placeholder` does not exist **here**". A core would also
	become the union of five widget sets — `wui` has `ProgressRing`, `cui` has
	`Table` — turning `nui` from *what a node is* into *which nodes exist*.

	What must stay common is the **naming**, which `nui` settled in B2. A
	discipline, not a vocabulary.

	## Why "vocabulary" and not "schema"

	A schema is a document you declare. `qui`'s node types *are* existing Haxe
	classes, so its vocabulary is read from them; `wui`'s are strings the C++
	knows how to build. Nothing is shared between those artefacts — only the
	question `mui` asks. The name says what is described and stays silent on how
	it is obtained.
**/
class Vocabulary {
	#if macro
	static inline var CONTROLS = "wui/ui";

	static var cache:Map<String, Map<String, String>> = null;

	/** Does `wui` know how to build this node type? **/
	/**
		Hand `mui` this vocabulary, from `wui`'s own build file:

		```
		--macro wui.nui.Vocabulary.registerWithMui()
		```

		`mui` cannot look this up the way it looks up a type, because a macro
		cannot call a function it does not name. So the naming happens here,
		where it is `wui` naming itself — and `mui` keeps no list of backends.
	**/
	public static function registerWithMui():Void {
		mui.macros.Backend.register({
			knows: knows,
			keysOf: keysOf,
			requiredOf: requiredOf,
			kindOf: kindOf,
			types: types,
		});
	}

	public static function knows(type:String):Bool {
		return all().exists(type);
	}

	/** Every property this type accepts. **/
	public static function keysOf(type:String):Array<String> {
		var own = all().get(type);
		return own == null ? [] : [for (k in own.keys()) k];
	}

	/** Properties this type requires: not nullable, and with no declared default. **/
	public static function requiredOf(type:String):Array<String> {
		var out = [];
		var cls = classOf(type);
		if (cls == null) return out;

		eachProp(cls, function(field, kind) {
			if (!isNullable(field.type) && !field.meta.has(":defaultValue")) out.push(field.name);
		});
		return out;
	}

	/** Which `PropValue` constructor a property takes, by name. `null` if unknown. **/
	public static function kindOf(type:String, key:String):Null<String> {
		var own = all().get(type);
		return (own != null && own.exists(key)) ? own.get(key) : null;
	}

	/**
		The WinRT member a property maps to — the one thing a Haxe type cannot
		say, and therefore the only thing still written by hand.
	**/
	public static function winrtOf(type:String, key:String):Null<String> {
		var cls = classOf(type);
		if (cls == null) return null;

		var found:String = null;
		eachProp(cls, function(field, kind) {
			if (field.name != key) return;
			var meta = field.meta.extract(":winrt");
			if (meta.length > 0 && meta[0].params.length > 0) {
				switch (meta[0].params[0].expr) {
					case EConst(CString(v, _)): found = v;
					case _:
				}
			}
		});
		return found;
	}

	/**
		The same lookup, on `View` itself.

		The two rendering paths name their types differently — the transpiled one
		uses WinUI's (`TextBlock`, `StackPanel`), the node one uses nui's (`Text`,
		`VStack`) — so a lookup keyed by node type misses when the caller holds a
		transpiled name. The properties every element has are declared on `View`,
		which both paths share, so asking it directly answers either way.
	**/
	public static function viewProp(key:String):Null<{winrt:String, kind:String}> {
		var cls = resolveClass("wui.View");
		if (cls == null) return null;

		var found:{winrt:String, kind:String} = null;
		eachProp(cls, function(field, kind) {
			if (field.name != key || found != null) return;
			var meta = field.meta.extract(":winrt");
			if (meta.length > 0 && meta[0].params.length > 0) {
				switch (meta[0].params[0].expr) {
					case EConst(CString(v, _)): found = {winrt: v, kind: kind};
					case _:
				}
			}
		});
		return found;
	}

	/** The WinUI control a node type maps to. **/
	public static function winuiFor(type:String):Null<String> {
		var cls = classOf(type);
		return cls == null ? null : winuiNameOf(cls);
	}

	/** Every declared property of a type, with its kind and WinRT member. **/
	public static function propsFor(type:String):Array<{name:String, kind:String, winrt:String}> {
		var out = [];
		var cls = classOf(type);
		if (cls == null) return out;

		eachProp(cls, function(field, kind) {
			var meta = field.meta.extract(":winrt");
			if (meta.length == 0 || meta[0].params.length == 0) return;
			switch (meta[0].params[0].expr) {
				case EConst(CString(member, _)):
					out.push({name: field.name, kind: kind, winrt: member});
				case _:
			}
		});
		return out;
	}

	/**
		Properties carrying a declared default, for the generated `create`.

		This is what lets `VStack` and `HStack` be generated at all: both are a
		StackPanel and only `orientation` tells them apart, so the default has to
		be applied at creation rather than hardcoded in a switch.
	**/
	public static function defaultsFor(type:String):Array<{winrt:String, kind:String, value:String}> {
		var out = [];
		var cls = classOf(type);
		if (cls == null) return out;

		eachProp(cls, function(field, kind) {
			var winrt = field.meta.extract(":winrt");
			var def = field.meta.extract(":defaultValue");
			if (winrt.length == 0 || def.length == 0) return;
			if (winrt[0].params.length == 0 || def[0].params.length == 0) return;

			var member = switch (winrt[0].params[0].expr) {
				case EConst(CString(v, _)): v;
				case _: null;
			};
			var value = switch (def[0].params[0].expr) {
				case EConst(CString(v, _)): v;
				case EConst(CInt(v)): v;
				case EConst(CFloat(v)): v;
				case EConst(CIdent(v)) if (v == "true" || v == "false"): v;
				case _: null;
			};
			if (member != null && value != null) out.push({winrt: member, kind: kind, value: value});
		});
		return out;
	}

	/** Every known type, sorted, for an error message that helps. **/
	public static function types():Array<String> {
		var out = [for (t in all().keys()) t];
		out.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		return out;
	}

	// ---- reading the controls ----

	static function all():Map<String, Map<String, String>> {
		if (cache != null) return cache;
		cache = new Map();

		for (module in modules()) {
			var cls = resolveClass("wui.ui." + module);
			if (cls == null) continue;

			var type = nodeNameOf(cls);
			if (type == null) continue;

			var props = new Map<String, String>();
			eachProp(cls, function(field, kind) props.set(field.name, kind));
			// MERGED rather than set, because a canonical name can have two
			// controls behind it: `ProgressBar` and `ProgressRing` are both a
			// `ProgressView`, and which one is built depends on whether the
			// node carries a value. So the canonical type carries the union,
			// and `WinUISink.nativeTypeOf` decides at creation.
			var known = cache.get(type);
			if (known == null) cache.set(type, props);
			else for (name in props.keys()) if (!known.exists(name)) known.set(name, props.get(name));

			// Answer to this backend's OWN name as well: same control, same
			// properties, two vocabularies naming it. A tree written against
			// `wui` directly -- the menu bar, anything out of `FromViews` --
			// says `ToggleSwitch`, and goes on saying it.
			if (cls.name != type && !cache.exists(cls.name)) cache.set(cls.name, props);

			// And to the transpiled name, when that is a third word.
			var winui = winuiNameOf(cls);
			if (winui != null && !cache.exists(winui)) cache.set(winui, props);
		}
		return cache;
	}

	static function modules():Array<String> {
		for (path in Context.getClassPath()) {
			var dir = haxe.io.Path.join([path, CONTROLS]);
			if (!sys.FileSystem.exists(dir)) continue;

			var out = [];
			for (entry in sys.FileSystem.readDirectory(dir)) {
				if (StringTools.endsWith(entry, ".hx")) out.push(entry.substr(0, entry.length - 3));
			}
			return out;
		}
		return [];
	}

	static function classOf(type:String):Null<ClassType> {
		for (module in modules()) {
			var cls = resolveClass("wui.ui." + module);
			if (cls == null) continue;
			if (nodeNameOf(cls) == type || cls.name == type || winuiNameOf(cls) == type) return cls;
		}
		return null;
	}

	static function resolveClass(path:String):Null<ClassType> {
		try {
			return switch (Context.getType(path)) {
				case TInst(ref, _): ref.get();
				case _: null;
			};
		} catch (e:Dynamic) {
			return null;
		}
	}

	/**
		The name the transpiled path uses, when it differs.

		A control has two identities: its class name is nui's, and the generator
		holds WinUI's — `Text` against `TextBlock`. Nothing could bridge them,
		because the transpiled name is a `super()` argument no macro can read, so
		a lookup by type simply missed and a fallback on `View` hid it for the
		shared properties. A type-specific one would have been dropped in silence.
	**/
	public static function winuiNameOf(cls:ClassType):Null<String> {
		var meta = cls.meta.extract(":winuiType");
		if (meta.length == 0 || meta[0].params.length == 0) return null;
		return switch (meta[0].params[0].expr) {
			case EConst(CString(s, _)): s;
			case _: null;
		};
	}

	/**
		The node type a control is — the **canonical** name, when there is one.

		There used to be a `@:node("Text")` on a class called `Text`: the same
		word twice, once as a string that could drift from the other. A control
		is a node type because it maps to a real control, which `@:winuiType`
		already says; what it is called needed no restating.

		That held while the name was this backend's own business. It stopped
		holding when `mui`'s markup began checking a tag against the target's
		vocabulary: the name became **shared**, and half of these classes are
		named after WinUI's control rather than after the concept. So `<Toggle/>`
		did not compile for `wui` while `WinUISink` was translating `Toggle` at
		the door for every tree that arrived over the wire -- the schema refusing
		at compile time exactly what the sink would have rendered.

		`wui.nui.Canonical` already held the table; this reads it, and the class
		name stays what a WinUI reader recognises. Nothing is restated: the
		canonical name is a DIFFERENT word, which is the whole reason it has to
		be said.
	**/
	public static function nodeNameOf(cls:ClassType):Null<String> {
		if (winuiNameOf(cls) == null) return null;
		var canon = Canonical.canonOf(cls.name);
		return canon != null ? canon : cls.name;
	}

	/** Walk the `@:winrt` properties of a class and its ancestors, once each. **/
	public static function eachProp(cls:ClassType, fn:(ClassField, String) -> Void):Void {
		var seen = new Map<String, Bool>();
		var current = cls;

		while (current != null) {
			for (field in current.fields.get()) {
				if (!field.meta.has(":winrt") || seen.exists(field.name)) continue;
				seen.set(field.name, true);

				var kind = kindOfType(field.type);
				// A `@:winrt` field says "I cross to a WinUI property". A kind
				// this generator cannot spell used to make it vanish instead:
				// no setter in the emitted C++, no warning, and a received
				// value ignored in silence. That is failing OPEN, which is the
				// one shape this ecosystem refuses everywhere else.
				//
				// Found by trying `nui.Numbers` on `wui.ui.Text.numbers`: an
				// abstract over `Null<String>` was not a string here, the two
				// `textNumerals` branches disappeared from `WuiNodes.cpp`, and
				// the build succeeded without a word.
				if (kind == null) {
					Context.error(field.name + ": a @:winrt property of type "
						+ haxe.macro.TypeTools.toString(field.type)
						+ ", which this generator cannot spell -- it emits no setter "
						+ "for it, so a received value would be dropped in silence.\n"
						+ "  Use Int, Float, Bool, String, a function, or an abstract "
						+ "over one of those.", field.pos);
				}
				fn(field, kind);
			}
			current = current.superClass == null ? null : current.superClass.t.get();
		}
	}

	public static function isNullable(t:Type):Bool {
		return switch (t) {
			case TAbstract(ref, _) if (ref.get().name == "Null"): true;
			case _: false;
		};
	}

	/**
		What a property carries, in this generator's own alphabet.

		An abstract is followed to what it is an abstract OVER, so a type that
		gives a value its meaning -- `nui.Numbers`, which reads as a `Bool` and
		travels as `"tabular"` -- crosses as the string it really is. Before
		that it answered null, and null used to mean "skip this field".
	**/
	public static function kindOfType(t:Type):Null<String> {
		return switch (t.follow()) {
			case TAbstract(ref, _):
				switch (ref.get().name) {
					case "Int": "KInt";
					case "Float": "KFloat";
					case "Bool": "KBool";
					// Guarded against an abstract that follows to itself -- a
					// core type has no underlying one to reach.
					case _:
						var under = Context.followWithAbstracts(t);
						Std.string(under) == Std.string(t) ? null : kindOfType(under);
				}
			case TInst(ref, _): ref.get().name == "String" ? "KString" : null;
			case TFun(_, _): "KCallback";
			case _: null;
		};
	}
	#end
}

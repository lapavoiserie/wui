/**
	A secret field on wui. Run with:

	    haxe -cp src -cp test -lib rui -lib nui -lib mui -lib kui -D mui_backend=wui \
	      --macro "mui.macros.Bind.all()" -main SecretCheck --interp

	What is checked here is the part that decides whether any of it CAN be true:
	what the vocabulary lets a node carry, and what C++ the generator emits. The
	control itself is proven on Windows, and this is where that stands.

	**Proven** by the Farceur session, 2026-09-18, through UI Automation on a
	rebuilt pupitre:

	- no reveal button, focus or not — the box holds an `Edit`, a `ScrollViewer`
	  and the placeholder's `TextBlock`, and nothing else;
	- masked: UIA reports `IsPassword = True`, and reading it through the Value
	  pattern comes back empty;
	- nothing per keystroke: the engine received no action while typing;
	- the class really is `PasswordBox`, carrying the placeholder it was given.

	**Not proven, and not to be assumed**: that Enter submits, that the field is
	cleared afterwards, that a second Enter reports an empty string rather than
	the same secret, that copying is refused, and what the text services
	framework is handed.

	## Why `wui` has no `PasswordInput`

	The canon's other masked field — a password an application owns, bound and
	read back — is on `pui`, `cui` and `sui`, and deliberately NOT here yet.

	It was written and withdrawn the same night. A second control class was
	needed, because the guarantee above is that `wui.ui.PasswordBox` declares no
	value; but a node type and its WinRT class are the same name in this
	backend, and two classes claiming `@:winuiType("PasswordBox")` collide.
	`wui.nui.Vocabulary.classOf` matches on either name and answered the wrong
	class, so the generator emitted

	    if (t == "PasswordBox" && k == "text")

	— a value setter on the SECRET node type. The guarantee verified on Windows
	the day before, silently undone by an addition that had nothing to do with
	it, and visible only in the emitted C++.

	Giving `wui` a password field means separating the node type from the WinRT
	class it instantiates — a change in the generator, not another control — and
	that is worth doing carefully rather than at the end of an evening. The
	contract entry is optional, so until then an application naming
	`mui.ui.PasswordInput` on `wui` fails to compile at that line, which is the
	answer that costs nothing.

	## What cannot be proven from here

	The reason is worth keeping, because it will come back for any keyboard
	behaviour on this backend: posted `WM_CHAR` messages do not reach a XAML
	control, so the box stays empty and the engine hears nothing — which does
	not distinguish "not wired" from "not typed". Real keys need `SendInput`,
	which takes the keyboard and the foreground window away from whoever is
	using the machine. That is a proof to arrange, not one to steal.
**/
class SecretCheck {
	static var failures = 0;

	static function check(label:String, ok:Bool, ?got:Dynamic) {
		if (!ok) failures++;
		Sys.println((ok ? "ok   " : "FAIL ") + label + (ok || got == null ? "" : '  (got: $got)'));
	}

	static function main() {
		// --- the node carries no value, because none is declared ---
		//
		// This is the structural half of the guarantee. `wui.nui.Vocabulary`
		// reads the control class to decide what a node of this type may carry,
		// so "a tree cannot set a password" is true because there is no
		// property to set -- not because a sink remembers to drop one.
		var props = SecretVocabulary.props().split(",");
		var names = [for (p in props) p.split("=")[0]];
		check("the vocabulary knows PasswordBox", names.length > 0, names.join(" "));
		check("it declares a placeholder", names.indexOf("placeholder") >= 0, names.join(" "));
		check("and a reveal mode", names.indexOf("revealMode") >= 0, names.join(" "));
		for (forbidden in ["password", "text", "value", "secret"])
			check('it declares no "$forbidden" for a tree to set',
				names.indexOf(forbidden) < 0, names.join(" "));

		// --- the canonical name reaches the control ---
		check("SecretInput is a canonical alias",
			wui.nui.Canonical.isAlias("SecretInput"));
		check("and becomes a PasswordBox",
			wui.nui.Canonical.type("SecretInput") == "PasswordBox",
			wui.nui.Canonical.type("SecretInput"));

		// --- what the generator emits ---
		var runtime = SecretVocabulary.runtime();
		check("reveal is turned off when the control is made",
			runtime.indexOf("PasswordRevealMode::Hidden") > 0);
		check("and `Peek`, WinUI's own default, is never asked for",
			runtime.indexOf("PasswordRevealMode::Peek") < 0);

		var at = runtime.indexOf("k == \"onSecret\"");
		check("a submit handler is emitted", at > 0);
		var block = at < 0 ? "" : runtime.substr(at, 900);
		check("it reports on Enter", block.indexOf("VirtualKey::Enter") > 0);
		check("and clears the field straight afterwards",
			block.indexOf("s.Password(L\"\")") > 0);
		check("under the echo guard, so clearing is not read as an entry",
			block.indexOf("g_setting[h] = true") > 0);
		check("PasswordChanged is never wired: nothing is reported per keystroke",
			runtime.indexOf("PasswordChanged") < 0);

		// --- the mui facade ---
		var field = new wui.mui.SecretInput("rtmp://serveur/app/clé", _ -> {}, true,
			"À saisir sur la machine elle-même.");
		check("the facade is a PasswordBox", field.viewType == "PasswordBox", field.viewType);
		check("it carries the action", field.properties.get(nui.SelfSource.SECRET_KEY) != null);
		check("whether one is stored", field.properties.get("isSet") == true);
		check("and the application's words for a refusal",
			field.properties.get("whenRefused") == "À saisir sur la machine elle-même.");
		for (forbidden in ["password", "text", "value"])
			check('and no "$forbidden" of its own', field.properties.get(forbidden) == null);

		Sys.println(failures == 0 ? "\nall checks passed" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}

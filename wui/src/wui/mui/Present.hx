package wui.mui;

import mui.surface.SurfaceDecl;
import mui.surface.SurfaceDecl.SurfaceDeclTools;
import mui.surface.SurfaceRole;

/**
	`wui`'s conformance for `mui.surface.Present`: bring a declared surface
	forward.

	- `Primary`: the main window restored if minimised, shown if a Status
	  application hid it, raised, and the application brought to the front.
	- `Preferences`: its own window, made on the first asking -- never at
	  launch -- and raised on the next; closed, it is made again.
	- `Auxiliary`: the window with that id, raised, or made again if the
	  person closed it.

	`false` for a role this application did not declare, or one with no
	window on Windows.
**/
class Present {
	public static function show(role:SurfaceRole, ?id:String):Bool {
		var app:App = cast wui.bridge.HaxeBridge.app();
		if (app == null) return false;
		return switch (role) {
			case Primary:
				wui.bridge.HaxeBridge.presentRoot(-1);
			case Preferences:
				var decl = pick(app.surfaces(), Preferences, id, "preferences");
				if (decl == null) false;
				else {
					var content = decl.content;
					// Named as the declaration names itself; a bare view is
					// titled as the application is (an empty title takes the
					// main window's). Sized to what it holds, at least 480 wide.
					wui.bridge.HaxeBridge.openWindow("preferences:" + decl.id, "",
						function() return Look.surface(content()), 480,
						SurfaceDeclTools.windowTitleOf(app.surfaces(), decl.id));
				}
			case Auxiliary:
				var decl = pick(app.surfaces(), Auxiliary, id, null);
				if (decl == null) false;
				else {
					var content = decl.content;
					wui.bridge.HaxeBridge.openWindow(decl.id, titleOf(decl.id),
						function() return Look.surface(content()), 0,
						SurfaceDeclTools.windowTitleOf(app.surfaces(), decl.id));
				}
			case _:
				false;
		};
	}

	/**
		End the application, once the command that asked has returned: the
		icon leaves the notification area, every window closes, and the
		application's lifetime is released last.
	**/
	public static function quit():Void
		wui.bridge.HaxeBridge.quit();

	/** The declaration with `id`, else the role's default, else the first. **/
	static function pick(decls:Array<SurfaceDecl>, role:SurfaceRole, id:Null<String>,
			defaultId:Null<String>):Null<{id:String, content:() -> mui.View}> {
		var all = SurfaceDeclTools.treesOf(decls, role);
		if (id != null) {
			for (one in all) if (one.id == id) return one;
			return null;
		}
		if (defaultId != null) for (one in all) if (one.id == defaultId) return one;
		return all.length > 0 ? all[0] : null;
	}

	/** The title an auxiliary window gets at launch, for the same window made again. **/
	static function titleOf(id:String):String
		return id.length == 0 ? "Window" : id.charAt(0).toUpperCase() + id.substr(1);
}

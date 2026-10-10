package wui.bridge;

/**
	`trace` to the debugger's output on Windows.

	A WinUI application has no console, so hxcpp's `trace` -- every
	`[wui] …` line this library writes to say what it mounted or refused --
	went nowhere a person could read. `OutputDebugString` is where a Windows
	tool looks: Visual Studio's Output window, DebugView.
**/
#if (cpp && wui_winui)
@:cppFileCode('#include <windows.h>')
#end
class DebugTrace {
	public static function install():Void {
		#if (cpp && wui_winui)
		haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos) {
			var line = haxe.Log.formatOutput(v, infos) + "\n";
			untyped __cpp__("OutputDebugStringA({0}.utf8_str())", line);
		};
		#end
	}
}

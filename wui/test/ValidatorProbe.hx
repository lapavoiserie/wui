/** Runs wui.macros.NodeValidator on whatever is compiled, as a wui build does. **/
class ValidatorProbe {
	#if macro
	public static function register() {
		haxe.macro.Context.onAfterTyping(types -> wui.macros.NodeValidator.check(types));
	}
	#end
}

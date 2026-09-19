/** The generated pch, written out so a check can read it. **/
class PchProbe {
	public static macro function write(dir:String):haxe.macro.Expr {
		@:privateAccess wui.macros.ProjectGenerator.generatePch(dir);
		return macro null;
	}
	static function main() {}
}

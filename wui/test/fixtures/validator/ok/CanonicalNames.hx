import nui.Node;
import nui.PropValue;

/** Canonical names the sink translates: each must compile. **/
class CanonicalNames {
	static function bar():Node return new Node("ProgressView").prop("value", PFloat(0.5));
	static function ring():Node return new Node("ProgressView");
	static function toggle():Node return new Node("Toggle");
	static function field():Node return new Node("TextInput");
	static function main() {
		bar(); ring(); toggle(); field();
	}
}

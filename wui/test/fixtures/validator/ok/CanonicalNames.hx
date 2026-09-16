import nui.Node;
import nui.PropValue;

/** Canonical names the sink translates: each must compile. **/
class CanonicalNames {
	static function bar():Node return new Node("ProgressView").prop("value", PFloat(0.5));
	static function ring():Node return new Node("ProgressView");
	static function toggle():Node return new Node("Toggle");
	static function field():Node return new Node("TextInput");
	static function picker():Node return new Node("Picker").prop("selectedIndex", PInt(0));
	// A canonical Icon under the name of wui's own control: its keys are the
	// canon's, which the sink translates to a glyph.
	static function icon():Node return new Node("Icon").prop("name", PString("mic")).prop("label", PString("Mic"));
	static function image():Node return new Node("Image").prop("src", PString("asset:logo.png")).prop("alt", PString("Logo"));
	static function main() {
		bar(); ring(); toggle(); field(); picker(); icon(); image();
	}
}

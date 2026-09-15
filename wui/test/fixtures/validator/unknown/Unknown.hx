import nui.Node;

/** A literal type nothing builds: must stay a compile error. **/
class Unknown {
	static function main() {
		new Node("Hologramme");
	}
}

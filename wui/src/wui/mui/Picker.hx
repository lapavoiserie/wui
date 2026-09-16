package wui.mui;

/**
	`wui`'s conformance for `mui.ui.Picker`: a WinUI `ComboBox`.

	```haxe
	new Picker("Transition", ["Cut", "Fade", "Wipe"], transition_)
	```

	The label is the combo box's header; an empty one shows no header.
**/
class Picker extends wui.ui.ComboBox {
	public function new(label:String, options:Array<String>, selection:PickerBinding) {
		super(options, selection.unwrap(), label);
	}
}

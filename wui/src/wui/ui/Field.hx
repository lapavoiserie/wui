package wui.ui;

import wui.View;

/**
	The canon's `Field`: a label, and the controls of one row.

	A Grid tagged `field` of two columns, made with its parts (`fieldSetup`):
	the label, and a Grid holding the controls side by side -- the only one
	stretched when it is alone, so a text field takes the row. Each control is
	labelled by the field's label for UI Automation.

	In a `Form` the label column is the form's (`formAlign`); outside one it is
	as wide as the label, and the controls follow it.
**/
@:winuiType("Grid")
@:noWinuiAlias
@:build(wui.macros.ControlBuilder.build())
class Field extends View {
	@:winrt("FieldLabel") public var label:String;
	@:winrt("ColumnSpacing") public var spacing:Float = 12;
	@:winrt("Tag") public var kind:String = "field";

	public function new(label:String, controls:Array<View>) {
		super("Field", controls);
		this.label = label;
	}
}

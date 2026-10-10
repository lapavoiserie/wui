package wui.ui;

import wui.View;

/**
	The canon's `Form`: the rows of one entry, a label beside what it names.

	A vertical StackPanel tagged `form`, whose children `wui_node_insert` turns
	into rows of two columns -- the label, then the control -- unless they are
	rows already (`Field`, `Section`). A control with a `label` of its own
	(`Picker`, `Toggle`, ...) gives it to the label column and draws no header:
	`WinUISink` sends it as `formLabel`, which also names the control for UI
	Automation, so Narrator reads "Fréquence, Hebdomadaire".

	The label column is one width for the whole form, sections included:
	`formAlign` measures every label and sizes them all to the widest, which is
	what a WinUI Grid would do if the rows were one Grid -- and they cannot be,
	because a `Section` sits between them.

	`@:noWinuiAlias`: a StackPanel like `VStack`, which keeps answering to that
	name.
**/
@:winuiType("StackPanel")
@:noWinuiAlias
@:build(wui.macros.ControlBuilder.build())
class Form extends View {
	@:winrt("Spacing") public var spacing:Float = 16;

	/** How `wui_node_insert` knows a child of this panel is a row. **/
	@:winrt("Tag") public var kind:String = "form";

	public function new(rows:Array<View>) {
		super("Form", rows);
	}
}

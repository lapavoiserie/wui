package wui.mui;


/**
	`wui`'s conformance for `mui.ui.SecretInput`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `wui`.

	A `PasswordBox`, which gives three of the canon's four duties outright —
	masked, no clipboard, and nothing that reads the value back out — with
	reveal turned off (`wui.ui.PasswordBox` says why) and the report wired to
	Enter alone, never to `PasswordChanged`.

	The value is not a property of the node. It cannot be: `wui.nui.Vocabulary`
	reads `wui.ui.PasswordBox` to decide what a node of this type may carry, and
	no value is declared there.
**/
class SecretInput extends wui.ui.PasswordBox {
    public function new(placeholder:String, ?onSecret:String -> Void, isSet:Bool = false,
            ?whenRefused:String) {
        super(placeholder);
        // The property, not the field: what the push bridge consumes is
        // `properties.get(...)`, the same lesson `wui.mui.Button` carries for
        // its `onClick`.
        if (onSecret != null) properties.set(nui.SelfSource.SECRET_KEY, onSecret);
        if (isSet) properties.set("isSet", true);
        if (whenRefused != null) properties.set("whenRefused", whenRefused);
    }
}

#!/bin/sh
# What wui.macros.NodeValidator accepts and refuses, as a wui build would run it.
#
#   ./test/validator-check.sh
cd "$(dirname "$0")/.."
fails=0
common="-cp src -cp test -lib nui -lib rui -lib mui -D mui_backend=wui --macro ValidatorProbe.register() --no-output"

if out=$(haxe $common -cp test/fixtures/validator/ok -main CanonicalNames 2>&1); then
	echo "ok   canonical names the sink translates compile: ProgressView, Toggle, TextInput, Picker, Icon, Image"
else
	echo "FAIL canonical names were refused:"; echo "$out"; fails=$((fails + 1))
fi

out=$(haxe $common -cp test/fixtures/validator/unknown -main Unknown 2>&1)
if echo "$out" | grep -q 'wui ne sait pas construire un noeud "Hologramme"'; then
	echo "ok   a literal type nothing builds is still refused"
else
	echo "FAIL Hologramme was not refused:"; echo "$out"; fails=$((fails + 1))
fi

[ "$fails" -eq 0 ] && echo "\nall checks passed" || echo "\n$fails failed"
exit "$fails"

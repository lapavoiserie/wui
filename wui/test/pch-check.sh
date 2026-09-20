#!/bin/sh
# The generated pch includes what the generated runtime uses.
#
#   ./test/pch-check.sh
#
# `UISettings` was used by the colour helpers and NOT included, so a clean
# Windows build stopped at `'UISettings': is not a member of`. It compiled as
# text on this Mac, which is exactly the gap this check closes.
cd "$(dirname "$0")/.."
work=$(mktemp -d)
haxe -cp src -cp test -lib rui -lib nui -lib mui -lib kui -D mui_backend=wui \
	--macro "mui.macros.Bind.all()" --macro "PchProbe.write('$work')" \
	-main PchProbe --interp > /dev/null 2>&1
fails=0
# `RectangleGeometry` is in Media, which the clip helpers need.
for needle in "winrt/Windows.UI.ViewManagement.h" "winrt/Microsoft.UI.Xaml.Media.h"; do
	if grep -q "$needle" "$work"/pch.h 2>/dev/null; then
		echo "ok   the pch includes $needle"
	else
		echo "FAIL the pch does not include $needle"; fails=1
	fi
done
rm -rf "$work"
[ "$fails" -eq 0 ] && echo "" && echo "all good" || { echo ""; echo "failed"; }
exit "$fails"

package wui.macros;

#if macro
import haxe.macro.Context;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
#end

/**
 * Generates the C++/WinRT application boilerplate:
 * - App.h / App.cpp (wWinMain entry point, window creation)
 * - WuiRuntime.h (string conversion, UI thread dispatch, state notification)
 */
class BridgeGenerator {
    #if macro
    public static function generate(appName:String, outputDir:String, windowWidth:Int, windowHeight:Int, appClassPath:String, callbackCount:Int):Void {
        if (!FileSystem.exists(outputDir)) {
            FileSystem.createDirectory(outputDir);
        }

        generateNodeRuntime(outputDir);
        generateAppHeader(appName, outputDir);
        generateAppSource(appName, outputDir, windowWidth, windowHeight, appClassPath, callbackCount);
        generateRuntime(outputDir);
    }


    /**
        Emit the node runtime: a handle table and the six operations of
        `nui.NodeSink`, implemented against WinUI.

        **The handle is an integer, not an object.** `qui` can hold a `ui.Item`
        in Haxe because Silica items are visible to it; a WinRT control is not
        visible to hxcpp at all. So the tree lives here, Haxe holds indices, and
        the contract crosses the same way callbacks already do.

        This file does not depend on the app, only on the vocabulary of node
        types it knows how to build.
    /**
        Emit the node runtime: a handle table and the six operations of
        `nui.NodeSink`, implemented against WinUI.

        **The switch is generated, not written.** It used to be a hand-kept list
        of `if (t == "Text")` branches under a comment asking whoever touched it
        to keep it in step with `Vocabulary` -- the fourth copy of one truth, and
        the last. It is built from the controls now: a class carrying
        `@:winuiType` is a node type, its `@:winrt` vars are its properties, and
        their declared defaults are applied at creation.

        **The handle is an integer, not an object.** `qui` holds a `ui.Item` in
        Haxe because Silica items are visible to it; a WinRT control is not
        visible to hxcpp at all. So the tree lives here and Haxe holds indices,
        the same way callbacks already cross.
    **/
    /**
        The registry a native component joins -- `vui`'s, or anyone's.

        A component is compiled into the application from its own sources (the
        `msbuild` payload `ProjectGenerator` already reads) and registers itself
        with a static initialiser. The node runtime consults it at the four places
        the Farceur prototype had to patch the generated project to reach:
        creation before the unknown fallback, each property setter, destruction,
        and `wui_node_knows`.

        `hostType` names the control the component really builds -- its root. A
        property the component does not take continues as that type, so the
        generated setters for a margin, a background or visibility still apply;
        without it they match on "LevelMeter", find nothing, and the property is
        lost without a word.
    **/
    static function generateComponentsHeader(outputDir:String):Void {
        var h = new StringBuf();
        h.add("#pragma once\n");
        h.add("// Native components for the node runtime. See BridgeGenerator.generateComponentsHeader.\n");
        h.add("//\n");
        h.add("// Everything runs on the UI thread. A property setter returns true when it\n");
        h.add("// took the key; false lets the generated setters of hostType apply. A number\n");
        h.add("// may arrive through propInt or propFloat -- a whole Float is described as an\n");
        h.add("// Int -- so take a numeric key in both.\n");
        h.add("#include <winrt/Microsoft.UI.Xaml.h>\n#include <cstring>\n#include <string>\n#include <vector>\n\n");
        h.add("struct WuiComponent {\n");
        h.add("    const char* type;\n");
        h.add("    const char* hostType;\n");
        h.add("    winrt::Microsoft::UI::Xaml::UIElement (*create)();\n");
        h.add("    bool (*propString)(winrt::Microsoft::UI::Xaml::UIElement const&, const char* key, const char* value);\n");
        h.add("    bool (*propInt)(winrt::Microsoft::UI::Xaml::UIElement const&, const char* key, int value);\n");
        h.add("    bool (*propFloat)(winrt::Microsoft::UI::Xaml::UIElement const&, const char* key, double value);\n");
        h.add("    bool (*propBool)(winrt::Microsoft::UI::Xaml::UIElement const&, const char* key, bool value);\n");
        h.add("    void (*destroy)(winrt::Microsoft::UI::Xaml::UIElement const&);\n");
        h.add("};\n\n");
        h.add("namespace wui { namespace components {\n");
        h.add("    inline std::vector<WuiComponent>& all() {\n        static std::vector<WuiComponent> registered;\n        return registered;\n    }\n\n");
        h.add("    inline const WuiComponent* find(std::string const& type) {\n");
        h.add("        for (auto& c : all()) if (c.type && type == c.type) return &c;\n");
        h.add("        return nullptr;\n    }\n\n");
        h.add("    // static wui::components::Registrar meter{{\"LevelMeter\", \"StackPanel\", &create, ...}};\n");
        h.add("    struct Registrar {\n        explicit Registrar(WuiComponent c) { all().push_back(c); }\n    };\n");
        h.add("}}\n");
        ProjectGenerator.writeIfChanged(Path.join([outputDir, "WuiComponents.h"]), h.toString());
    }

    static function generateNodeRuntime(outputDir:String):Void {
        var header = new StringBuf();
        header.add("#pragma once\n#include \"pch.h\"\n\n");
        header.add("// The six operations of nui.NodeSink, over integer handles.\n");
        header.add("extern \"C\" int  wui_node_create(const char* type, int parent);\n");
        header.add("extern \"C\" void wui_node_prop_string(int h, const char* type, const char* key, const char* value);\n");
        header.add("extern \"C\" void wui_node_prop_int(int h, const char* type, const char* key, int value);\n");
        header.add("extern \"C\" void wui_node_prop_float(int h, const char* type, const char* key, double value);\n");
        header.add("extern \"C\" void wui_node_prop_bool(int h, const char* type, const char* key, bool value);\n");
        header.add("extern \"C\" void wui_node_prop_callback(int h, const char* type, const char* key, int callbackId);\n");
        header.add("extern \"C\" void wui_node_modifier(int h, const char* type, const char* modType, double f0, const char* s0);\n");
        header.add("extern \"C\" void wui_node_insert(int parent, int child, int index);\n");
        header.add("extern \"C\" void wui_node_remove(int parent, int child);\n");
        header.add("extern \"C\" void wui_node_destroy(int h);\n");
        header.add("// Whether a node of this type can be built here: a declared control, or a\n");
        header.add("// component registered through WuiComponents.h.\n");
        header.add("extern \"C\" bool wui_node_knows(const char* type);\n\n");
        header.add("namespace wui { namespace nodes {\n");
        header.add("    // Register a surface's root and get its handle. The first window's root\n");
        header.add("    // lands on handle 0 as before -- but as a fact of an empty table, not a\n");
        header.add("    // contract. This replaced reset(), which CLEARED the table first: fine\n");
        header.add("    // with one window, and with two it wiped the other surface's controls.\n");
        header.add("    int registerRoot(winrt::Microsoft::UI::Xaml::UIElement const& root);\n\n");
        header.add("    // Open one auxiliary window and register its root. BuildUI hands this\n");
        header.add("    // to the hxcpp library through the wui_bridge_set_window_creator slot;\n");
        header.add("    // the library never names it, so it stays linkable on its own.\n");
        header.add("    int createWindow(const char* title);\n}}\n");
        ProjectGenerator.writeIfChanged(Path.join([outputDir, "WuiNodes.h"]), header.toString());
        generateComponentsHeader(outputDir);

        var src = new StringBuf();
        src.add("#include \"pch.h\"\n#include \"WuiNodes.h\"\n#include \"WuiRuntime.h\"\n#include \"WuiComponents.h\"\n#include <unordered_map>\n#include <cmath>\n");
        src.add("// VirtualKey / VirtualKeyModifiers, for the accelerator a MenuFlyoutItem\n");
        src.add("// carries. pch.h pulls the Xaml headers; the enums live in Windows.System,\n");
        src.add("// which nothing else here needed until the menu bar.\n");
        src.add("#include <winrt/Windows.System.h>\n");
        src.add("#include <vector>\n#include <string>\n\n");
        // Pictures: a BitmapImage, the executable's directory for assets, a
        // temporary file for a data: picture.
        src.add("#include <winrt/Microsoft.UI.Xaml.Media.Imaging.h>\n");
        src.add("#include <winrt/Microsoft.UI.Xaml.Automation.h>\n");
        src.add("#include <winrt/Microsoft.UI.Xaml.Documents.h>\n");
        src.add("#include <unordered_map>\n#include <wctype.h>\n");
        src.add("#include <windows.h>\n#include <fstream>\n\n");
        src.add("namespace winrt_controls = winrt::Microsoft::UI::Xaml::Controls;\n");
        src.add("namespace winrt_xaml = winrt::Microsoft::UI::Xaml;\n\n");
        src.add("// Implemented in the hxcpp library: a node property that is a handler crosses\n");
        src.add("// as an id, never as a pointer -- the same rule as every other callback here.\n");
        src.add("extern \"C\" void wui_bridge_invoke_node(int id);\n");
        src.add("// A control that carries a value hands it back with the event. What Haxe last\n");
        src.add("// wrote is not the answer: the user may have typed since, and the field is the\n");
        src.add("// authority on its own contents.\n");
        src.add("extern \"C\" void wui_bridge_invoke_node_string(int id, const char* value);\n");
        src.add("extern \"C\" void wui_bridge_invoke_node_float(int id, double value);\n");
        src.add("extern \"C\" void wui_bridge_invoke_node_int(int id, int value);\n");
        src.add("extern \"C\" void wui_bridge_invoke_node_bool(int id, bool value);\n");
        src.add("// An auxiliary window was closed; the Haxe side disposes exactly that\n");
        src.add("// surface's record. Reported by the Closed handler createWindow installs.\n");
        src.add("extern \"C\" void wui_bridge_surface_closed(int rootHandle);\n\n");

        src.add("namespace {\n");
        src.add("    // Index -> control. Handles are never reused: a stale one then names a hole\n");
        src.add("    // rather than someone elses control, so a use-after-destroy is a reported\n");
        src.add("    // no-op instead of a wrong widget being poked.\n");
        src.add("    std::vector<winrt_xaml::UIElement> g_nodes;\n\n");
        src.add("    // Which registered component made a handle, so destroy can tell it.\n");
        src.add("    std::unordered_map<int, const WuiComponent*> g_componentOf;\n\n");
        src.add("    // One Click subscription per node, so applying onClick again REPLACES it.\n");
        src.add("    // WinUI events accumulate, and a re-render hands fresh closures that can\n");
        src.add("    // never compare equal, so without revoking first one click fires n+1 times.\n");
        src.add("    std::vector<winrt::event_token> g_clickTokens;\n\n");
        src.add("    // The same, for the one event a control uses to report its own value.\n");
        src.add("    // A separate vector rather than a second use of the one above: a Button\n");
        src.add("    // has a click and a Slider has a value change, but nothing says a control\n");
        src.add("    // cannot one day have both, and sharing the slot would silently revoke\n");
        src.add("    // one by subscribing the other.\n");
        src.add("    std::vector<winrt::event_token> g_valueTokens;\n");
        // A secret reports on a KEY, not on a value change, so its handler gets
        // a slot of its own: sharing g_valueTokens would make wiring a submit
        // retire whatever value handler the same node already had.
        src.add("    std::vector<winrt::event_token> g_keyTokens;\n\n");
        // The Tag a control was given, as text, or empty.
        //
        // Read through IPropertyValue rather than `unbox_value_or<hstring>`:
        // that one instantiates IReference<hstring>, which this header set
        // rejects outright ("T must be WinRT type"). The boxing interface
        // underneath asks nothing of the type system and answers the same
        // question.
        src.add("    std::wstring tagText(winrt_xaml::UIElement const& e) {\n");
        src.add("        auto fe = e.try_as<winrt_xaml::FrameworkElement>();\n");
        src.add("        if (fe == nullptr) return L\"\";\n");
        src.add("        auto boxed = fe.Tag();\n");
        src.add("        if (boxed == nullptr) return L\"\";\n");
        src.add("        auto pv = boxed.try_as<winrt::Windows::Foundation::IPropertyValue>();\n");
        src.add("        if (pv == nullptr || pv.Type() != winrt::Windows::Foundation::PropertyType::String) return L\"\";\n");
        src.add("        return std::wstring(pv.GetString().c_str());\n    }\n\n");
        // A column's rows follow its children: after an insert or a removal,
        // every child from `from` on sits in the row of its new position.
        src.add("    void columnRenumber(winrt_controls::Grid const& grid, uint32_t from) {\n");
        src.add("        for (uint32_t k = from; k < grid.Children().Size(); ++k) {\n");
        src.add("            if (auto moved = grid.Children().GetAt(k).try_as<winrt_xaml::FrameworkElement>())\n");
        src.add("                winrt_controls::Grid::SetRow(moved, (int)k);\n        }\n    }\n\n");
        // The column a ScrollViewer's children live in, made on first use:
        // vertical scrolling as needed, never horizontal.
        src.add("    winrt_controls::StackPanel scrollColumn(winrt_controls::ScrollViewer const& scroll, bool make) {\n");
        src.add("        auto content = scroll.Content();\n");
        src.add("        winrt_controls::StackPanel column{ nullptr };\n");
        src.add("        if (content) column = content.try_as<winrt_controls::StackPanel>();\n");
        src.add("        if (column != nullptr && tagText(column) == L\"scroll\") return column;\n");
        src.add("        if (!make) return nullptr;\n");
        src.add("        winrt_controls::StackPanel made;\n");
        src.add("        made.Orientation(winrt_controls::Orientation::Vertical);\n");
        src.add("        made.Tag(winrt::box_value(L\"scroll\"));\n");
        src.add("        scroll.VerticalScrollBarVisibility(winrt_controls::ScrollBarVisibility::Auto);\n");
        src.add("        scroll.HorizontalScrollBarVisibility(winrt_controls::ScrollBarVisibility::Disabled);\n");
        src.add("        scroll.Content(made);\n");
        src.add("        return made;\n    }\n\n");

        src.add("    // The auxiliary windows, pinned. A winrt::Window is ref-counted, and\n");
        src.add("    // nothing else in this process is obliged to hold one once createWindow\n");
        src.add("    // returns -- the main window survives as an App member for the same\n");
        src.add("    // reason. Appended, never removed: the same never-shrink policy as the\n");
        src.add("    // handle table, and a closed window is a dead entry nobody dereferences.\n");
        src.add("    std::vector<winrt_xaml::Window> g_windows;\n\n");
        src.add("    winrt_xaml::UIElement at(int h) {\n");
        src.add("        if (h < 0 || h >= (int)g_nodes.size()) return nullptr;\n");
        src.add("        return g_nodes[h];\n    }\n\n");
        src.add("    int put(winrt_xaml::UIElement const& e) {\n");
        src.add("        g_nodes.push_back(e);\n        g_clickTokens.push_back(winrt::event_token{});\n");
        src.add("        g_valueTokens.push_back(winrt::event_token{});\n");
        src.add("        g_keyTokens.push_back(winrt::event_token{});\n");
        src.add("        return (int)g_nodes.size() - 1;\n    }\n\n");
        // A ComboBox's selection, applied when it can be. WinUI throws for an
        // index past the last item, and the index may arrive before the items
        // do; and a tree arriving while the list is open must not move the
        // highlight under the pointer. So the wanted index is kept per handle
        // and applied on every chance: when it is set, when an item is
        // inserted, when the list closes.
        //
        // Two things found by the Farceur session on its switcher, both of which
        // overwrote a person's choice: a selection this runtime makes must not be
        // reported as one the user made (applying a received index sent
        // onSelect back, at attach and after every tree), and a choice the user
        // made must replace the wanted index (closing the list re-applied the
        // index of the last tree, from before the choice). So the index this
        // runtime is about to set is noted, and the SelectionChanged it causes
        // is swallowed -- matched by value, so it holds whether WinUI raises the
        // event inside the setter or later -- and a reported choice becomes the
        // wanted index.
        src.add("    std::unordered_map<int, int> g_comboWanted;\n");
        src.add("    std::unordered_map<int, int> g_comboSetting;\n");
        src.add("    std::unordered_map<int, winrt::event_token> g_comboClosed;\n\n");
        src.add("    void comboApply(winrt_controls::ComboBox const& c, int h) {\n");
        src.add("        auto it = g_comboWanted.find(h);\n");
        src.add("        if (it == g_comboWanted.end() || c.IsDropDownOpen()) return;\n");
        src.add("        int want = it->second < -1 ? -1 : it->second;\n");
        src.add("        if (want >= (int)c.Items().Size()) return;\n");
        src.add("        if (c.SelectedIndex() != want) {\n");
        src.add("            g_comboSetting[h] = want;\n");
        src.add("            c.SelectedIndex(want);\n        }\n    }\n\n");
        // True when this change is the one comboApply just made: consumed once.
        src.add("    bool comboProgrammatic(int h, int index) {\n");
        src.add("        auto it = g_comboSetting.find(h);\n");
        src.add("        if (it == g_comboSetting.end() || it->second != index) return false;\n");
        src.add("        g_comboSetting.erase(it);\n        return true;\n    }\n\n");
        // `nui`'s `clip`: children cut at this view's edge. WinUI has no
        // property for it -- a Grid or a StackPanel does not clip, and every
        // container in this backend is one -- so it is a geometry on
        // `UIElement.Clip`, and a geometry does NOT follow the element: it is
        // a fixed rectangle, and one set before layout would be 0x0 forever.
        // Hence the SizeChanged, which is the whole reason this is not a
        // one-liner.
        //
        // The handler takes the element from `sender` and holds nothing: an
        // element owning a handler owning the element is a cycle WinRT has no
        // collector to break -- the same rule the window's Closed follows.
        src.add("    std::unordered_map<int, winrt::event_token> g_clipTokens;\n\n");
        src.add("    void clipApply(winrt_xaml::FrameworkElement const& fe) {\n");
        src.add("        winrt::Microsoft::UI::Xaml::Media::RectangleGeometry geometry;\n");
        src.add("        geometry.Rect(winrt::Windows::Foundation::Rect{ 0.0f, 0.0f,\n");
        src.add("            (float)fe.ActualWidth(), (float)fe.ActualHeight() });\n");
        src.add("        fe.Clip(geometry);\n    }\n\n");
        src.add("    void clipToBounds(winrt_xaml::FrameworkElement const& fe, int h) {\n");
        src.add("        clipApply(fe);\n");
        src.add("        if (g_clipTokens.find(h) != g_clipTokens.end()) return;\n");
        src.add("        g_clipTokens[h] = fe.SizeChanged([](auto const& sender, auto const&) {\n");
        src.add("            auto e = sender.template try_as<winrt_xaml::FrameworkElement>();\n");
        src.add("            if (e != nullptr) clipApply(e);\n");
        src.add("        });\n    }\n\n");

        // A TabView selects by index and raises SelectionChanged when it is set,
        // so it needs the same two-map guard the ComboBox needed: an index this
        // runtime applies must not come back as a choice the person made. That
        // defect was found on a Windows screen -- a received tree reported
        // `onSelect` at every attach, overwriting what the person had chosen.
        src.add("    std::unordered_map<int, int> g_tabWanted;\n");
        src.add("    std::unordered_map<int, int> g_tabSetting;\n\n");
        // An insert may be what makes a wanted index valid: the tree arrives as
        // a tab at a time, and the selection is pushed before the last one.
        src.add("    void tabApply(winrt_controls::TabView const& c, int h) {\n");
        src.add("        auto it = g_tabWanted.find(h);\n");
        src.add("        if (it == g_tabWanted.end()) return;\n");
        src.add("        int want = it->second;\n");
        src.add("        if (want < 0 || want >= (int)c.TabItems().Size()) return;\n");
        src.add("        if (c.SelectedIndex() != want) {\n");
        src.add("            g_tabSetting[h] = want;\n");
        src.add("            c.SelectedIndex(want);\n        }\n    }\n\n");
        src.add("    bool tabProgrammatic(int h, int index) {\n");
        src.add("        auto it = g_tabSetting.find(h);\n");
        src.add("        if (it == g_tabSetting.end() || it->second != index) return false;\n");
        src.add("        g_tabSetting.erase(it);\n        return true;\n    }\n\n");
        src.add("    void tabSelect(winrt_controls::TabView const& c, int h, int want) {\n");
        src.add("        g_tabWanted[h] = want;\n        tabApply(c, h);\n    }\n\n");
        // The canon names a tab's icon; WinUI wants an IconSource. An empty
        // glyph means no icon rather than an empty box -- a name this platform
        // does not know is a thing to leave out, not to draw.
        src.add("    void tabIcon(winrt_controls::TabViewItem const& c, winrt::hstring const& glyph) {\n");
        src.add("        if (glyph.empty()) { c.IconSource(nullptr); return; }\n");
        src.add("        winrt_controls::FontIconSource source;\n");
        src.add("        source.Glyph(glyph);\n");
        src.add("        c.IconSource(source);\n    }\n\n");
        src.add("    void comboSelect(winrt_controls::ComboBox const& c, int h, int want) {\n");
        src.add("        g_comboWanted[h] = want;\n");
        src.add("        if (g_comboClosed.find(h) == g_comboClosed.end()) {\n");
        src.add("            g_comboClosed[h] = c.DropDownClosed([h](auto const&, auto const&) {\n");
        src.add("                if (auto e = at(h)) { if (auto cc = e.try_as<winrt_controls::ComboBox>()) comboApply(cc, h); }\n");
        src.add("            });\n        }\n");
        src.add("        comboApply(c, h);\n    }\n\n");
        // The same two rules for every control that reports its own value, found
        // by the Farceur session on its audio tracks after the ComboBox: a
        // received tree set a switch and two sliders, and each reported the value
        // it was given as though a person had moved it. Nothing was lost that
        // time -- every echo carried what the engine had just sent -- but an echo
        // leaving for a slot's previous binding could unmute a microphone on air.
        //
        // - A value this runtime sets is not a user's edit. `g_setting` is raised
        //   around the setter, which covers the events WinUI raises inside it
        //   (Toggled, ValueChanged), and the value is also marked, which covers
        //   the one it raises later (TextChanged). Whichever catches it clears
        //   the mark, so a stale mark cannot swallow a later edit to that value.
        // - A value arriving while the user holds the control is not applied: a
        //   slider under the pointer, a text box with focus. The last one that
        //   arrived is applied when the interaction ends.
        src.add("    std::unordered_map<int, bool> g_setting;\n");
        src.add("    std::unordered_map<int, bool> g_boolMark;\n");
        src.add("    std::unordered_map<int, double> g_doubleMark;\n");
        src.add("    std::unordered_map<int, winrt::hstring> g_textMark;\n");
        src.add("    std::unordered_map<int, bool> g_holding;\n");
        src.add("    std::unordered_map<int, double> g_heldValue;\n");
        src.add("    std::unordered_map<int, winrt::hstring> g_heldText;\n");
        src.add("    std::unordered_map<int, bool> g_watched;\n\n");

        src.add("    bool runtimeBool(int h, bool v) {\n");
        src.add("        auto it = g_boolMark.find(h);\n");
        src.add("        bool marked = it != g_boolMark.end() && it->second == v;\n");
        src.add("        if (g_setting[h] || marked) { if (it != g_boolMark.end()) g_boolMark.erase(it); return true; }\n");
        src.add("        return false;\n    }\n\n");
        src.add("    bool runtimeDouble(int h, double v) {\n");
        src.add("        auto it = g_doubleMark.find(h);\n");
        src.add("        bool marked = it != g_doubleMark.end() && std::abs(it->second - v) < 1e-9;\n");
        src.add("        if (g_setting[h] || marked) { if (it != g_doubleMark.end()) g_doubleMark.erase(it); return true; }\n");
        src.add("        return false;\n    }\n\n");
        src.add("    bool runtimeText(int h, winrt::hstring const& v) {\n");
        src.add("        auto it = g_textMark.find(h);\n");
        src.add("        bool marked = it != g_textMark.end() && it->second == v;\n");
        src.add("        if (g_setting[h] || marked) { if (it != g_textMark.end()) g_textMark.erase(it); return true; }\n");
        src.add("        return false;\n    }\n\n");

        src.add("    void setToggle(winrt_controls::ToggleSwitch const& c, int h, bool v) {\n");
        src.add("        if (c.IsOn() == v) return;\n");
        src.add("        g_boolMark[h] = v;\n");
        src.add("        g_setting[h] = true; c.IsOn(v); g_setting[h] = false;\n    }\n\n");

        src.add("    void applySlider(winrt_controls::Slider const& c, int h, double v) {\n");
        src.add("        if (c.Value() == v) return;\n");
        src.add("        g_doubleMark[h] = v;\n");
        src.add("        g_setting[h] = true; c.Value(v); g_setting[h] = false;\n");
        src.add("        // The slider may have clamped or snapped it: mark what it holds.\n");
        src.add("        if (g_doubleMark.find(h) != g_doubleMark.end()) g_doubleMark[h] = c.Value();\n    }\n\n");
        src.add("    void releaseSlider(int h) {\n");
        src.add("        if (!g_holding[h]) return;\n");
        src.add("        g_holding[h] = false;\n");
        src.add("        auto held = g_heldValue.find(h);\n");
        src.add("        if (held == g_heldValue.end()) return;\n");
        src.add("        double v = held->second; g_heldValue.erase(held);\n");
        src.add("        if (auto e = at(h)) { if (auto s = e.try_as<winrt_controls::Slider>()) applySlider(s, h, v); }\n    }\n\n");
        src.add("    void setSlider(winrt_controls::Slider const& c, int h, double v) {\n");
        src.add("        if (!g_watched[h]) {\n");
        src.add("            g_watched[h] = true;\n");
        src.add("            // handledEventsToo: the slider's thumb handles the pointer itself.\n");
        src.add("            c.AddHandler(winrt_xaml::UIElement::PointerPressedEvent(), winrt::box_value(winrt_xaml::Input::PointerEventHandler(\n");
        src.add("                [h](auto const&, auto const&) { g_holding[h] = true; })), true);\n");
        src.add("            for (auto ended : { winrt_xaml::UIElement::PointerReleasedEvent(), winrt_xaml::UIElement::PointerCaptureLostEvent(), winrt_xaml::UIElement::PointerCanceledEvent() }) {\n");
        src.add("                c.AddHandler(ended, winrt::box_value(winrt_xaml::Input::PointerEventHandler(\n");
        src.add("                    [h](auto const&, auto const&) { releaseSlider(h); })), true);\n");
        src.add("            }\n        }\n");
        src.add("        if (g_holding[h]) { g_heldValue[h] = v; return; }\n");
        src.add("        applySlider(c, h, v);\n    }\n\n");

        src.add("    void applyTextBox(winrt_controls::TextBox const& c, int h, winrt::hstring const& v) {\n");
        src.add("        if (c.Text() == v) return;\n");
        src.add("        g_textMark[h] = v;\n");
        src.add("        g_setting[h] = true; c.Text(v); g_setting[h] = false;\n    }\n\n");
        src.add("    void setTextBox(winrt_controls::TextBox const& c, int h, winrt::hstring const& v) {\n");
        src.add("        if (!g_watched[h]) {\n");
        src.add("            g_watched[h] = true;\n");
        src.add("            c.LostFocus([h](auto const&, auto const&) {\n");
        src.add("                auto held = g_heldText.find(h);\n");
        src.add("                if (held == g_heldText.end()) return;\n");
        src.add("                winrt::hstring v = held->second; g_heldText.erase(held);\n");
        src.add("                if (auto e = at(h)) { if (auto t = e.try_as<winrt_controls::TextBox>()) applyTextBox(t, h, v); }\n");
        src.add("            });\n        }\n");
        src.add("        if (c.FocusState() != winrt_xaml::FocusState::Unfocused) { g_heldText[h] = v; return; }\n");
        src.add("        applyTextBox(c, h, v);\n    }\n\n");
        // An Image node: a Grid holding a WinUI Image and a TextBlock for its alt,
        // built on the first property and shown one or the other. A picture that
        // opens shows; one that fails, or a source this runtime cannot use
        // (refused:, blob:, anything unknown), shows the alt.
        src.add("    struct ImageParts { winrt_controls::Image image{ nullptr }; winrt_controls::TextBlock alt{ nullptr }; };\n");
        src.add("    std::unordered_map<int, ImageParts> g_images;\n\n");
        src.add("    void imageShow(ImageParts& p, bool picture) {\n");
        src.add("        p.image.Visibility(picture ? winrt_xaml::Visibility::Visible : winrt_xaml::Visibility::Collapsed);\n");
        src.add("        p.alt.Visibility(picture ? winrt_xaml::Visibility::Collapsed : winrt_xaml::Visibility::Visible);\n    }\n\n");
        src.add("    ImageParts& imageParts(winrt_controls::Grid const& g, int h) {\n");
        src.add("        auto& p = g_images[h];\n");
        src.add("        if (p.image) return p;\n");
        src.add("        p.image = winrt_controls::Image();\n");
        src.add("        p.image.Stretch(winrt::Microsoft::UI::Xaml::Media::Stretch::Uniform);\n");
        src.add("        p.alt = winrt_controls::TextBlock();\n");
        src.add("        p.alt.TextWrapping(winrt_xaml::TextWrapping::Wrap);\n");
        src.add("        p.alt.TextAlignment(winrt_xaml::TextAlignment::Center);\n");
        src.add("        p.alt.HorizontalAlignment(winrt_xaml::HorizontalAlignment::Center);\n");
        src.add("        p.alt.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);\n");
        src.add("        p.alt.FontSize(12);\n        p.alt.Opacity(0.6);\n");
        src.add("        g.Children().Append(p.image);\n        g.Children().Append(p.alt);\n");
        src.add("        p.image.ImageOpened([h](auto const&, auto const&) { auto it = g_images.find(h); if (it != g_images.end()) imageShow(it->second, true); });\n");
        src.add("        p.image.ImageFailed([h](auto const&, auto const&) { auto it = g_images.find(h); if (it != g_images.end()) imageShow(it->second, false); });\n");
        src.add("        imageShow(p, false);\n");
        src.add("        return p;\n    }\n\n");

        src.add("    bool startsWith(std::wstring const& s, std::wstring const& prefix) { return s.compare(0, prefix.size(), prefix) == 0; }\n\n");
        src.add("    std::wstring exeDirectory() {\n");
        src.add("        wchar_t buffer[MAX_PATH];\n");
        src.add("        DWORD n = GetModuleFileNameW(nullptr, buffer, MAX_PATH);\n");
        src.add("        std::wstring path(buffer, n);\n");
        src.add("        auto slash = path.find_last_of(L\"\\\\/\");\n");
        src.add("        return slash == std::wstring::npos ? L\".\" : path.substr(0, slash);\n    }\n\n");
        src.add("    std::wstring fileUri(std::wstring path) {\n");
        src.add("        for (auto& ch : path) if (ch == L'\\\\') ch = L'/';\n");
        src.add("        return L\"file:///\" + path;\n    }\n\n");
        // A data: picture: decoded here, checked by its own first bytes, written
        // to a temporary file named by its content, and opened from there -- the
        // one way to hand WinUI bytes without an asynchronous stream on the UI
        // thread.
        src.add("    bool decodeBase64(std::wstring const& text, std::vector<uint8_t>& out) {\n");
        src.add("        auto value = [](wchar_t c) -> int {\n");
        src.add("            if (c >= L'A' && c <= L'Z') return c - L'A';\n");
        src.add("            if (c >= L'a' && c <= L'z') return c - L'a' + 26;\n");
        src.add("            if (c >= L'0' && c <= L'9') return c - L'0' + 52;\n");
        src.add("            if (c == L'+') return 62;\n            if (c == L'/') return 63;\n            return -1;\n        };\n");
        src.add("        int bits = 0, acc = 0;\n");
        src.add("        for (wchar_t c : text) {\n");
        src.add("            if (c == L'=') break;\n");
        src.add("            int v = value(c);\n            if (v < 0) return false;\n");
        src.add("            acc = (acc << 6) | v; bits += 6;\n");
        src.add("            if (bits >= 8) { bits -= 8; out.push_back((uint8_t)((acc >> bits) & 0xFF)); }\n        }\n");
        src.add("        return true;\n    }\n\n");
        src.add("    bool pngOrJpeg(std::vector<uint8_t> const& b) {\n");
        src.add("        if (b.size() >= 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return true;\n");
        src.add("        return b.size() >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;\n    }\n\n");
        src.add("    std::wstring dataPictureFile(std::wstring const& src) {\n");
        src.add("        auto comma = src.find(L',');\n");
        src.add("        if (comma == std::wstring::npos) return L\"\";\n");
        src.add("        std::vector<uint8_t> bytes;\n");
        src.add("        if (!decodeBase64(src.substr(comma + 1), bytes) || !pngOrJpeg(bytes)) return L\"\";\n");
        src.add("        uint64_t hash = 1469598103934665603ULL;\n");
        src.add("        for (auto b : bytes) { hash ^= b; hash *= 1099511628211ULL; }\n");
        src.add("        wchar_t temp[MAX_PATH];\n");
        src.add("        DWORD n = GetTempPathW(MAX_PATH, temp);\n");
        src.add("        std::wstring dir = std::wstring(temp, n) + L\"wui-pictures\";\n");
        src.add("        CreateDirectoryW(dir.c_str(), nullptr);\n");
        src.add("        std::wstring file = dir + L\"\\\\\" + std::to_wstring(hash) + (bytes[0] == 0x89 ? L\".png\" : L\".jpg\");\n");
        src.add("        if (GetFileAttributesW(file.c_str()) == INVALID_FILE_ATTRIBUTES) {\n");
        src.add("            std::ofstream out(file, std::ios::binary);\n");
        src.add("            out.write((const char*)bytes.data(), (std::streamsize)bytes.size());\n        }\n");
        src.add("        return file;\n    }\n\n");

        src.add("    void imageSource(winrt_controls::Grid const& g, int h, winrt::hstring const& value) {\n");
        src.add("        auto& p = imageParts(g, h);\n");
        src.add("        std::wstring src(value.c_str());\n");
        src.add("        std::wstring uri;\n");
        src.add("        if (startsWith(src, L\"https://\") || startsWith(src, L\"file:///\")) {\n");
        src.add("            uri = src;\n");
        src.add("        } else if (startsWith(src, L\"asset:\")) {\n");
        src.add("            std::wstring path = src.substr(6);\n");
        src.add("            auto hash = path.find(L'#');\n");
        src.add("            if (hash != std::wstring::npos) path = path.substr(0, hash);\n");
        src.add("            uri = fileUri(exeDirectory() + L\"\\\\assets\\\\\" + path);\n");
        src.add("        } else if (startsWith(src, L\"data:image/png;base64,\") || startsWith(src, L\"data:image/jpeg;base64,\")) {\n");
        src.add("            std::wstring file = dataPictureFile(src);\n");
        src.add("            if (!file.empty()) uri = fileUri(file);\n        }\n");
        src.add("        if (uri.empty()) { p.image.Source(nullptr); imageShow(p, false); return; }\n");
        src.add("        try {\n");
        src.add("            winrt::Microsoft::UI::Xaml::Media::Imaging::BitmapImage bitmap;\n");
        src.add("            bitmap.UriSource(winrt::Windows::Foundation::Uri(uri));\n");
        src.add("            // Hidden until it opens: a picture still loading is not a failure.\n");
        src.add("            p.image.Visibility(winrt_xaml::Visibility::Collapsed);\n");
        src.add("            p.alt.Visibility(winrt_xaml::Visibility::Collapsed);\n");
        src.add("            p.image.Source(bitmap);\n");
        src.add("        } catch (...) { p.image.Source(nullptr); imageShow(p, false); }\n    }\n\n");
        src.add("    void imageAlt(winrt_controls::Grid const& g, int h, winrt::hstring const& value) {\n");
        src.add("        imageParts(g, h).alt.Text(value);\n    }\n\n");
        src.add("    void imageFit(winrt_controls::Grid const& g, int h, std::string const& fit) {\n");
        src.add("        auto& p = imageParts(g, h);\n");
        src.add("        namespace media = winrt::Microsoft::UI::Xaml::Media;\n");
        src.add("        p.image.Stretch(fit == \"cover\" ? media::Stretch::UniformToFill : fit == \"fill\" ? media::Stretch::Fill : media::Stretch::Uniform);\n    }\n\n");

        // The fonts this application ships, and what to ask WinUI for.
        //
        // A tree names a FAMILY; WinUI wants a FILE for a family nobody
        // installed -- "assets\fonts\Inter.ttf#Inter". Only a build can put the
        // two together, since the family's name is inside the file
        // (`nui.FontFile`), so the table is written here from what is in
        // assets/fonts. A name this application does not ship is handed to
        // WinUI as it stands: it may well be a family Windows has.
        src.add("    const std::unordered_map<std::wstring, std::wstring> g_fontFiles = {\n");
        for (face in shippedFaces()) {
            var family = face.family.toLowerCase();
            src.add('        { L"' + family + '", L"' + face.path + '#' + face.family + '" },\n');
        }
        src.add("    };\n\n");
        src.add("    std::wstring fontLower(std::wstring const& s) {\n");
        src.add("        std::wstring out = s;\n");
        src.add("        for (auto& c : out) c = (wchar_t)towlower(c);\n");
        src.add("        return out;\n    }\n\n");
        src.add("    void textFamily(winrt_controls::TextBlock const& c, winrt::hstring const& name) {\n");
        src.add("        if (name.empty()) return;\n");
        src.add("        auto found = g_fontFiles.find(fontLower(std::wstring(name.c_str())));\n");
        src.add("        auto asked = found == g_fontFiles.end() ? std::wstring(name.c_str()) : found->second;\n");
        src.add("        c.FontFamily(winrt::Microsoft::UI::Xaml::Media::FontFamily(winrt::hstring(asked)));\n    }\n\n");
        // Digits of one width. Typography is an attached property, so it is set
        // on the element rather than through a member of it.
        src.add("    void textNumerals(winrt_controls::TextBlock const& c, std::string const& said) {\n");
        src.add("        winrt::Microsoft::UI::Xaml::Documents::Typography::SetNumeralAlignment(c,\n");
        src.add("            said == \"tabular\"\n");
        src.add("                ? winrt::Microsoft::UI::Xaml::FontNumeralAlignment::Tabular\n");
        src.add("                : winrt::Microsoft::UI::Xaml::FontNumeralAlignment::Normal);\n    }\n\n");
        // A Button's content, composed: its text alone, or a glyph and its text
        // in a row, or the glyph alone -- and a UI Automation name, the text or
        // the icon's name. Recomposed only when one of the three changes, so a
        // re-render does not rebuild the button under the pointer.
        src.add("    struct ButtonParts { std::wstring label; std::wstring glyph; std::wstring iconName; bool composed = false; };\n");
        src.add("    std::unordered_map<int, ButtonParts> g_buttons;\n\n");
        src.add("    void buttonCompose(winrt_controls::Button const& c, int h) {\n");
        src.add("        auto& b = g_buttons[h];\n");
        src.add("        b.composed = true;\n");
        src.add("        if (b.glyph.empty()) {\n");
        src.add("            c.Content(winrt::box_value(winrt::hstring(b.label)));\n");
        src.add("        } else {\n");
        src.add("            winrt_controls::StackPanel row;\n");
        src.add("            row.Orientation(winrt_controls::Orientation::Horizontal);\n");
        src.add("            row.Spacing(8);\n");
        src.add("            winrt_controls::FontIcon icon;\n");
        src.add("            icon.FontFamily(winrt::Microsoft::UI::Xaml::Media::FontFamily(L\"Segoe Fluent Icons, Segoe MDL2 Assets\"));\n");
        src.add("            icon.Glyph(winrt::hstring(b.glyph));\n");
        src.add("            icon.FontSize(16);\n");
        src.add("            row.Children().Append(icon);\n");
        src.add("            if (!b.label.empty()) {\n");
        src.add("                winrt_controls::TextBlock text;\n");
        src.add("                text.Text(winrt::hstring(b.label));\n");
        src.add("                text.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);\n");
        src.add("                row.Children().Append(text);\n            }\n");
        src.add("            c.Content(row);\n        }\n");
        src.add("        winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetName(c, winrt::hstring(b.label.empty() ? b.iconName : b.label));\n    }\n\n");
        src.add("    void buttonLabel(winrt_controls::Button const& c, int h, winrt::hstring const& v) {\n");
        src.add("        auto& b = g_buttons[h];\n");
        src.add("        if (b.composed && b.label == v.c_str()) return;\n");
        src.add("        b.label = v.c_str();\n        buttonCompose(c, h);\n    }\n\n");
        src.add("    void buttonIcon(winrt_controls::Button const& c, int h, winrt::hstring const& v) {\n");
        src.add("        auto& b = g_buttons[h];\n");
        src.add("        if (b.composed && b.glyph == v.c_str()) return;\n");
        src.add("        b.glyph = v.c_str();\n        buttonCompose(c, h);\n    }\n\n");
        src.add("    void buttonIconName(winrt_controls::Button const& c, int h, winrt::hstring const& v) {\n");
        src.add("        auto& b = g_buttons[h];\n");
        src.add("        if (b.iconName == v.c_str()) return;\n");
        src.add("        b.iconName = v.c_str();\n");
        src.add("        if (b.composed && b.label.empty()) winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetName(c, v);\n    }\n");
        src.add("}\n\n");

        src.add("namespace wui { namespace nodes {\n");
        src.add("    // A root is an ordinary handle: appended, never index 0 by contract.\n");
        src.add("    // Clearing here is what this function exists to NOT do -- the old reset()\n");
        src.add("    // wiped every surface's controls to seat one window's root.\n");
        src.add("    int registerRoot(winrt_xaml::UIElement const& root) {\n");
        src.add("        return put(root);\n    }\n\n");
        src.add("    // One auxiliary window: a Window, a column root registered like any\n");
        src.add("    // other surface's, a Closed handler that names the handle back to Haxe.\n");
        src.add("    // Same UI thread as everything else -- WinUI 3's normal multi-window\n");
        src.add("    // shape, and the only thread hxcpp is attached to.\n");
        src.add("    int createWindow(const char* title) {\n");
        src.add("        winrt_xaml::Window window;\n");
        src.add("        window.Title(winrt::hstring(wui::runtime::fromUtf8(title)));\n");
        src.add("        winrt_controls::Grid root;\n");
        src.add("        root.Tag(winrt::box_value(L\"column\"));\n");
        src.add("        int handle = registerRoot(root);\n");
        src.add("        window.Content(root);\n");
        src.add("        // The handle crosses by value: the closure must not hold the window\n");
        src.add("        // (a window owning a handler owning the window is a cycle WinRT has\n");
        src.add("        // no collector to break -- the same rule as the sender lambdas below).\n");
        src.add("        window.Closed([handle](auto const&, auto const&) {\n");
        src.add("            wui_bridge_surface_closed(handle);\n        });\n");
        src.add("        g_windows.push_back(window);\n");
        src.add("        window.Activate();\n");
        src.add("        return handle;\n    }\n}}\n\n");

        // ---- create, from the declarations ----
        src.add("extern \"C\" int wui_node_create(const char* type, int parent) {\n");
        src.add("    std::string t(type);\n\n");
        src.add("    // Materialise, and nothing else -- no children, no mounting. WinUI can\n");
        src.add("    // honour that: a control exists before it has a parent, which is why\n");
        src.add("    // insert is a real operation here and not the no-op Silica forces.\n");
        for (type in wui.nui.Vocabulary.types()) {
            var winui = wui.nui.Vocabulary.winuiFor(type);
            if (winui == null) continue;

            src.add("    if (t == \"" + type + "\") {\n");
            src.add("        winrt_controls::" + winui + " c;\n");
            for (entry in wui.nui.Vocabulary.defaultsFor(type)) {
                // Escaped like every other splice: a declared default is still
                // a string landing inside a C++ literal -- and converted to an
                // hstring here rather than left as a narrow one. A member that
                // boxes its value (`Tag`, `Content`, `Header`) would otherwise
                // be handed a `char[4]`, and box_value on an array asks WinRT
                // for `IReference<char[4]>`: "T must be WinRT type", from inside
                // a generated header that names none of our files.
                //
                // Two forms, exactly as the runtime path passes two: the wide
                // one for members that take text, the narrow one for the enum
                // conversions, which compare against `std::string`.
                var narrow = entry.kind == "KString"
                    ? "\"" + UIBuilder.escapeWideString(entry.value) + "\"" : entry.value;
                var wide = entry.kind == "KString"
                    ? "winrt::hstring(wui::runtime::fromUtf8(" + narrow + "))" : entry.value;
                // A key applied by a helper has no call to emit here.
                //
                // `nodeSetter` answers those with the bare member name, which
                // in the edited path means only "this key is handled" -- the
                // statement itself comes from `reassertGuard`. This loop read
                // that marker as a call and wrote `c.FontItalic;`, a bare
                // expression, which MSVC rejects: *'FontItalic': is not a
                // member of TextBlock*. It stopped a clean clone from building
                // the Farceur pupitre at all.
                //
                // Only `FontItalic` has a declared default among them today,
                // which is why one key and not nine. Skipping is right rather
                // than merely convenient: those helpers read the runtime's own
                // parameters and some need the node's handle, neither of which
                // exists while the control is being materialised -- and every
                // default in that list is the platform's own (upright text,
                // ordinary numerals). If one ever is not, the place to apply it
                // is the helper, not a second spelling here.
                if (appliedByHelper(entry.winrt)) continue;

                var call = nodeSetter(entry.winrt, entry.kind, wide, narrow);
                if (call == null) continue;

                src.add("        c." + call + ";\n");
            }
            src.add("        return put(c);\n    }\n");
        }
        // A registered native component (vui): after the declared controls, so a
        // component can never shadow one, and before the unknown fallback, which
        // is exactly the "?LevelMeter" a panel used to draw.
        src.add("\n    if (auto comp = wui::components::find(t)) {\n");
        src.add("        if (comp->create) {\n");
        src.add("            auto element = comp->create();\n");
        src.add("            if (element) {\n");
        src.add("                // Put as is, never wrapped: the component recognises its\n");
        src.add("                // element when the same object comes back to prop_* and destroy.\n");
        src.add("                int handle = put(element);\n");
        src.add("                g_componentOf[handle] = comp;\n");
        src.add("                return handle;\n            }\n        }\n    }\n");
        src.add("\n    // An unknown type is shown, not swallowed: a tree that cannot render\n");
        src.add("    // should say so rather than leave a hole nobody can explain.\n");
        src.add("    winrt_controls::TextBlock unknown;\n");
        src.add("    unknown.Text(winrt::hstring(L\"?\" + wui::runtime::fromUtf8(type)));\n");
        src.add("    return put(unknown);\n}\n\n");

        // ---- one setter function per kind, branches from the declarations ----
        for (kind in ["KString", "KInt", "KFloat", "KBool"]) {
            var fn = switch (kind) {
                case "KString": "string"; case "KInt": "int";
                case "KFloat": "float"; case _: "bool";
            };
            var cty = switch (kind) {
                case "KString": "const char*"; case "KInt": "int";
                case "KFloat": "double"; case _: "bool";
            };
            src.add("extern \"C\" void wui_node_prop_" + fn + "(int h, const char* type, const char* key, " + cty + " value) {\n");
            src.add("    auto e = at(h);\n    if (e == nullptr) return;\n");
            src.add("    std::string t(type);\n    std::string k(key);\n");
            // A component takes its own keys first. What it leaves -- a margin, a
            // background, visibility -- continues as its host type, so the setters
            // generated below still apply: they match on the type, and nothing is
            // declared for "LevelMeter".
            var member = switch (kind) {
                case "KString": "propString"; case "KInt": "propInt";
                case "KFloat": "propFloat"; case _: "propBool";
            };
            src.add("    if (auto comp = wui::components::find(t)) {\n");
            src.add("        if (comp->" + member + " && comp->" + member + "(e, key, value)) return;\n");
            src.add("        t = comp->hostType ? comp->hostType : \"\";\n    }\n");
            if (kind == "KString") src.add("    auto text = winrt::hstring(wui::runtime::fromUtf8(value));\n");
            src.add("\n");

            // The one hand-written property: an accelerator is not a member a
            // generated setter could call -- it becomes a KeyboardAccelerator
            // (two enums, appended to a collection). The chord GRAMMAR lives in
            // Haxe (wui.mui.Chords), where a test pins it without a Windows
            // machine; what crosses is one packed int, unpacked here. Undeclared
            // on purpose: a @:winrt declaration would emit `c.Accelerator(...)`
            // and MSVC would rightly refuse the member.
            if (kind == "KInt") {
                src.add("    if (t == \"MenuFlyoutItem\" && k == \"accelerator\") {\n");
                src.add("        if (auto m = e.try_as<winrt_controls::MenuFlyoutItem>()) {\n");
                src.add("            // Replace, never accumulate: a re-render re-applies the prop,\n");
                src.add("            // and two identical accelerators would both fire the click.\n");
                src.add("            m.KeyboardAccelerators().Clear();\n");
                src.add("            winrt::Microsoft::UI::Xaml::Input::KeyboardAccelerator a;\n");
                src.add("            a.Key((winrt::Windows::System::VirtualKey)(value & 0xFFFF));\n");
                src.add("            a.Modifiers((winrt::Windows::System::VirtualKeyModifiers)(value >> 16));\n");
                src.add("            m.KeyboardAccelerators().Append(a);\n");
                src.add("        }\n        return;\n    }\n\n");
            }

            for (type in wui.nui.Vocabulary.types()) {
                var winui = wui.nui.Vocabulary.winuiFor(type);
                if (winui == null) continue;

                for (entry in wui.nui.Vocabulary.propsFor(type)) {
                    var valueExpr = incoming(kind, entry.kind);
                    if (valueExpr == null) continue;
                    var call = nodeSetter(entry.winrt, entry.kind, "text", valueExpr);
                    if (call == null) continue;

                    // Emit against the concrete control and let MSVC check it has
                    // the member. That is what replaced the owner table: a
                    // hand-kept list of which WinRT type declares what, already
                    // wrong about Panel, and failing in silence when it was.
                    // A string is compared as the hstring the setter applies,
                    // not as the raw `const char*` it arrived as.
                    var statement = reassertGuard(entry.winrt, entry.kind == "KString" ? "text" : valueExpr, call, winui);
                    src.add("    if (t == \"" + type + "\" && k == \"" + entry.name + "\") {\n");
                    src.add("        if (auto c = e.try_as<winrt_controls::" + winui + ">()) { " + statement + " }\n");
                    src.add("        return;\n    }\n");
                }
            }
            src.add("}\n\n");
        }

        // ---- the rest: unchanged, and not derivable ----
        src.add("extern \"C\" void wui_node_prop_callback(int h, const char* type, const char* key, int callbackId) {\n");
        src.add("    auto e = at(h);\n    if (e == nullptr) return;\n");
        src.add("    std::string k(key);\n\n");
        src.add("    if (k == \"onClick\") {\n");
        src.add("        if (auto b = e.try_as<winrt_controls::Button>()) {\n");
        src.add("            if (g_clickTokens[h].value != 0) { b.Click(g_clickTokens[h]); }\n");
        src.add("            g_clickTokens[h] = b.Click([callbackId](winrt::Windows::Foundation::IInspectable const&,\n");
        src.add("                                                   winrt_xaml::RoutedEventArgs const&) {\n");
        src.add("                wui_bridge_invoke_node(callbackId);\n            });\n            return;\n        }\n");
        src.add("        // A menu command clicks the same way a Button does: same token slot\n");
        src.add("        // (one node is one control, never both), same id over the bridge.\n");
        src.add("        if (auto mi = e.try_as<winrt_controls::MenuFlyoutItem>()) {\n");
        src.add("            if (g_clickTokens[h].value != 0) { mi.Click(g_clickTokens[h]); }\n");
        src.add("            g_clickTokens[h] = mi.Click([callbackId](winrt::Windows::Foundation::IInspectable const&,\n");
        src.add("                                                    winrt_xaml::RoutedEventArgs const&) {\n");
        src.add("                wui_bridge_invoke_node(callbackId);\n            });\n        }\n        return;\n    }\n\n");

        // The value the handler reports is read off the **sender**, never off a
        // captured control. Capturing would make the control own a handler that
        // owns the control, which is a reference cycle WinRT has no collector to
        // break; the sender is the same object, handed over for free.
        //
        // The lambdas take `auto const&` so the delegate types stay out of this
        // file. Naming them would drag in headers per control and buy nothing:
        // the compiler still checks the call.
        src.add("    // Each control reports through the one event that carries its value.\n");
        src.add("    if (k == \"onToggle\") {\n");
        src.add("        if (auto c = e.try_as<winrt_controls::ToggleSwitch>()) {\n");
        src.add("            if (g_valueTokens[h].value != 0) { c.Toggled(g_valueTokens[h]); }\n");
        src.add("            g_valueTokens[h] = c.Toggled([callbackId, h](auto const& sender, auto const&) {\n");
        src.add("                if (auto s = sender.template try_as<winrt_controls::ToggleSwitch>()) {\n");
        src.add("                    if (runtimeBool(h, s.IsOn())) return;\n");
        src.add("                    wui_bridge_invoke_node_bool(callbackId, s.IsOn());\n                }\n");
        src.add("            });\n        }\n        return;\n    }\n\n");

        src.add("    if (k == \"onText\") {\n");
        src.add("        if (auto c = e.try_as<winrt_controls::TextBox>()) {\n");
        src.add("            if (g_valueTokens[h].value != 0) { c.TextChanged(g_valueTokens[h]); }\n");
        src.add("            g_valueTokens[h] = c.TextChanged([callbackId, h](auto const& sender, auto const&) {\n");
        src.add("                if (auto s = sender.template try_as<winrt_controls::TextBox>()) {\n");
        src.add("                    if (runtimeText(h, s.Text())) return;\n");
        src.add("                    wui_bridge_invoke_node_string(callbackId, winrt::to_string(s.Text()).c_str());\n                }\n");
        src.add("            });\n        }\n        return;\n    }\n\n");

        src.add("    if (k == \"onSecret\") {\n");
        src.add("        if (auto c = e.try_as<winrt_controls::PasswordBox>()) {\n");
        src.add("            if (g_keyTokens[h].value != 0) { c.KeyDown(g_keyTokens[h]); }\n");
        // A secret is reported ONCE, on submission, and never per keystroke:
        // `PasswordChanged` is deliberately not wired. The field is cleared
        // straight afterwards, so a second Enter reports an empty string rather
        // than the same secret again -- the rule nui's canon states, and the
        // same one `pui.ui.SecretInput` follows.
        src.add("            g_keyTokens[h] = c.KeyDown([callbackId, h](auto const& sender, auto const& args) {\n");
        src.add("                if (args.Key() != winrt::Windows::System::VirtualKey::Enter) return;\n");
        src.add("                auto s = sender.template try_as<winrt_controls::PasswordBox>();\n");
        src.add("                if (s == nullptr) return;\n");
        src.add("                auto value = winrt::to_string(s.Password());\n");
        src.add("                g_setting[h] = true; s.Password(L\"\"); g_setting[h] = false;\n");
        src.add("                wui_bridge_invoke_node_string(callbackId, value.c_str());\n");
        src.add("            });\n        }\n        return;\n    }\n\n");

        src.add("    if (k == \"onValue\") {\n");
        src.add("        if (auto c = e.try_as<winrt_controls::Slider>()) {\n");
        src.add("            if (g_valueTokens[h].value != 0) { c.ValueChanged(g_valueTokens[h]); }\n");
        src.add("            g_valueTokens[h] = c.ValueChanged([callbackId, h](auto const& sender, auto const&) {\n");
        src.add("                if (auto s = sender.template try_as<winrt_controls::Slider>()) {\n");
        src.add("                    if (runtimeDouble(h, s.Value())) return;\n");
        src.add("                    wui_bridge_invoke_node_float(callbackId, s.Value());\n                }\n");
        src.add("            });\n        }\n        return;\n    }\n\n");

        // A selection reports the **index**, not the item. Haxe describes a list
        // of sections and knows them by position; handing back an opaque WinRT
        // object would make the application look one up in a collection it never
        // built. Both controls select by item and both are asked where that item
        // sits, which is the translation the setter does in the other direction.
        src.add("    if (k == \"onSelect\") {\n");
        src.add("        if (auto nav = e.try_as<winrt_controls::NavigationView>()) {\n");
        src.add("            if (g_valueTokens[h].value != 0) { nav.SelectionChanged(g_valueTokens[h]); }\n");
        src.add("            g_valueTokens[h] = nav.SelectionChanged([callbackId](auto const& sender, auto const& args) {\n");
        src.add("                auto n = sender.template try_as<winrt_controls::NavigationView>();\n");
        src.add("                if (n == nullptr) return;\n");
        src.add("                uint32_t index = 0;\n");
        src.add("                if (n.MenuItems().IndexOf(args.SelectedItem(), index)) {\n");
        src.add("                    wui_bridge_invoke_node_int(callbackId, (int)index);\n                }\n");
        src.add("            });\n            return;\n        }\n");
        // A ComboBox reports its own SelectedIndex. -1 is not a choice -- it is
        // the list emptied or an item removed under the selection -- so it is
        // not reported: nobody picked "nothing".
        src.add("        if (auto combo = e.try_as<winrt_controls::ComboBox>()) {\n");
        src.add("            if (g_valueTokens[h].value != 0) { combo.SelectionChanged(g_valueTokens[h]); }\n");
        src.add("            g_valueTokens[h] = combo.SelectionChanged([callbackId, h](auto const& sender, auto const&) {\n");
        src.add("                auto b = sender.template try_as<winrt_controls::ComboBox>();\n");
        src.add("                if (b == nullptr) return;\n");
        src.add("                int index = b.SelectedIndex();\n");
        src.add("                if (comboProgrammatic(h, index)) return;\n");
        src.add("                if (index < 0) return;\n");
        src.add("                g_comboWanted[h] = index;\n");
        src.add("                wui_bridge_invoke_node_int(callbackId, index);\n");
        src.add("            });\n            return;\n        }\n");
        src.add("        if (auto tabs = e.try_as<winrt_controls::TabView>()) {\n");
        src.add("            if (g_valueTokens[h].value != 0) { tabs.SelectionChanged(g_valueTokens[h]); }\n");
        src.add("            g_valueTokens[h] = tabs.SelectionChanged([callbackId, h](auto const& sender, auto const&) {\n");
        src.add("                auto b = sender.template try_as<winrt_controls::TabView>();\n");
        src.add("                if (b == nullptr) return;\n");
        src.add("                int index = b.SelectedIndex();\n");
        src.add("                if (tabProgrammatic(h, index)) return;\n");
        src.add("                if (index < 0) return;\n");
        src.add("                g_tabWanted[h] = index;\n");
        src.add("                wui_bridge_invoke_node_int(callbackId, index);\n");
        src.add("            });\n            return;\n        }\n");
        src.add("        if (auto bar = e.try_as<winrt_controls::SelectorBar>()) {\n");
        src.add("            if (g_valueTokens[h].value != 0) { bar.SelectionChanged(g_valueTokens[h]); }\n");
        src.add("            g_valueTokens[h] = bar.SelectionChanged([callbackId](auto const& sender, auto const&) {\n");
        src.add("                auto b = sender.template try_as<winrt_controls::SelectorBar>();\n");
        src.add("                if (b == nullptr) return;\n");
        src.add("                uint32_t index = 0;\n");
        src.add("                if (b.Items().IndexOf(b.SelectedItem(), index)) {\n");
        src.add("                    wui_bridge_invoke_node_int(callbackId, (int)index);\n                }\n");
        src.add("            });\n            return;\n        }\n        return;\n    }\n\n");

        src.add("    OutputDebugStringA(\"[wui] callback ignored: no event on this control reports it\\n\");\n}\n\n");

        src.add("extern \"C\" void wui_node_modifier(int h, const char* type, const char* modType, double f0, const char* s0) {\n");
        src.add("    // nui keeps an ordered modifier chain; wui has declared properties. A\n");
        src.add("    // colour is the same thing under two names, so it is routed rather than\n");
        src.add("    // reported: `backgroundColor` IS `Background`, and the node path already\n");
        src.add("    // knows how to set that on whatever control this handle holds.\n");
        src.add("    //\n");
        src.add("    // Everything below ignored the chain entirely, and said so to the\n");
        src.add("    // debugger. So a TAKE button carrying `backgroundColor: role:accent`\n");
        src.add("    // stayed grey, and `brushFromRole` -- written, correct, tested as text --\n");
        src.add("    // was never called for a view. Found on Windows by the Farceur session.\n");
        src.add("    std::string kind(modType == nullptr ? \"\" : modType);\n");
        src.add("    if (kind == \"backgroundColor\") { wui_node_prop_string(h, type, \"background\", s0); return; }\n");
        src.add("    if (kind == \"foregroundColor\") { wui_node_prop_string(h, type, \"foregroundColor\", s0); return; }\n");
        src.add("    if (kind == \"border\") { wui_node_prop_string(h, type, \"borderBrush\", s0); return; }\n");
        // Not a property under another name, like the three above: WinUI has
        // nothing to route this to. See `clipToBounds`.
        src.add("    if (kind == \"clip\") {\n");
        src.add("        auto e = at(h);\n");
        src.add("        if (e == nullptr) return;\n");
        src.add("        if (auto fe = e.try_as<winrt_xaml::FrameworkElement>()) clipToBounds(fe, h);\n");
        src.add("        return;\n    }\n");
        src.add("    (void)f0;\n");
        src.add("    OutputDebugStringA((\"[wui] modifier ignored: \" + kind + \"\\n\").c_str());\n}\n\n");

        // A parent holds its children in whichever place its own WinRT type
        // provides, and there are four such places -- not one. Handling only
        // `Panel` and returning silently for the rest is what drew the kitchen
        // sink as a lone "+": a TabView keeps its pages in `TabItems`, so every
        // tab was dropped, and WinUI renders a TabView with no items as nothing
        // but its add-tab button. A ScrollViewer and a Border lost their content
        // the same way, one level further down.
        src.add("extern \"C\" void wui_node_insert(int parent, int child, int index) {\n");
        src.add("    auto p = at(parent);\n    auto c = at(child);\n");
        src.add("    if (p == nullptr || c == nullptr) return;\n\n");
        // A row is a Grid, and its children go into columns rather than into a
        // queue. That is the whole of what makes a spacer work: a StackPanel
        // hands every child the size it asks for and has no leftover room to
        // give away, so an empty Border between two labels came out zero wide.
        // Sized `Auto` for real content and `*` for a spacer, the spacers share
        // whatever the row does not use.
        src.add("    if (auto grid = p.try_as<winrt_controls::Grid>()) {\n");
        src.add("        if (tagText(p) == L\"row\") {\n");
        src.add("            auto fe = c.try_as<winrt_xaml::FrameworkElement>();\n");
        src.add("            winrt_controls::ColumnDefinition column;\n");
        src.add("            column.Width(tagText(c) == L\"spacer\"\n");
        src.add("                ? winrt_xaml::GridLength{ 1.0, winrt_xaml::GridUnitType::Star }\n");
        src.add("                : winrt_xaml::GridLength{ 0.0, winrt_xaml::GridUnitType::Auto });\n\n");
        src.add("            uint32_t column_index = grid.ColumnDefinitions().Size();\n");
        src.add("            grid.ColumnDefinitions().Append(column);\n");
        src.add("            grid.Children().Append(c);\n");
        src.add("            if (fe != nullptr) winrt_controls::Grid::SetColumn(fe, (int)column_index);\n");
        src.add("            return;\n        }\n    }\n\n");

        // A surface's root is a column: a Grid with a row per child, `Auto` for
        // content and `*` for a ScrollViewer. It used to be a vertical
        // StackPanel, which measures its children with an unbounded height --
        // and a ScrollViewer given all the height it asks for has nothing to
        // scroll. A received tree taller than the window was cut off.
        //
        // Only a surface's root is a column. Making every `VStack` one, so a
        // nested ScrollView would scroll, drew the Farceur pupitre entirely
        // black -- laid out, every rectangle sane, nothing painted -- and was
        // put back the same day. See `wui.ui.VStack`.
        src.add("    if (auto grid = p.try_as<winrt_controls::Grid>()) {\n");
        src.add("        if (tagText(p) == L\"column\") {\n");
        src.add("            winrt_controls::RowDefinition row;\n");
        src.add("            bool share = c.try_as<winrt_controls::ScrollViewer>() != nullptr;\n");
        src.add("            row.Height(share\n");
        src.add("                ? winrt_xaml::GridLength{ 1.0, winrt_xaml::GridUnitType::Star }\n");
        src.add("                : winrt_xaml::GridLength{ 0.0, winrt_xaml::GridUnitType::Auto });\n");
        src.add("            uint32_t n = grid.Children().Size();\n");
        src.add("            uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("            if (i > n) i = n;\n");
        src.add("            grid.RowDefinitions().InsertAt(i, row);\n");
        src.add("            grid.Children().InsertAt(i, c);\n");
        src.add("            columnRenumber(grid, i);\n");
        src.add("            return;\n        }\n    }\n\n");

        src.add("    // A panel is the only shape with an ordered list, so it is the only\n");
        src.add("    // one that can honour `index`. WinUI can place a child at a chosen\n");
        src.add("    // position; Silica cannot -- its positioners append -- which is why\n");
        src.add("    // the contract keeps this parameter rather than dropping it for its\n");
        src.add("    // first adopter.\n");
        src.add("    if (auto panel = p.try_as<winrt_controls::Panel>()) {\n");
        src.add("        uint32_t n = panel.Children().Size();\n");
        src.add("        uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("        if (i > n) i = n;\n");
        src.add("        panel.Children().InsertAt(i, c);\n        return;\n    }\n\n");
        src.add("    if (auto tabs = p.try_as<winrt_controls::TabView>()) {\n");
        src.add("        uint32_t n = tabs.TabItems().Size();\n");
        src.add("        uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("        if (i > n) i = n;\n");
        src.add("        tabs.TabItems().InsertAt(i, c);\n");
        src.add("        tabApply(tabs, parent);\n        return;\n    }\n\n");
        // A NavigationView takes its children in two different places, and which
        // one is decided by the child's own type: the pane holds the items, the
        // Content holds the one section showing. That is the difference between
        // it and a TabView, where every content is present at once because every
        // item carries one.
        src.add("    if (auto nav = p.try_as<winrt_controls::NavigationView>()) {\n");
        src.add("        if (auto item = c.try_as<winrt_controls::NavigationViewItem>()) {\n");
        src.add("            uint32_t n = nav.MenuItems().Size();\n");
        src.add("            uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("            if (i > n) i = n;\n");
        src.add("            nav.MenuItems().InsertAt(i, item);\n        } else {\n");
        src.add("            nav.Content(c);\n        }\n        return;\n    }\n\n");

        // A ComboBox holds its options in Items, and only ComboBoxItems: a bare
        // element would be needed in the list and in the selection box at once.
        // An insert may be what makes a wanted index valid, so it is retried.
        src.add("    if (auto combo = p.try_as<winrt_controls::ComboBox>()) {\n");
        src.add("        if (auto item = c.try_as<winrt_controls::ComboBoxItem>()) {\n");
        src.add("            uint32_t n = combo.Items().Size();\n");
        src.add("            uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("            if (i > n) i = n;\n");
        src.add("            combo.Items().InsertAt(i, item);\n");
        src.add("            comboApply(combo, parent);\n        } else {\n");
        src.add("            OutputDebugStringA(\"[wui] insert: a ComboBox holds ComboBoxItems only\\n\");\n        }\n");
        src.add("        return;\n    }\n\n");

        src.add("    if (auto bar = p.try_as<winrt_controls::SelectorBar>()) {\n");
        src.add("        if (auto item = c.try_as<winrt_controls::SelectorBarItem>()) {\n");
        src.add("            uint32_t n = bar.Items().Size();\n");
        src.add("            uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("            if (i > n) i = n;\n");
        src.add("            bar.Items().InsertAt(i, item);\n        }\n        return;\n    }\n\n");

        // Places five and six: a MenuBar holds MenuBarItems and a MenuBarItem
        // holds flyout items -- typed vectors both, not a Panel's children.
        // The MenuBarItem branch must sit BEFORE any generic fallback: it is a
        // Control, and a fallback that boxed it as content would swallow it.
        src.add("    if (auto menubar = p.try_as<winrt_controls::MenuBar>()) {\n");
        src.add("        if (auto item = c.try_as<winrt_controls::MenuBarItem>()) {\n");
        src.add("            uint32_t n = menubar.Items().Size();\n");
        src.add("            uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("            if (i > n) i = n;\n");
        src.add("            menubar.Items().InsertAt(i, item);\n        }\n        return;\n    }\n\n");
        src.add("    if (auto menu = p.try_as<winrt_controls::MenuBarItem>()) {\n");
        src.add("        if (auto item = c.try_as<winrt_controls::MenuFlyoutItemBase>()) {\n");
        src.add("            uint32_t n = menu.Items().Size();\n");
        src.add("            uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("            if (i > n) i = n;\n");
        src.add("            menu.Items().InsertAt(i, item);\n        }\n        return;\n    }\n\n");

        // A ScrollViewer holds one content, and a canonical ScrollView has
        // children, as many as mui's contract gives it. They go into a vertical
        // StackPanel made the first time one arrives and tagged so it is never
        // mistaken for a child's own. Before the ContentControl fallback, which
        // a ScrollViewer also is: there, each child replaced the last.
        src.add("    if (auto scroll = p.try_as<winrt_controls::ScrollViewer>()) {\n");
        src.add("        auto column = scrollColumn(scroll, true);\n");
        src.add("        uint32_t n = column.Children().Size();\n");
        src.add("        uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("        if (i > n) i = n;\n");
        src.add("        column.Children().InsertAt(i, c);\n        return;\n    }\n\n");
        src.add("    // Single-content containers: there is nothing for `index` to order,\n");
        src.add("    // and a second child replaces the first rather than joining it.\n");
        src.add("    if (auto border = p.try_as<winrt_controls::Border>()) { border.Child(c); return; }\n");
        src.add("    if (auto holder = p.try_as<winrt_controls::ContentControl>()) { holder.Content(c); return; }\n\n");
        src.add("    OutputDebugStringA(\"[wui] insert: this parent has nowhere to put a child\\n\");\n}\n\n");

        src.add("extern \"C\" void wui_node_remove(int parent, int child) {\n");
        src.add("    auto p = at(parent);\n    auto c = at(child);\n");
        src.add("    if (p == nullptr || c == nullptr) return;\n\n");
        // A row loses a column with the child that occupied it, and the ones
        // after it move up. Leaving the column behind would keep its share of
        // the width reserved for a control that is gone.
        src.add("    if (auto grid = p.try_as<winrt_controls::Grid>()) {\n");
        src.add("        if (tagText(p) == L\"row\") {\n");
        src.add("            uint32_t index = 0;\n");
        src.add("            if (grid.Children().IndexOf(c, index)) {\n");
        src.add("                grid.Children().RemoveAt(index);\n");
        src.add("                if (index < grid.ColumnDefinitions().Size()) grid.ColumnDefinitions().RemoveAt(index);\n");
        src.add("                for (uint32_t i = index; i < grid.Children().Size(); ++i) {\n");
        src.add("                    if (auto moved = grid.Children().GetAt(i).try_as<winrt_xaml::FrameworkElement>())\n");
        src.add("                        winrt_controls::Grid::SetColumn(moved, (int)i);\n                }\n            }\n");
        src.add("            return;\n        }\n    }\n\n");

        src.add("    if (auto grid = p.try_as<winrt_controls::Grid>()) {\n");
        src.add("        if (tagText(p) == L\"column\") {\n");
        src.add("            uint32_t index = 0;\n");
        src.add("            if (grid.Children().IndexOf(c, index)) {\n");
        src.add("                grid.Children().RemoveAt(index);\n");
        src.add("                if (index < grid.RowDefinitions().Size()) grid.RowDefinitions().RemoveAt(index);\n");
        src.add("                columnRenumber(grid, index);\n            }\n");
        src.add("            return;\n        }\n    }\n\n");
        src.add("    if (auto scroll = p.try_as<winrt_controls::ScrollViewer>()) {\n");
        src.add("        if (auto column = scrollColumn(scroll, false)) {\n");
        src.add("            uint32_t index = 0;\n");
        src.add("            if (column.Children().IndexOf(c, index)) column.Children().RemoveAt(index);\n        }\n");
        src.add("        return;\n    }\n\n");

        src.add("    if (auto panel = p.try_as<winrt_controls::Panel>()) {\n");
        src.add("        uint32_t index = 0;\n");
        src.add("        if (panel.Children().IndexOf(c, index)) panel.Children().RemoveAt(index);\n");
        src.add("        return;\n    }\n\n");
        src.add("    if (auto tabs = p.try_as<winrt_controls::TabView>()) {\n");
        src.add("        uint32_t index = 0;\n");
        src.add("        if (tabs.TabItems().IndexOf(c, index)) tabs.TabItems().RemoveAt(index);\n");
        src.add("        return;\n    }\n\n");
        src.add("    if (auto nav = p.try_as<winrt_controls::NavigationView>()) {\n");
        src.add("        if (auto item = c.try_as<winrt_controls::NavigationViewItem>()) {\n");
        src.add("            uint32_t index = 0;\n");
        src.add("            if (nav.MenuItems().IndexOf(item, index)) nav.MenuItems().RemoveAt(index);\n");
        src.add("        } else if (nav.Content() == c) {\n            nav.Content(nullptr);\n        }\n");
        src.add("        return;\n    }\n\n");

        src.add("    if (auto combo = p.try_as<winrt_controls::ComboBox>()) {\n");
        src.add("        uint32_t index = 0;\n");
        src.add("        if (combo.Items().IndexOf(c, index)) combo.Items().RemoveAt(index);\n");
        src.add("        return;\n    }\n\n");

        src.add("    if (auto bar = p.try_as<winrt_controls::SelectorBar>()) {\n");
        src.add("        if (auto item = c.try_as<winrt_controls::SelectorBarItem>()) {\n");
        src.add("            uint32_t index = 0;\n");
        src.add("            if (bar.Items().IndexOf(item, index)) bar.Items().RemoveAt(index);\n        }\n");
        src.add("        return;\n    }\n\n");

        src.add("    if (auto menubar = p.try_as<winrt_controls::MenuBar>()) {\n");
        src.add("        if (auto item = c.try_as<winrt_controls::MenuBarItem>()) {\n");
        src.add("            uint32_t index = 0;\n");
        src.add("            if (menubar.Items().IndexOf(item, index)) menubar.Items().RemoveAt(index);\n        }\n");
        src.add("        return;\n    }\n\n");
        src.add("    if (auto menu = p.try_as<winrt_controls::MenuBarItem>()) {\n");
        src.add("        if (auto item = c.try_as<winrt_controls::MenuFlyoutItemBase>()) {\n");
        src.add("            uint32_t index = 0;\n");
        src.add("            if (menu.Items().IndexOf(item, index)) menu.Items().RemoveAt(index);\n        }\n");
        src.add("        return;\n    }\n\n");

        src.add("    // Emptied rather than searched: a single-content container holds this\n");
        src.add("    // child or it holds nothing, and clearing one it does not hold would\n");
        src.add("    // throw away a sibling that is still on screen.\n");
        src.add("    if (auto border = p.try_as<winrt_controls::Border>()) {\n");
        src.add("        if (border.Child() == c) border.Child(nullptr);\n        return;\n    }\n\n");
        src.add("    if (auto holder = p.try_as<winrt_controls::ContentControl>()) {\n");
        src.add("        if (holder.Content() == c) holder.Content(nullptr);\n        return;\n    }\n}\n\n");

        src.add("extern \"C\" void wui_node_destroy(int h) {\n");
        src.add("    // h < 0, not h <= 0: handle 0 stopped being \"the root\" when roots became\n");
        src.add("    // registered handles. Roots are still never destroyed -- but by who calls\n");
        src.add("    // (the reconciler only destroys handles it created), not by a magic index.\n");
        src.add("    if (h < 0 || h >= (int)g_nodes.size()) return;\n");
        src.add("    // A real release, not a hide. Dropping the last reference frees a WinRT\n");
        src.add("    // control -- unlike Silica, where destroy can only set visible = false.\n");
        src.add("    // Both token slots, not just clicks: a value subscription kept alive on a\n");
        src.add("    // freed slot was a leak the single-token line quietly had.\n");
        src.add("    g_clickTokens[h] = winrt::event_token{};\n");
        src.add("    g_valueTokens[h] = winrt::event_token{};\n");
        src.add("    // A component is told before its element is released, with the same\n");
        src.add("    // object it made.\n");
        src.add("    auto owner = g_componentOf.find(h);\n");
        src.add("    if (owner != g_componentOf.end()) {\n");
        src.add("        if (owner->second->destroy && g_nodes[h]) owner->second->destroy(g_nodes[h]);\n");
        src.add("        g_componentOf.erase(owner);\n    }\n");
        src.add("    g_nodes[h] = nullptr;\n}\n\n");

        src.add("extern \"C\" bool wui_node_knows(const char* type) {\n");
        src.add("    std::string t(type);\n");
        for (type in wui.nui.Vocabulary.types()) {
            if (wui.nui.Vocabulary.winuiFor(type) == null) continue;
            src.add("    if (t == \"" + type + "\") return true;\n");
        }
        src.add("    return wui::components::find(t) != nullptr;\n}\n");

        ProjectGenerator.writeIfChanged(Path.join([outputDir, "WuiNodes.cpp"]), src.toString());
    }

    /**
        A named typographic step, as a size. The table is the one the previous
        hand-written translation used, kept rather than reinvented.
    **/
    /**
        The font files this application ships, as their own tables describe them.

        Read here because only a build can: the family's name lives inside the
        file, and the node runtime needs a table from a name to a file. A file
        that is not a font this can read is passed over -- a directory is not a
        manifest.
    **/
    static function shippedFaces():Array<{path:String, family:String}> {
        var out = [];
        var where = "assets/fonts";
        if (!FileSystem.exists(where) || !FileSystem.isDirectory(where)) return out;
        var names = FileSystem.readDirectory(where);
        names.sort(Reflect.compare);
        for (name in names) {
            var path = where + "/" + name;
            if (FileSystem.isDirectory(path)) continue;
            var lower = name.toLowerCase();
            if (!StringTools.endsWith(lower, ".ttf") && !StringTools.endsWith(lower, ".otf")) continue;
            var face = nui.FontFile.read(try File.getBytes(path) catch (_:Dynamic) null);
            if (face == null) continue;
            // Backslashes, and doubled: this ends up inside a C++ string.
            out.push({path: "assets\\\\fonts\\\\" + name, family: face.family});
        }
        return out;
    }

    static function fontScale(valueExpr:String):String {
        return "(" + valueExpr + " == std::string(\"Display\") ? 68 :"
            + " " + valueExpr + " == std::string(\"TitleLarge\") ? 40 :"
            + " " + valueExpr + " == std::string(\"Title\") ? 28 :"
            + " " + valueExpr + " == std::string(\"Subtitle\") ? 20 :"
            + " " + valueExpr + " == std::string(\"Caption\") ? 12 : 14)";
    }

    /**
        A name to its alignment enum.

        The two enums do not share their values: horizontal is Left/Center/Right,
        vertical is Top/Center/Bottom. One conversion for both compiled here and
        was rejected by MSVC, which is the sort of thing only the real compiler
        knows.
    **/
    static function alignmentExpr(member:String, valueExpr:String):String {
        var e = "winrt_xaml::" + member;
        var near = member == "VerticalAlignment" ? "Top" : "Left";
        var far = member == "VerticalAlignment" ? "Bottom" : "Right";

        return "(" + valueExpr + " == std::string(\"Center\") ? " + e + "::Center :"
            + " " + valueExpr + " == std::string(\"" + far + "\") ? " + e + "::" + far + " :"
            + " " + valueExpr + " == std::string(\"" + near + "\") ? " + e + "::" + near
            + " : " + e + "::Stretch)";
    }

    /**
        The WinRT call for one property, or `null` when the node path cannot make
        it yet -- reported by its absence rather than emitted wrong.
    **/
    /**
        How a value arriving through the `kind` entry point reaches a `declared`
        member, or null when that entry point has no business setting it.

        **A number does not know which of the two it is.** Haxe answers
        `Std.isOfType(1.0, Int)` with `true` — a Float with nothing after the
        decimal point *is* an integer value — so a describing layer holding
        `Dynamic` sends `max = 1.0` through the integer entry point. Matching
        each entry point to its own declared kind meant that call found no
        branch and vanished: a slider kept WinUI's default maximum of 100, drew
        a value of 0.4 as a thumb pinned to the left, and said nothing.

        Which C type a number crossed as is an accident of the value. What it
        has to become is written on the member, so the two numeric entry points
        accept each other's properties and convert. Strings and booleans stay
        matched exactly: neither has a form the other can be mistaken for.
    **/
    static function incoming(kind:String, declared:String):Null<String> {
        if (kind == declared) return "value";
        return switch [kind, declared] {
            case ["KInt", "KFloat"]: "(double)value";
            case ["KFloat", "KInt"]: "(int)value";
            case _: null;
        };
    }

    /**
        Never re-assert a value a control already has.

        A two-way control is written by the user and then written again by the
        render that the user's own edit provoked -- the same value, arriving a
        moment later. WinRT does not treat that as a no-op: assigning `Text`
        moves the caret, and assigning `IsOn` cuts the switch animation off
        mid-slide and replaces it with a jump. Both read as the control being
        rebuilt under the user's hands, which is exactly what push mode exists
        to avoid.

        Only the properties a control writes back are guarded. Reading a brush
        or an alignment to compare it would cost more than setting it, and none
        of them can be changed from under us.
    **/
    /**
		Whether this key reaches its control through a helper rather than a
		WinRT member of its own.

		`ImageSource` is not a member of `Image`; `FontItalic` is not a member
		of `TextBlock`. Each is applied by a helper the generated runtime
		carries, named in `reassertGuard`, and `nodeSetter` answers the bare
		member for them so the edited path knows the key is handled.

		**The question is asked here rather than by reading that answer**, which
		is what let the defaults loop mistake a marker for a call and emit
		`c.FontItalic;`. One value meaning two things is the shape; this is the
		second meaning, named.
	**/
	static function appliedByHelper(member:String):Bool {
		return switch (member) {
			case "ImageSource" | "ImageAlt" | "ImageFit" | "ButtonIcon" | "ButtonIconName"
				| "FontFamilyName" | "FontWeightValue" | "FontItalic" | "Numerals": true;
			case _: false;
		}
	}

	static function reassertGuard(member:String, valueExpr:String, call:String, ?control:String):String {
        return switch (member) {
            // The controls a user edits: through the setters that keep a
            // runtime value from being reported as an edit, and that hold a
            // value back while the user holds the control. See `g_setting`.
            case "IsOn" if (control == "ToggleSwitch"):
                "setToggle(c, h, " + valueExpr + ");";
            case "Value" if (control == "Slider"):
                "setSlider(c, h, " + valueExpr + ");";

            // A range edge moves the VALUE when it crosses it, and a fresh
            // Slider holds 0: setting `Minimum` to 0.2 raises the value to 0.2
            // and raises `ValueChanged` with it. Unguarded, that reached the
            // sender as an edit nobody made -- the Farceur régie had a
            // transition of 1 s rewritten to 0.2 s in the saved project every
            // time a pupitre attached, because attaching is when a received
            // tree first applies its props.
            //
            // A slider whose minimum is 0 could never show it, which is why it
            // survived every panel built so far.
            //
            // Under the same guard the edited properties use: the event is
            // raised synchronously inside the call, so `g_setting` covers it,
            // and the value the control settled on is marked as ours in case a
            // platform ever raises it late.
            case "Minimum" | "Maximum" if (control == "Slider"):
                "g_setting[h] = true; c." + call + "; g_setting[h] = false; "
                + "g_doubleMark[h] = c.Value();";
            case "Text" if (control == "TextBox"):
                "setTextBox(c, h, " + valueExpr + ");";
            // A button's text is composed with its icon, never set on its own.
            case "Content" if (control == "Button"):
                "buttonLabel(c, h, " + valueExpr + ");";
            case "ButtonIcon":
                "buttonIcon(c, h, " + valueExpr + ");";
            case "ButtonIconName":
                "buttonIconName(c, h, " + valueExpr + ");";
            case "FontFamilyName":
                "textFamily(c, text);";
            case "FontWeightValue":
                "c.FontWeight(winrt::Windows::UI::Text::FontWeight{ (uint16_t)" + valueExpr + " });";
            case "FontItalic":
                "c.FontStyle(" + valueExpr + " ? winrt::Windows::UI::Text::FontStyle::Italic : winrt::Windows::UI::Text::FontStyle::Normal);";
            case "Numerals":
                "textNumerals(c, std::string(value));";
            case "ImageSource":
                "imageSource(c, h, " + valueExpr + ");";
            case "ImageAlt":
                "imageAlt(c, h, " + valueExpr + ");";
            case "ImageFit":
                "imageFit(c, h, std::string(value));";
            case "Text" | "IsOn" | "Value":
                "if (c." + member + "() != " + valueExpr + ") { c." + call + "; }";

            // Selecting by index is a lookup, so it is a statement rather than a
            // call and `call` is not used. Both controls select by item; Haxe
            // knows its sections by position, and this is where the two meet.
            // A NavigationView selects by item: the member is a name for the
            // lookup, not a WinRT property.
            case "SelectedMenuIndex":
                selectByIndex("MenuItems", valueExpr);
            // A ComboBox's real SelectedIndex, through comboSelect: see there.
            case "SelectedIndex":
                "comboSelect(c, h, " + valueExpr + ");";
            case "SelectedItemIndex":
                selectByIndex("Items", valueExpr);
            // A TabView has a real SelectedIndex; the member above is spoken
            // for by the ComboBox, so this one is named for its control.
            case "TabSelectedIndex":
                "tabSelect(c, h, " + valueExpr + ");";
            case "TabIconGlyph":
                "tabIcon(c, " + valueExpr + ");";

            case _:
                "c." + call + ";";
        };
    }

    /**
        Select the item at `valueExpr`, unless it is already the selected one.

        The guard is what keeps a tap from being fought. Selecting a section
        raises `SelectionChanged`, which tells Haxe, which re-renders and pushes
        the index back -- and re-selecting an item WinUI has already selected
        raises the event again. Comparing first turns that loop into one pass.
    **/
    static function selectByIndex(collection:String, valueExpr:String):String {
        return "{ uint32_t cur = 0;"
            + " bool have = c." + collection + "().IndexOf(c.SelectedItem(), cur);"
            + " if ((!have || (int)cur != " + valueExpr + ")"
            + " && (uint32_t)" + valueExpr + " < c." + collection + "().Size())"
            + " { c.SelectedItem(c." + collection + "().GetAt(" + valueExpr + ")); } }";
    }

    public static function nodeSetter(member:String, kind:String, textExpr:String, valueExpr:String):Null<String> {
        return switch (member) {
            case "Foreground" | "Background" | "BorderBrush":
                member + "(wui::runtime::brushFromName(" + valueExpr + "))";
            case "Orientation":
                member + "(std::string(" + valueExpr + ") == \"Horizontal\" ? winrt_controls::Orientation::Horizontal : winrt_controls::Orientation::Vertical)";

            // Two more enums, declared as strings on the Haxe side because that
            // is what a view can carry. `Top` is the mode that reads like tabs;
            // anything else falls back to WinUI's own choice rather than to a
            // mode picked here by accident.
            case "PaneDisplayMode":
                member + "(std::string(" + valueExpr + ") == \"Top\" ? winrt_controls::NavigationViewPaneDisplayMode::Top"
                    + " : std::string(" + valueExpr + ") == \"Left\" ? winrt_controls::NavigationViewPaneDisplayMode::Left"
                    + " : std::string(" + valueExpr + ") == \"LeftMinimal\" ? winrt_controls::NavigationViewPaneDisplayMode::LeftMinimal"
                    + " : winrt_controls::NavigationViewPaneDisplayMode::Auto)";
            case "IsBackButtonVisible":
                member + "(std::string(" + valueExpr + ") == \"Visible\" ? winrt_controls::NavigationViewBackButtonVisible::Visible"
                    + " : std::string(" + valueExpr + ") == \"Auto\" ? winrt_controls::NavigationViewBackButtonVisible::Auto"
                    + " : winrt_controls::NavigationViewBackButtonVisible::Collapsed)";
            // Both take an IInspectable, not a string: WinUI lets a header or a
            // content be any element, and a string has to be boxed to become
            // one. Passing the hstring compiled to "no overloaded function
            // could convert all the argument types", which names the symptom.
            case "Content" | "Header" | "Tag":
                member + "(winrt::box_value(" + textExpr + "))";
            // A family list, "Segoe Fluent Icons, Segoe MDL2 Assets": a
            // FontFamily object, not a string.
            case "FontFamily":
                member + "(winrt::Microsoft::UI::Xaml::Media::FontFamily(" + textExpr + "))";
            // Not WinRT members: an Image node's parts, applied by the helpers
            // `reassertGuard` names. A value here only says the key is handled.
            case _ if (appliedByHelper(member)):
                // Not a WinRT member: applied by one of the helpers
                // `reassertGuard` names. The value here only says the key is
                // HANDLED -- it is not a call, and `appliedByHelper` is what
                // anybody asking that question should use instead of reading
                // this string. See the comment on that function.
                member;
            // An enum, not a string: WinUI's own default is `Peek`, which
            // shows a reveal button while the box has focus. `wui.ui.PasswordBox`
            // declares `hidden` so a secret typed in front of a screen capture
            // is never offered one, and this is where that word becomes the
            // enum. Anything unrecognised is Hidden, which is the safe answer
            // rather than the literal one.
            case "PasswordRevealMode":
                member + "(std::string(" + valueExpr + ") == \"visible\""
                + " ? winrt_controls::PasswordRevealMode::Visible"
                + " : winrt_controls::PasswordRevealMode::Hidden)";
            case "Visibility":
                member + "(" + valueExpr + " ? winrt_xaml::Visibility::Visible : winrt_xaml::Visibility::Collapsed)";

            // These take a struct, not a number -- one value, four sides.
            case "Padding" | "Margin" | "BorderThickness":
                member + "(wui::runtime::uniformThickness(" + valueExpr + "))";
            case "CornerRadius":
                member + "(wui::runtime::uniformCornerRadius(" + valueExpr + "))";
            // The typographic scale the old hand-written translation carried.
            // Emitting nothing for it is what lost the design.
            case "FontScale":
                "FontSize(" + fontScale(valueExpr) + ")";
            case "FontWeight":
                // A struct literal, not FontWeights::SemiBold(): that is a
                // function returning auto and MSVC refuses it here.
                member + "(" + valueExpr + " ? winrt::Windows::UI::Text::FontWeight{ 600 } : winrt::Windows::UI::Text::FontWeight{ 400 })";
            case "HorizontalAlignment" | "VerticalAlignment":
                member + "(" + alignmentExpr(member, valueExpr) + ")";
            case _:
                kind == "KString" ? member + "(" + textExpr + ")" : member + "(" + valueExpr + ")";
        };
    }

    static function generateAppHeader(appName:String, outputDir:String):Void {
        // No XAML, no IDL — pure C++/WinRT Application with IXamlMetadataProvider
        var content = '#pragma once
#include "pch.h"
#include <winrt/Microsoft.UI.Xaml.Markup.h>
#include <winrt/Microsoft.UI.Xaml.XamlTypeInfo.h>

// Forward declare the UI builder
namespace MainWindow {
    winrt::Microsoft::UI::Xaml::UIElement BuildUI(
        winrt::Microsoft::UI::Xaml::Window const& window);
}

// Application class with IXamlMetadataProvider for programmatic resource loading.
// No XAML, no IDL, no XBF needed.
struct App : winrt::Microsoft::UI::Xaml::ApplicationT<App, winrt::Microsoft::UI::Xaml::Markup::IXamlMetadataProvider>
{
    void OnLaunched(winrt::Microsoft::UI::Xaml::LaunchActivatedEventArgs const&);

    // IXamlMetadataProvider — delegates to XamlControlsXamlMetaDataProvider
    winrt::Microsoft::UI::Xaml::Markup::IXamlType GetXamlType(winrt::Windows::UI::Xaml::Interop::TypeName const& type) {
        return m_provider.GetXamlType(type);
    }
    winrt::Microsoft::UI::Xaml::Markup::IXamlType GetXamlType(winrt::hstring const& fullName) {
        return m_provider.GetXamlType(fullName);
    }
    winrt::com_array<winrt::Microsoft::UI::Xaml::Markup::XmlnsDefinition> GetXmlnsDefinitions() {
        return m_provider.GetXmlnsDefinitions();
    }

private:
    winrt::Microsoft::UI::Xaml::XamlTypeInfo::XamlControlsXamlMetaDataProvider m_provider;
    winrt::Microsoft::UI::Xaml::Window m_window{ nullptr };
};
';
        ProjectGenerator.writeIfChanged(Path.join([outputDir, "App.h"]), content);
    }

    static function generateAppSource(appName:String, outputDir:String, windowWidth:Int, windowHeight:Int, appClassPath:String, callbackCount:Int):Void {
        var content = '#include "pch.h"
#include "App.h"
#include "MainWindow.h"

namespace winrt_xaml = winrt::Microsoft::UI::Xaml;

// Starts the Haxe runtime. Defined in the hxcpp static library; see
// wui.bridge.HaxeBridge. WinUI owns the entry point, so Haxe cannot own main --
// it is booted here instead, before the window exists, the same way Qt boots it
// in qui and Swift in sui.
extern "C" void wui_bridge_init();
extern "C" int wui_bridge_install(const char* appClass);

void App::OnLaunched(winrt_xaml::LaunchActivatedEventArgs const&)
{
    // Boot Haxe first: everything built below may call into it.
    wui_bridge_init();

    // Then let Haxe build its own view tree once, purely to collect the closures
    // its buttons carry. The controls below are still built by this file; what
    // this call produces is the id -> closure table the Click handlers use.
    //
    // The count is compared because a silent zero is the failure that matters:
    // the app would look correct and every Haxe button would do nothing.
    {
        int installed = wui_bridge_install("$appClassPath");
        if (installed != $callbackCount) {
            OutputDebugStringA("[wui] callback count mismatch, generated vs registered\\n");
        }
    }

    // Load WinUI control styles (enables TextBox, Slider, ToggleSwitch, etc.)
    Resources().MergedDictionaries().Append(
        winrt::Microsoft::UI::Xaml::Controls::XamlControlsResources());

    m_window = winrt_xaml::Window();
    m_window.Title(L"$appName");

    // Store the dispatcher queue for UI thread marshaling
    wui::runtime::dispatcherQueue = m_window.DispatcherQueue();

    // Resize window
    if (auto appWindow = m_window.AppWindow()) {
        appWindow.Resize(winrt::Windows::Graphics::SizeInt32{ $windowWidth, $windowHeight });
    }

    // Build the UI from Haxe-generated code
    auto content = MainWindow::BuildUI(m_window);
    m_window.Content(content);

    m_window.Activate();
}

// Application entry point
int __stdcall wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    winrt::init_apartment(winrt::apartment_type::single_threaded);

    winrt_xaml::Application::Start(
        [](auto&&) {
            ::winrt::make<App>();
        });

    return 0;
}
';
        ProjectGenerator.writeIfChanged(Path.join([outputDir, "App.cpp"]), content);
    }

    static function generateRuntime(outputDir:String):Void {
        var content = '#pragma once
#include <cctype>
#include <functional>
#include <string>
#include <vector>
#include <unordered_map>
#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

namespace wui { namespace runtime {

    // ---- UI Thread Dispatch ----

    inline winrt::Microsoft::UI::Dispatching::DispatcherQueue dispatcherQueue{ nullptr };

    inline void runOnUIThread(std::function<void()> fn) {
        if (dispatcherQueue && !dispatcherQueue.HasThreadAccess()) {
            dispatcherQueue.TryEnqueue(
                winrt::Microsoft::UI::Dispatching::DispatcherQueueHandler(fn));
        } else {
            fn();
        }
    }

    // ---- String Conversion ----

    inline winrt::hstring toHString(const std::wstring& s) { return winrt::hstring(s); }
    inline winrt::hstring toHString(const wchar_t* s) { return winrt::hstring(s); }
    inline winrt::hstring toHString(int value) { return winrt::hstring(std::to_wstring(value)); }
    inline winrt::hstring toHString(double value) { return winrt::hstring(std::to_wstring(value)); }
    inline winrt::hstring toHString(bool value) { return winrt::hstring(value ? L"true" : L"false"); }

    // ---- UTF-8 <-> UTF-16, for text crossing the Haxe bridge ----
    //
    // Haxe strings are UTF-8 and WinUI wants UTF-16, so every string that crosses
    // is converted here rather than at each call site. Going through the Win32
    // functions rather than std::codecvt, which is deprecated and was never right
    // about surrogate pairs -- an emoji in a text box is enough to show it.

    inline std::wstring fromUtf8(const char* s) {
        if (s == nullptr || *s == 0) return std::wstring();
        int len = ::MultiByteToWideChar(CP_UTF8, 0, s, -1, nullptr, 0);
        if (len <= 1) return std::wstring();
        std::wstring out(static_cast<size_t>(len - 1), static_cast<wchar_t>(0));
        ::MultiByteToWideChar(CP_UTF8, 0, s, -1, &out[0], len);
        return out;
    }

    inline std::string toUtf8(const std::wstring& s) {
        if (s.empty()) return std::string();
        int len = ::WideCharToMultiByte(CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()),
                                        nullptr, 0, nullptr, nullptr);
        if (len <= 0) return std::string();
        std::string out(static_cast<size_t>(len), 0);
        ::WideCharToMultiByte(CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()),
                              &out[0], len, nullptr, nullptr);
        return out;
    }

    // ---- State Change Notification (placeholder for debugging) ----

    inline void onStateChanged(const char* name, const char* value) {}

    // ---- Color Helpers ----

    inline winrt::Microsoft::UI::Xaml::Media::SolidColorBrush
    colorBrush(uint8_t r, uint8_t g, uint8_t b, uint8_t a = 255) {
        winrt::Windows::UI::Color color{ a, r, g, b };
        return winrt::Microsoft::UI::Xaml::Media::SolidColorBrush(color);
    }

    inline auto blackBrush()       { return colorBrush(0, 0, 0); }
    inline auto whiteBrush()       { return colorBrush(255, 255, 255); }
    inline auto redBrush()         { return colorBrush(255, 0, 0); }
    inline auto greenBrush()       { return colorBrush(0, 128, 0); }
    inline auto blueBrush()        { return colorBrush(0, 0, 255); }
    inline auto yellowBrush()      { return colorBrush(255, 255, 0); }
    inline auto orangeBrush()      { return colorBrush(255, 165, 0); }
    inline auto purpleBrush()      { return colorBrush(128, 0, 128); }
    inline auto grayBrush()        { return colorBrush(128, 128, 128); }
    inline auto transparentBrush() { return colorBrush(0, 0, 0, 0); }

    // The accent is the one the PERSON chose, read from the system rather than
    // written down here. It used to be a constant, so a pupitre on a machine
    // whose owner had picked orange drew the default blue and said nothing.
    inline winrt::Windows::UI::Color systemAccent() {
        try {
            winrt::Windows::UI::ViewManagement::UISettings settings;
            return settings.GetColorValue(
                winrt::Windows::UI::ViewManagement::UIColorType::Accent);
        } catch (...) {
            return winrt::Windows::UI::Color{ 255, 0, 120, 212 };
        }
    }

    inline auto accentBrush() { auto c = systemAccent(); return colorBrush(c.R, c.G, c.B, c.A); }

    // Whether this machine is showing a dark theme, which decides what
    // `surface`, `text`, `muted` and `border` resolve to. Asked of the system
    // for the same reason as the accent.
    inline bool systemIsDark() {
        try {
            winrt::Windows::UI::ViewManagement::UISettings settings;
            auto bg = settings.GetColorValue(
                winrt::Windows::UI::ViewManagement::UIColorType::Background);
            return (bg.R + bg.G + bg.B) < 384;
        } catch (...) {
            return false;
        }
    }

    // ---- nui roles ----
    //
    // A role crosses as a role so that THIS machine resolves it: its accent,
    // its light or dark theme. A number chosen by the sender would be a number
    // chosen for a screen it cannot see. See nui.Role.
    inline winrt::Microsoft::UI::Xaml::Media::SolidColorBrush brushFromRole(const std::string& role) {
        const bool dark = systemIsDark();
        if (role == "accent")  return accentBrush();
        if (role == "danger")  return dark ? colorBrush(248, 113, 113) : colorBrush(196, 43, 28);
        if (role == "warning") return dark ? colorBrush(251, 191, 36)  : colorBrush(157, 93, 0);
        if (role == "success") return dark ? colorBrush(108, 203, 95)  : colorBrush(15, 123, 15);
        if (role == "surface") return dark ? colorBrush(32, 32, 32)    : colorBrush(255, 255, 255);
        if (role == "text")    return dark ? colorBrush(255, 255, 255) : colorBrush(26, 26, 26);
        if (role == "muted")   return dark ? colorBrush(155, 155, 155) : colorBrush(95, 95, 95);
        if (role == "border")  return dark ? colorBrush(60, 60, 60)    : colorBrush(216, 216, 216);
        OutputDebugStringA(("[wui] no colour for role " + role + "\\n").c_str());
        return nullptr;
    }

    // ---- nui components ----
    //
    // #rgb, #rgba, #rrggbb or #rrggbbaa, the opacity LAST. Refused rather
    // than guessed: a malformed colour is a typo somebody made, and a brush
    // invented for it is a wrong pixel nobody traces.
    inline winrt::Microsoft::UI::Xaml::Media::SolidColorBrush brushFromHex(const std::string& said) {
        std::string body = said.substr(1);
        const bool shorthand = body.size() == 3 || body.size() == 4;
        if (body.size() != 3 && body.size() != 4 && body.size() != 6 && body.size() != 8)
            return nullptr;

        std::string full;
        for (char ch : body) {
            if (!std::isxdigit(static_cast<unsigned char>(ch))) return nullptr;
            full.push_back(ch);
            if (shorthand) full.push_back(ch);
        }
        auto byteAt = [&](size_t i) {
            return (uint8_t)std::stoi(full.substr(i, 2), nullptr, 16);
        };
        // Written without one, a colour is solid: nobody writing #c8323c meant
        // invisible.
        uint8_t a = full.size() == 8 ? byteAt(6) : 255;
        return colorBrush(byteAt(0), byteAt(2), byteAt(4), a);
    }

    // A colour arrives from nui as a word: role:danger, #c8323c, or one of
    // the names this backend accepted before the canon existed.
    //
    // An unknown one yields no brush rather than a guessed one: leaving the
    // control its own colour beats inventing one.
    inline winrt::Microsoft::UI::Xaml::Media::SolidColorBrush brushFromName(const char* name) {
        std::string n(name == nullptr ? "" : name);
        if (n.rfind("role:", 0) == 0) {
            std::string role = n.substr(5);
            for (auto& ch : role) ch = (char)std::tolower((unsigned char)ch);
            return brushFromRole(role);
        }
        // `rfind(…, 0)` rather than a char literal: this whole block lives
        // inside a Haxe string, where a single quote ends it.
        if (n.rfind("#", 0) == 0) return brushFromHex(n);

        // Folded, because a colour is not a different colour for being
        // capitalised. The divider in mui asked for "Gray", this table held
        // "gray", and the mismatch cost it its whole background -- a grey line
        // one pixel tall that drew nothing at all, on every screen it was on.
        for (auto& ch : n) ch = (char)std::tolower((unsigned char)ch);
        if (!n.empty() && n != "black" && n != "white" && n != "red" && n != "green"
            && n != "blue" && n != "yellow" && n != "orange" && n != "purple"
            && n != "gray" && n != "accent") {
            OutputDebugStringA(("[wui] no colour named " + n + "\\n").c_str());
        }
        if (n == "black")   return blackBrush();
        if (n == "white")   return whiteBrush();
        if (n == "red")     return redBrush();
        if (n == "green")   return greenBrush();
        if (n == "blue")    return blueBrush();
        if (n == "yellow")  return yellowBrush();
        if (n == "orange")  return orangeBrush();
        if (n == "purple")  return purpleBrush();
        if (n == "gray")    return grayBrush();
        if (n == "accent")  return accentBrush();
        return nullptr;
    }

    // ---- Thickness / CornerRadius ----

    inline winrt::Microsoft::UI::Xaml::Thickness uniformThickness(double value) {
        return { value, value, value, value };
    }

    inline winrt::Microsoft::UI::Xaml::CornerRadius uniformCornerRadius(double value) {
        return { value, value, value, value };
    }

}} // namespace wui::runtime
';
        ProjectGenerator.writeIfChanged(Path.join([outputDir, "WuiRuntime.h"]), content);
    }
    #end
}

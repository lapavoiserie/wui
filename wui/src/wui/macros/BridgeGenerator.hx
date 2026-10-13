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
        header.add("extern \"C\" void wui_node_modifier(int h, const char* type, const char* modType, double f0, double f1, double f2, double f3, int nf, const char* s0);\n");
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
        header.add("    int createWindow(const char* title);\n\n");
        header.add("    // The main window and its root, from BuildUI: what Present.show(Primary)\n");
        header.add("    // raises, and what a Status app keeps alive when it is closed.\n");
        header.add("    void setPrimaryWindow(winrt::Microsoft::UI::Xaml::Window const& window, int root);\n}}\n");
        ProjectGenerator.writeIfChanged(Path.join([outputDir, "WuiNodes.h"]), header.toString());
        generateComponentsHeader(outputDir);

        var src = new StringBuf();
        src.add("#include \"pch.h\"\n#include \"WuiNodes.h\"\n#include \"WuiRuntime.h\"\n#include \"WuiComponents.h\"\n#include <unordered_map>\n#include <cmath>\n");
        src.add("// VirtualKey / VirtualKeyModifiers, for the accelerator a MenuFlyoutItem\n");
        src.add("// carries. pch.h pulls the Xaml headers; the enums live in Windows.System,\n");
        src.add("// which nothing else here needed until the menu bar.\n");
        src.add("#include <winrt/Windows.System.h>\n");
        src.add("#include <ctime>\n#include <cstdio>\n#include <cwchar>\n#include <winrt/Windows.Globalization.h>\n");
        src.add(SurfacesCpp.includes());
        src.add("#include <vector>\n#include <string>\n\n");
        // Pictures: a BitmapImage, the executable's directory for assets, a
        // temporary file for a data: picture.
        src.add("#include <winrt/Microsoft.UI.Xaml.Media.Imaging.h>\n");
        src.add("#include <winrt/Microsoft.UI.Xaml.Automation.h>\n");
        src.add("#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>\n");
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
        // Whether a child of a column takes the height left over (`*`) rather
        // than what it asks for: a ScrollViewer, tabs, a sidebar, a nested
        // column, or a ZStack (an untagged Grid) holding one.
        src.add("    bool fillsHeight(winrt_xaml::UIElement const& e) {\n");
        src.add("        if (e.try_as<winrt_controls::ScrollViewer>() != nullptr) return true;\n");
        src.add("        if (e.try_as<winrt_controls::NavigationView>() != nullptr) return true;\n");
        src.add("        if (e.try_as<winrt_controls::TabView>() != nullptr) return true;\n");
        src.add("        auto grid = e.try_as<winrt_controls::Grid>();\n");
        src.add("        if (grid == nullptr) return false;\n");
        src.add("        auto tag = tagText(grid);\n");
        // A nested column always does: it is a wrapper, inserted once, and its
        // content may only come to fill later (a loading screen, then tabs).
        src.add("        if (tag == L\"column\") return true;\n");
        src.add("        if (!tag.empty()) return false;\n");
        src.add("        for (auto const& child : grid.Children()) if (fillsHeight(child)) return true;\n");
        src.add("        return false;\n    }\n\n");
        // A column's rows follow its children: after an insert or a removal,
        // every child from `from` on sits in the row of its new position.
        src.add("    void columnRenumber(winrt_controls::Grid const& grid, uint32_t from) {\n");
        src.add("        for (uint32_t k = from; k < grid.Children().Size(); ++k) {\n");
        src.add("            if (auto moved = grid.Children().GetAt(k).try_as<winrt_xaml::FrameworkElement>())\n");
        src.add("                winrt_controls::Grid::SetRow(moved, (int)k);\n        }\n    }\n\n");
        // A row's columns: `Auto` for content, `*` for a spacer. Except the
        // usual row -- something, its text, one spacer, then what sits at the
        // trailing edge: the text before the spacer takes the leftover room
        // itself, and the spacer none. Drawn the same while there is room;
        // short of it, the text wraps within what the row can give it, where
        // an `Auto` column kept its whole width and pushed the trailing
        // controls past the row's edge.
        src.add("    bool rowShrinks(winrt_xaml::UIElement const& e) {\n");
        src.add("        if (e.try_as<winrt_controls::TextBlock>()) return true;\n");
        src.add("        auto stack = e.try_as<winrt_controls::StackPanel>();\n");
        src.add("        return stack != nullptr && stack.Orientation() == winrt_controls::Orientation::Vertical;\n    }\n\n");
        src.add("    void rowColumns(winrt_controls::Grid const& grid) {\n");
        src.add("        auto kids = grid.Children();\n");
        src.add("        auto columns = grid.ColumnDefinitions();\n");
        src.add("        uint32_t n = kids.Size() < columns.Size() ? kids.Size() : columns.Size();\n");
        src.add("        int spacers = 0, spacer = -1;\n");
        src.add("        for (uint32_t i = 0; i < n; ++i)\n");
        src.add("            if (tagText(kids.GetAt(i)) == L\"spacer\") { ++spacers; spacer = (int)i; }\n");
        src.add("        int filler = (spacers == 1 && spacer > 0 && rowShrinks(kids.GetAt(spacer - 1))) ? spacer - 1 : -1;\n");
        src.add("        for (uint32_t i = 0; i < n; ++i) {\n");
        src.add("            bool star = filler >= 0 ? (int)i == filler : tagText(kids.GetAt(i)) == L\"spacer\";\n");
        // Not below a few words' width: a column of one letter a line
        // drew a card as tall as the window.
        src.add("            columns.GetAt(i).MinWidth((int)i == filler ? 96.0 : 0.0);\n");
        src.add("            columns.GetAt(i).Width(star\n");
        src.add("                ? winrt_xaml::GridLength{ 1.0, winrt_xaml::GridUnitType::Star }\n");
        src.add("                : winrt_xaml::GridLength{ 0.0, winrt_xaml::GridUnitType::Auto });\n        }\n    }\n\n");
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
        src.add("    std::vector<winrt_xaml::Window> g_windows;\n");
        // Every window by the root handle Haxe knows it by: Present raises one.
        src.add("    std::unordered_map<int, winrt_xaml::Window> g_windowOf;\n");
        src.add("    int g_primaryRoot = -1;\n\n");
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
        src.add("    void navIcon(winrt_controls::NavigationViewItem const& c, winrt::hstring const& glyph) {\n");
        src.add("        if (glyph.empty()) { c.Icon(nullptr); return; }\n");
        src.add("        winrt_controls::FontIcon icon;\n");
        src.add("        icon.Glyph(glyph);\n");
        src.add("        c.Icon(icon);\n    }\n\n");
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
        src.add("    struct ButtonParts { std::wstring label; std::wstring glyph; std::wstring iconName; std::string style; bool checked = false; bool composed = false; };\n");
        src.add("    std::unordered_map<int, ButtonParts> g_buttons;\n\n");
        src.add("    void buttonCompose(winrt_controls::Button const& c, int h) {\n");
        src.add("        auto& b = g_buttons[h];\n");
        src.add("        b.composed = true;\n");
        // A check draws its mark and no text: the label is what a screen
        // reader says, "Mark the dishes done", never a caption.
        src.add("        if (b.style == \"check\") {\n");
        src.add("            winrt_controls::FontIcon mark;\n");
        src.add("            mark.FontFamily(winrt::Microsoft::UI::Xaml::Media::FontFamily(L\"Segoe Fluent Icons, Segoe MDL2 Assets\"));\n");
        src.add("            mark.Glyph(b.checked ? L\"\\xEC61\" : L\"\\xEA3A\");\n");
        src.add("            mark.FontSize(20);\n");
        src.add("            c.Content(mark);\n");
        src.add("        } else if (b.glyph.empty()) {\n");
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
        src.add("        if (b.composed && b.label.empty()) winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetName(c, v);\n    }\n\n");
        // The canon's `style`, as chrome. Undone only for what the previous
        // style put there, so a decoration's own background survives a
        // button that never had a style.
        src.add("    void buttonStyle(winrt_controls::Button const& c, int h, winrt::hstring const& v) {\n");
        src.add("        auto& b = g_buttons[h];\n");
        src.add("        std::string now = winrt::to_string(v);\n");
        src.add("        if (b.composed && b.style == now) return;\n");
        src.add("        std::string was = b.style;\n");
        src.add("        b.style = now;\n");
        src.add("        if (was == \"primary\") c.ClearValue(winrt_xaml::FrameworkElement::StyleProperty());\n");
        src.add("        if (was == \"plain\" || was == \"check\") {\n");
        src.add("            c.ClearValue(winrt_controls::Control::BackgroundProperty());\n");
        src.add("            c.ClearValue(winrt_controls::Control::BorderThicknessProperty());\n        }\n");
        src.add("        if (now == \"primary\") {\n");
        src.add("            try {\n");
        src.add("                c.Style(winrt_xaml::Application::Current().Resources().Lookup(winrt::box_value(L\"AccentButtonStyle\")).as<winrt_xaml::Style>());\n");
        src.add("            } catch (...) {}\n        }\n");
        src.add("        if (now == \"plain\" || now == \"check\") {\n");
        src.add("            c.Background(wui::runtime::transparentBrush());\n");
        src.add("            c.BorderThickness(winrt_xaml::Thickness{ 0, 0, 0, 0 });\n        }\n");
        src.add("        if (was == \"check\" || now == \"check\") buttonCompose(c, h);\n    }\n\n");
        src.add("    void buttonChecked(winrt_controls::Button const& c, int h, bool v) {\n");
        src.add("        auto& b = g_buttons[h];\n");
        src.add("        if (b.composed && b.checked == v) return;\n");
        src.add("        b.checked = v;\n");
        src.add("        if (b.style == \"check\") buttonCompose(c, h);\n    }\n\n");
        // A toolbar's title is the bar's content, on the left of its commands.
        src.add("    void commandBarTitle(winrt_controls::CommandBar const& c, winrt::hstring const& v) {\n");
        src.add("        if (v.empty()) { c.Content(nullptr); return; }\n");
        src.add("        winrt_controls::TextBlock title;\n");
        src.add("        title.Text(v);\n");
        src.add("        try {\n");
        src.add("            title.Style(winrt_xaml::Application::Current().Resources().Lookup(winrt::box_value(L\"SubtitleTextBlockStyle\")).as<winrt_xaml::Style>());\n");
        src.add("        } catch (...) {}\n");
        src.add("        title.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);\n");
        src.add("        title.Margin(winrt_xaml::Thickness{ 12, 0, 12, 0 });\n");
        src.add("        c.Content(title);\n    }\n\n");
        src.add("    void appBarIcon(winrt_controls::AppBarButton const& c, winrt::hstring const& v) {\n");
        src.add("        if (v.empty()) { c.Icon(nullptr); return; }\n");
        src.add("        winrt_controls::FontIcon icon;\n");
        src.add("        icon.FontFamily(winrt::Microsoft::UI::Xaml::Media::FontFamily(L\"Segoe Fluent Icons, Segoe MDL2 Assets\"));\n");
        src.add("        icon.Glyph(v);\n");
        src.add("        c.Icon(icon);\n    }\n\n");
        // What a toolbar wraps a child in when the child is not a command of
        // its own -- a picker, a primary button. Kept per child, so a child
        // moved within the bar is moved in the same wrapper: a second one
        // would find it still parented to the first and throw.
        src.add("    std::unordered_map<int, winrt_controls::AppBarElementContainer> g_barBoxes;\n\n");

        // ---- forms: see wui.ui.Form, Section and Field ----
        // A form's row for a child that is not one already, kept per child for
        // the reason a toolbar's wrapper is; and the label each child gave the
        // form's label column, which can arrive before the row exists.
        src.add("    std::unordered_map<int, winrt_controls::Grid> g_formRows;\n");
        src.add("    std::unordered_map<int, std::wstring> g_formLabels;\n");
        // A field control's label beside it: a row of the label and the
        // control, made when the sink says the control is one, filled when
        // the control is inserted.
        src.add("    std::unordered_map<int, winrt_controls::StackPanel> g_inlineRows;\n\n");
        src.add("    void twoColumns(winrt_controls::Grid const& g) {\n");
        src.add("        winrt_controls::ColumnDefinition label;\n");
        src.add("        label.Width(winrt_xaml::GridLength{ 0.0, winrt_xaml::GridUnitType::Auto });\n");
        src.add("        winrt_controls::ColumnDefinition control;\n");
        src.add("        control.Width(winrt_xaml::GridLength{ 1.0, winrt_xaml::GridUnitType::Star });\n");
        src.add("        g.ColumnDefinitions().Append(label);\n");
        src.add("        g.ColumnDefinitions().Append(control);\n    }\n\n");
        src.add("    winrt_controls::TextBlock labelBlock() {\n");
        src.add("        winrt_controls::TextBlock t;\n");
        src.add("        t.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);\n");
        src.add("        return t;\n    }\n\n");
        // The form a row belongs to, by its logical parents: a row in a section
        // not yet in its form has none, and is aligned when the section arrives.
        src.add("    winrt_controls::StackPanel formOf(winrt_xaml::UIElement const& start) {\n");
        src.add("        auto fe = start.try_as<winrt_xaml::FrameworkElement>();\n");
        src.add("        while (fe != nullptr) {\n");
        src.add("            if (tagText(fe) == L\"form\") return fe.try_as<winrt_controls::StackPanel>();\n");
        src.add("            auto up = fe.Parent();\n");
        src.add("            fe = up ? up.try_as<winrt_xaml::FrameworkElement>() : nullptr;\n        }\n");
        src.add("        return nullptr;\n    }\n\n");
        // One label column for the whole form: every label measured, every
        // row's first column set to the widest. The rows cannot be one Grid --
        // a section stands between them -- so this is what one Grid would do.
        src.add("    void formCollect(winrt_controls::Panel const& panel, std::vector<winrt_controls::Grid>& rows) {\n");
        src.add("        for (auto const& child : panel.Children()) {\n");
        src.add("            auto tag = tagText(child);\n");
        src.add("            if (tag == L\"formrow\" || tag == L\"field\") rows.push_back(child.as<winrt_controls::Grid>());\n");
        src.add("            else if (tag == L\"formsection\") formCollect(child.as<winrt_controls::Panel>(), rows);\n        }\n    }\n\n");
        src.add("    void formAlign(winrt_xaml::UIElement const& from) {\n");
        src.add("        auto form = formOf(from);\n");
        src.add("        if (form == nullptr) return;\n");
        src.add("        std::vector<winrt_controls::Grid> rows;\n");
        src.add("        formCollect(form, rows);\n");
        src.add("        float widest = 0;\n");
        src.add("        for (auto const& row : rows) {\n");
        src.add("            auto label = row.Children().GetAt(0);\n");
        src.add("            label.Measure(winrt::Windows::Foundation::Size{ 1e6f, 1e6f });\n");
        src.add("            if (label.DesiredSize().Width > widest) widest = label.DesiredSize().Width;\n        }\n");
        src.add("        for (auto const& row : rows)\n");
        src.add("            row.ColumnDefinitions().GetAt(0).Width(winrt_xaml::GridLength{ (double)widest, winrt_xaml::GridUnitType::Pixel });\n    }\n\n");
        src.add("    winrt_controls::Grid formRowFor(int child, winrt_xaml::UIElement const& c) {\n");
        src.add("        winrt_controls::Grid row;\n");
        src.add("        row.Tag(winrt::box_value(L\"formrow\"));\n");
        src.add("        row.ColumnSpacing(12);\n");
        src.add("        twoColumns(row);\n");
        src.add("        auto label = labelBlock();\n");
        src.add("        auto said = g_formLabels.find(child);\n");
        src.add("        if (said != g_formLabels.end()) label.Text(winrt::hstring(said->second));\n");
        src.add("        row.Children().Append(label);\n");
        src.add("        if (auto fe = c.try_as<winrt_xaml::FrameworkElement>()) winrt_controls::Grid::SetColumn(fe, 1);\n");
        src.add("        row.Children().Append(c);\n");
        src.add("        winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetLabeledBy(c, label);\n");
        src.add("        return row;\n    }\n\n");
        // A field is made with its parts: its label, and a Grid for its
        // controls, where a control alone takes the row and several sit side
        // by side. The Grid is held by a GroupItem, whose automation peer is a
        // group: a Panel has none, so a Grid cannot be named for Narrator.
        src.add("    void fieldSetup(winrt_controls::Grid const& c) {\n");
        src.add("        twoColumns(c);\n");
        src.add("        c.Children().Append(labelBlock());\n");
        src.add("        winrt_controls::Grid controls;\n");
        src.add("        controls.ColumnSpacing(8);\n");
        src.add("        winrt_controls::GroupItem group;\n");
        // Its template is a group's in a list -- a header over items -- and
        // draws the content at the size it asks for, so a text field alone in
        // the row stopped stretching. The controls are given the group's width
        // instead. Replacing the template is not the fix: the group's peer
        // then reported no children, and Narrator lost every control in it.
        src.add("        group.SizeChanged([](auto const& sender, winrt_xaml::SizeChangedEventArgs const& args) {\n");
        src.add("            auto g = sender.template as<winrt_controls::GroupItem>();\n");
        src.add("            if (auto grid = g.Content().template try_as<winrt_controls::Grid>()) grid.Width(args.NewSize().Width);\n");
        src.add("        });\n");
        src.add("        group.IsTabStop(false);\n");
        src.add("        group.HorizontalContentAlignment(winrt_xaml::HorizontalAlignment::Stretch);\n");
        src.add("        group.Content(controls);\n");
        src.add("        winrt_controls::Grid::SetColumn(group, 1);\n");
        src.add("        c.Children().Append(group);\n    }\n\n");
        src.add("    winrt_controls::Grid fieldControls(winrt_controls::Grid const& field) {\n");
        src.add("        return field.Children().GetAt(1).as<winrt_controls::GroupItem>().Content().as<winrt_controls::Grid>();\n    }\n\n");
        // A control alone is named by the field's label ("Quoi"), and the
        // group is hidden from automation. Several keep their own names ("S",
        // "D") inside a group named by the label: "Jours, groupe", then each.
        src.add("    void fieldColumns(winrt_controls::Grid const& field) {\n");
        src.add("        namespace automation = winrt::Microsoft::UI::Xaml::Automation;\n");
        src.add("        auto label = field.Children().GetAt(0).as<winrt_controls::TextBlock>();\n");
        src.add("        auto group = field.Children().GetAt(1).as<winrt_controls::GroupItem>();\n");
        src.add("        auto controls = fieldControls(field);\n");
        src.add("        auto kids = controls.Children();\n");
        src.add("        bool alone = kids.Size() == 1;\n");
        src.add("        for (auto const& kid : kids)\n");
        src.add("            automation::AutomationProperties::SetLabeledBy(kid, alone ? label : nullptr);\n");
        src.add("        automation::AutomationProperties::SetName(group, alone ? winrt::hstring() : label.Text());\n");
        src.add("        automation::AutomationProperties::SetAccessibilityView(group, alone\n");
        src.add("            ? automation::Peers::AccessibilityView::Raw : automation::Peers::AccessibilityView::Content);\n");
        src.add("        uint32_t n = kids.Size();\n");
        src.add("        controls.ColumnDefinitions().Clear();\n");
        src.add("        for (uint32_t i = 0; i < n; ++i) {\n");
        src.add("            winrt_controls::ColumnDefinition d;\n");
        src.add("            d.Width(n == 1 ? winrt_xaml::GridLength{ 1.0, winrt_xaml::GridUnitType::Star }\n");
        src.add("                           : winrt_xaml::GridLength{ 0.0, winrt_xaml::GridUnitType::Auto });\n");
        src.add("            controls.ColumnDefinitions().Append(d);\n");
        src.add("            auto fe = kids.GetAt(i).try_as<winrt_xaml::FrameworkElement>();\n");
        src.add("            if (fe == nullptr) continue;\n");
        src.add("            winrt_controls::Grid::SetColumn(fe, (int)i);\n");
        // Several controls on one row are centred on it: a taller one -- a
        // SelectorBar -- left a text after it sitting at its top. Not over an
        // alignment the control set itself.
        src.add("            if (n > 1 && fe.ReadLocalValue(winrt_xaml::FrameworkElement::VerticalAlignmentProperty()) == winrt_xaml::DependencyProperty::UnsetValue())\n");
        src.add("                fe.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);\n        }\n    }\n\n");
        src.add("    void fieldLabel(winrt_controls::Grid const& c, winrt::hstring const& v) {\n");
        src.add("        c.Children().GetAt(0).as<winrt_controls::TextBlock>().Text(v);\n");
        src.add("        fieldColumns(c);\n");
        src.add("        formAlign(c);\n    }\n\n");
        // A section's heading is its first child, always there and collapsed
        // while it has no title, so a row's index is always one further on.
        src.add("    void sectionSetup(winrt_controls::StackPanel const& c) {\n");
        src.add("        winrt_controls::TextBlock heading;\n");
        src.add("        try {\n");
        src.add("            heading.Style(winrt_xaml::Application::Current().Resources().Lookup(winrt::box_value(L\"BodyStrongTextBlockStyle\")).as<winrt_xaml::Style>());\n");
        src.add("        } catch (...) {}\n");
        src.add("        heading.Visibility(winrt_xaml::Visibility::Collapsed);\n");
        src.add("        c.Children().Append(heading);\n    }\n\n");
        src.add("    void sectionTitle(winrt_controls::StackPanel const& c, winrt::hstring const& v) {\n");
        src.add("        auto heading = c.Children().GetAt(0).as<winrt_controls::TextBlock>();\n");
        src.add("        heading.Text(v);\n");
        src.add("        heading.Visibility(v.empty() ? winrt_xaml::Visibility::Collapsed : winrt_xaml::Visibility::Visible);\n    }\n\n");

        // ---- notices: see wui.ui.Notice ----
        // A notice is drawn over the head of the page, in a Popup, and an
        // empty spot stands where the node is so its siblings keep their
        // indices. The spot is a handle of its own, inserted and removed like
        // any child; its Loaded is what shows the notice, because only a
        // spot in a live tree can say which page it is on.
        src.add("    struct NoticeParts {\n");
        src.add("        int spot = -1;\n");
        src.add("        winrt_controls::Primitives::Popup popup{ nullptr };\n");
        src.add("        winrt_xaml::FrameworkElement host{ nullptr };\n");
        src.add("        winrt::event_token hostSized{};\n");
        src.add("        winrt::Microsoft::UI::Dispatching::DispatcherQueueTimer timer{ nullptr };\n");
        src.add("        std::wstring kind;\n");
        src.add("        std::wstring dismiss;\n");
        src.add("        int actionId = -1;\n");
        src.add("        int presentedId = -1;\n");
        src.add("        bool quiet = false;\n");
        src.add("        bool inTree = false;\n");
        src.add("        bool bottom = false;\n");
        src.add("        bool watched = false;\n        bool pointerIn = false;\n        bool focusIn = false;\n    };\n");
        src.add("    std::unordered_map<int, NoticeParts> g_notices;\n\n");
        src.add("    winrt_xaml::FrameworkElement findNamed(winrt_xaml::DependencyObject const& from, winrt::hstring const& name) {\n");
        src.add("        namespace media = winrt::Microsoft::UI::Xaml::Media;\n");
        src.add("        int n = media::VisualTreeHelper::GetChildrenCount(from);\n");
        src.add("        for (int i = 0; i < n; ++i) {\n");
        src.add("            auto child = media::VisualTreeHelper::GetChild(from, i);\n");
        src.add("            if (auto fe = child.try_as<winrt_xaml::FrameworkElement>()) { if (fe.Name() == name) return fe; }\n");
        src.add("            if (auto found = findNamed(child, name)) return found;\n        }\n");
        src.add("        return nullptr;\n    }\n\n");
        // The close button is part of the InfoBar's template, with no
        // property of its own to name it: found once the template is there.
        src.add("    void noticeNameClose(winrt_controls::InfoBar const& c, int h) {\n");
        src.add("        auto it = g_notices.find(h);\n");
        src.add("        if (it == g_notices.end() || it->second.dismiss.empty()) return;\n");
        src.add("        if (auto close = findNamed(c, L\"CloseButton\"))\n");
        src.add("            winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetName(close, winrt::hstring(it->second.dismiss));\n    }\n\n");
        // News goes away, trouble stays: a success or an info closes itself.
        // Five seconds, eight with an act -- the person has to reach it, and
        // the keyboard and Narrator are slower than a mouse -- and never while
        // the pointer or the focus is in the notice: the clock starts over
        // when both have left.
        src.add("    void noticeTimer(winrt_controls::InfoBar const& c, int h) {\n");
        src.add("        auto& n = g_notices[h];\n");
        src.add("        if (n.timer != nullptr) n.timer.Stop();\n");
        src.add("        if (!n.watched) {\n");
        src.add("            n.watched = true;\n");
        src.add("            auto touch = [h](bool pointer, bool in) {\n");
        src.add("                auto it = g_notices.find(h);\n");
        src.add("                if (it == g_notices.end()) return;\n");
        src.add("                (pointer ? it->second.pointerIn : it->second.focusIn) = in;\n");
        src.add("                if (auto e = at(h)) { if (auto bar = e.try_as<winrt_controls::InfoBar>()) noticeTimer(bar, h); }\n            };\n");
        src.add("            c.PointerEntered([touch](auto const&, auto const&) { touch(true, true); });\n");
        src.add("            c.PointerExited([touch](auto const&, auto const&) { touch(true, false); });\n");
        src.add("            c.GotFocus([touch](auto const&, auto const&) { touch(false, true); });\n");
        src.add("            c.LostFocus([touch](auto const&, auto const&) { touch(false, false); });\n        }\n");
        src.add("        if (!c.IsOpen() || n.kind == L\"warning\" || n.kind == L\"error\") return;\n");
        src.add("        if (n.pointerIn || n.focusIn) return;\n");
        src.add("        if (n.timer == nullptr) {\n");
        src.add("            n.timer = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread().CreateTimer();\n");
        src.add("            n.timer.IsRepeating(false);\n");
        src.add("            n.timer.Tick([h](auto const&, auto const&) {\n");
        src.add("                if (auto e = at(h)) { if (auto bar = e.try_as<winrt_controls::InfoBar>()) bar.IsOpen(false); }\n");
        src.add("            });\n        }\n");
        src.add("        n.timer.Interval(std::chrono::seconds(c.ActionButton() != nullptr ? 8 : 5));\n");
        src.add("        n.timer.Start();\n    }\n\n");
        // The InfoBar announces its icon and message, never its act, so an
        // "Annuler" was there for nobody listening. With an act, one
        // announcement says both -- in the application's words, both of
        // them -- under the InfoBar's own activity id, so it replaces the
        // InfoBar's rather than following it. Queued, so it is raised after
        // the InfoBar's and after the rest of this render's properties.
        src.add("    void noticeAnnounce(int h) {\n");
        src.add("        auto queue = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();\n");
        src.add("        if (queue == nullptr) return;\n");
        src.add("        queue.TryEnqueue(winrt::Microsoft::UI::Dispatching::DispatcherQueuePriority::Low, [h]() {\n");
        src.add("            namespace peers = winrt::Microsoft::UI::Xaml::Automation::Peers;\n");
        src.add("            auto e = at(h);\n");
        src.add("            auto bar = e ? e.try_as<winrt_controls::InfoBar>() : nullptr;\n");
        src.add("            if (bar == nullptr || !bar.IsOpen()) return;\n");
        src.add("            auto button = bar.ActionButton().try_as<winrt_controls::Button>();\n");
        src.add("            if (button == nullptr) return;\n");
        src.add("            auto act = winrt::unbox_value_or<winrt::hstring>(button.Content(), winrt::hstring());\n");
        src.add("            if (act.empty()) return;\n");
        src.add("            auto peer = peers::FrameworkElementAutomationPeer::FromElement(bar);\n");
        src.add("            if (peer == nullptr) return;\n");
        src.add("            peer.RaiseNotificationEvent(peers::AutomationNotificationKind::Other,\n");
        src.add("                peers::AutomationNotificationProcessing::ImportantMostRecent,\n");
        src.add("                bar.Message() + L\" \" + act, L\"InfoBarOpenedActivityId\");\n");
        src.add("        });\n    }\n\n");
        // Set by the application: quiet, so its own `false` is not reported
        // back to it as the person's.
        src.add("    void noticePresented(winrt_controls::InfoBar const& c, int h, bool v) {\n");
        src.add("        auto& n = g_notices[h];\n");
        src.add("        if (c.IsOpen() == v) return;\n");
        // A notice closed under the pointer never saw it leave.
        src.add("        if (v) { n.pointerIn = false; n.focusIn = false; }\n");
        src.add("        n.quiet = true;\n        c.IsOpen(v);\n        n.quiet = false;\n");
        src.add("        noticeTimer(c, h);\n");
        src.add("        if (v) { noticeNameClose(c, h); noticeAnnounce(h); }\n    }\n\n");
        src.add("    void noticeKind(winrt_controls::InfoBar const& c, int h, winrt::hstring const& v) {\n");
        src.add("        g_notices[h].kind = std::wstring(v.c_str());\n");
        src.add("        using winrt_controls::InfoBarSeverity;\n");
        src.add("        c.Severity(v == L\"success\" ? InfoBarSeverity::Success\n");
        src.add("            : v == L\"warning\" ? InfoBarSeverity::Warning\n");
        src.add("            : v == L\"error\" ? InfoBarSeverity::Error\n");
        src.add("            : InfoBarSeverity::Informational);\n");
        src.add("        noticeTimer(c, h);\n    }\n\n");
        src.add("    void noticeDismiss(winrt_controls::InfoBar const& c, int h, winrt::hstring const& v) {\n");
        src.add("        g_notices[h].dismiss = std::wstring(v.c_str());\n");
        src.add("        noticeNameClose(c, h);\n    }\n\n");
        // The act, at most one. Doing it closes the notice, which reports.
        src.add("    void noticeAction(winrt_controls::InfoBar const& c, int h, winrt::hstring const& v) {\n");
        src.add("        if (v.empty()) { c.ActionButton(nullptr); return; }\n");
        src.add("        auto button = c.ActionButton().try_as<winrt_controls::Button>();\n");
        src.add("        if (button == nullptr) {\n");
        src.add("            button = winrt_controls::Button();\n");
        src.add("            button.Click([h](auto const&, auto const&) {\n");
        src.add("                auto it = g_notices.find(h);\n");
        src.add("                if (it != g_notices.end() && it->second.actionId >= 0) wui_bridge_invoke_node(it->second.actionId);\n");
        src.add("                if (auto e = at(h)) { if (auto bar = e.try_as<winrt_controls::InfoBar>()) bar.IsOpen(false); }\n");
        src.add("            });\n");
        src.add("            c.ActionButton(button);\n        }\n");
        src.add("        button.Content(winrt::box_value(v));\n");
        src.add("        noticeTimer(c, h);\n    }\n\n");
        // Across the page the notice is on, inset: the content of a
        // NavigationView if it is in one, so the pane stays clear, or the
        // window's whole content.
        src.add("    void noticePlace(int h) {\n");
        src.add("        auto it = g_notices.find(h);\n");
        src.add("        if (it == g_notices.end() || it->second.host == nullptr || it->second.popup == nullptr) return;\n");
        src.add("        auto& n = it->second;\n");
        src.add("        auto bar = at(h).try_as<winrt_controls::InfoBar>();\n");
        src.add("        if (bar == nullptr) return;\n");
        src.add("        const double inset = 16;\n");
        src.add("        auto origin = n.host.TransformToVisual(nullptr).TransformPoint(winrt::Windows::Foundation::Point{ 0, 0 });\n");
        src.add("        double width = n.host.ActualWidth() - 2 * inset;\n");
        src.add("        bar.Width(width > 0 ? width : 0);\n");
        src.add("        n.popup.HorizontalOffset(origin.X + inset);\n");
        src.add("        n.popup.VerticalOffset(origin.Y + inset);\n    }\n\n");
        src.add("    void noticeHide(int h) {\n");
        src.add("        auto it = g_notices.find(h);\n");
        src.add("        if (it == g_notices.end()) return;\n");
        src.add("        auto& n = it->second;\n");
        src.add("        if (n.popup != nullptr) n.popup.IsOpen(false);\n");
        src.add("        if (n.host != nullptr && n.hostSized.value != 0) n.host.SizeChanged(n.hostSized);\n");
        src.add("        n.hostSized = winrt::event_token{};\n");
        src.add("        n.host = nullptr;\n    }\n\n");
        // An InfoBar's tint is translucent, made to sit in a page's own
        // flow; over the page, the text under it showed through. A solid
        // backing in the theme's colour, the tint over it.
        src.add("    winrt_controls::Border noticeBacking(winrt_controls::InfoBar const& bar) {\n");
        src.add("        winrt_controls::Border backing;\n");
        src.add("        try {\n");
        src.add("            backing.Background(winrt_xaml::Application::Current().Resources().Lookup(winrt::box_value(L\"SolidBackgroundFillColorBaseBrush\")).as<winrt::Microsoft::UI::Xaml::Media::Brush>());\n");
        src.add("        } catch (...) {}\n");
        src.add("        backing.CornerRadius(winrt_xaml::CornerRadius{ 4, 4, 4, 4 });\n");
        src.add("        backing.Child(bar);\n");
        src.add("        return backing;\n    }\n\n");
        src.add("    void noticeShow(int h, winrt_xaml::FrameworkElement const& spot) {\n");
        src.add("        namespace media = winrt::Microsoft::UI::Xaml::Media;\n");
        src.add("        auto it = g_notices.find(h);\n");
        src.add("        if (it == g_notices.end()) return;\n");
        src.add("        auto& n = it->second;\n");
        src.add("        auto bar = at(h).try_as<winrt_controls::InfoBar>();\n");
        src.add("        if (bar == nullptr || spot.XamlRoot() == nullptr) return;\n");
        src.add("        noticeHide(h);\n");
        src.add("        winrt_xaml::FrameworkElement host{ nullptr };\n");
        src.add("        for (auto up = media::VisualTreeHelper::GetParent(spot); up != nullptr; up = media::VisualTreeHelper::GetParent(up)) {\n");
        src.add("            if (auto nav = up.try_as<winrt_controls::NavigationView>()) {\n");
        src.add("                host = nav.Content().try_as<winrt_xaml::FrameworkElement>();\n");
        src.add("                break;\n            }\n        }\n");
        src.add("        if (host == nullptr) host = spot.XamlRoot().Content().try_as<winrt_xaml::FrameworkElement>();\n");
        src.add("        if (host == nullptr) return;\n");
        src.add("        if (n.popup == nullptr) {\n");
        src.add("            n.popup = winrt_controls::Primitives::Popup();\n");
        src.add("            n.popup.Child(noticeBacking(bar));\n");
        src.add("            bar.Loaded([h](auto const& sender, auto const&) {\n");
        src.add("                noticeNameClose(sender.template as<winrt_controls::InfoBar>(), h);\n            });\n        }\n");
        src.add("        n.popup.XamlRoot(spot.XamlRoot());\n");
        src.add("        n.host = host;\n");
        src.add("        n.hostSized = host.SizeChanged([h](auto const&, auto const&) { noticePlace(h); });\n");
        src.add("        noticePlace(h);\n");
        src.add("        n.popup.IsOpen(true);\n    }\n\n");

        // ---- dialogs: see wui.ui.Sheet and ConfirmDialog ----
        // A dialog hangs off its window, so like a notice it leaves an empty
        // spot where its node stands; the spot is what says which window.
        //
        // WinUI shows one ContentDialog per window at a time -- ShowAsync on
        // a second throws -- so dialogs wait in a queue and the next is shown
        // when the one showing has closed. A dialog the application stops
        // wanting while it waits simply leaves the queue. Nothing hides a
        // dialog to show another and brings it back later: one question at
        // a time is what a person can answer anyway.
        src.add("    struct DialogParts {\n");
        src.add("        int spot = -1;\n");
        src.add("        bool want = false;\n");
        src.add("        bool showing = false;\n");
        src.add("        bool quiet = false;\n");
        src.add("        bool wired = false;\n");
        src.add("        int presentedId = -1;\n");
        src.add("        int confirmId = -1;\n    };\n");
        src.add("    std::unordered_map<int, DialogParts> g_dialogs;\n");
        src.add("    std::vector<int> g_dialogQueue;\n");
        src.add("    int g_dialogShowing = -1;\n\n");
        src.add("    void dialogPump() {\n");
        src.add("        if (g_dialogShowing >= 0) return;\n");
        src.add("        for (size_t i = 0; i < g_dialogQueue.size(); ++i) {\n");
        src.add("            int h = g_dialogQueue[i];\n");
        src.add("            auto it = g_dialogs.find(h);\n");
        src.add("            if (it == g_dialogs.end() || !it->second.want) { g_dialogQueue.erase(g_dialogQueue.begin() + i); --i; continue; }\n");
        src.add("            auto& d = it->second;\n");
        // A spot not yet in a live tree has no window to say: the dialog
        // keeps its place, and the spot's Loaded pumps again.
        src.add("            auto spot = d.spot >= 0 ? at(d.spot) : nullptr;\n");
        src.add("            if (spot == nullptr || spot.XamlRoot() == nullptr) continue;\n");
        src.add("            auto dialog = at(h).try_as<winrt_controls::ContentDialog>();\n");
        src.add("            if (dialog == nullptr) { g_dialogQueue.erase(g_dialogQueue.begin() + i); --i; continue; }\n");
        src.add("            g_dialogQueue.erase(g_dialogQueue.begin() + i);\n");
        src.add("            if (!d.wired) {\n");
        src.add("                d.wired = true;\n");
        src.add("                dialog.Closed([h](auto const&, winrt_controls::ContentDialogClosedEventArgs const& args) {\n");
        src.add("                    auto found = g_dialogs.find(h);\n");
        src.add("                    if (g_dialogShowing == h) g_dialogShowing = -1;\n");
        src.add("                    if (found != g_dialogs.end()) {\n");
        src.add("                        auto& d = found->second;\n");
        src.add("                        d.showing = false;\n");
        src.add("                        bool quiet = d.quiet;\n");
        src.add("                        d.quiet = false;\n");
        src.add("                        if (!quiet) {\n");
        src.add("                            d.want = false;\n");
        src.add("                            if (args.Result() == winrt_controls::ContentDialogResult::Primary && d.confirmId >= 0)\n");
        src.add("                                wui_bridge_invoke_node(d.confirmId);\n");
        src.add("                            if (d.presentedId >= 0) wui_bridge_invoke_node_bool(d.presentedId, false);\n");
        src.add("                        }\n                    }\n");
        src.add("                    dialogPump();\n");
        src.add("                });\n            }\n");
        src.add("            dialog.XamlRoot(spot.XamlRoot());\n");
        src.add("            d.showing = true;\n");
        src.add("            g_dialogShowing = h;\n");
        src.add("            dialog.ShowAsync();\n");
        src.add("            return;\n        }\n    }\n\n");
        src.add("    void dialogPresented(winrt_controls::ContentDialog const& c, int h, bool v) {\n");
        src.add("        auto& d = g_dialogs[h];\n");
        src.add("        if (d.want == v) return;\n");
        src.add("        d.want = v;\n");
        src.add("        if (v) {\n");
        src.add("            g_dialogQueue.push_back(h);\n");
        src.add("            dialogPump();\n");
        src.add("        } else if (d.showing) {\n");
        // The application's own false: not reported back to it.
        src.add("            d.quiet = true;\n");
        src.add("            c.Hide();\n        }\n    }\n\n");
        src.add("    void dialogTitle(winrt_controls::ContentDialog const& c, winrt::hstring const& v) {\n");
        src.add("        c.Title(v.empty() ? nullptr : winrt::box_value(v));\n    }\n\n");
        src.add("    void dialogMessage(winrt_controls::ContentDialog const& c, winrt::hstring const& v) {\n");
        src.add("        if (v.empty()) { c.Content(nullptr); return; }\n");
        src.add("        winrt_controls::TextBlock text;\n");
        src.add("        text.Text(v);\n");
        src.add("        text.TextWrapping(winrt_xaml::TextWrapping::Wrap);\n");
        src.add("        c.Content(text);\n    }\n\n");
        src.add("    void dialogDestructive(winrt_controls::ContentDialog const& c, bool v) {\n");
        src.add("        c.DefaultButton(v ? winrt_controls::ContentDialogButton::Close : winrt_controls::ContentDialogButton::Primary);\n    }\n\n");
        // A ContentDialog made in code has the old template until it is given
        // the current style by name -- the one XAML would have applied.
        src.add("    void dialogSetup(winrt_controls::ContentDialog const& c) {\n");
        src.add("        try {\n");
        src.add("            c.Style(winrt_xaml::Application::Current().Resources().Lookup(winrt::box_value(L\"DefaultContentDialogStyle\")).as<winrt_xaml::Style>());\n");
        src.add("        } catch (...) {}\n");
        src.add("        c.DefaultButton(winrt_controls::ContentDialogButton::Primary);\n    }\n\n");
        // A sheet's children, one under the other, in its content.
        // A sheet holds a form, and a form's widest rows -- seven weekdays and
        // a stepper with its label beside it -- did not fit the 548 a
        // ContentDialog allows by default, nor 640.
        // Raised for sheets alone, in the dialog's own resources, where the
        // template looks it up; a question keeps the platform's width.
        // The rows scroll: the dialog template's own ScrollViewer has vertical
        // scrolling disabled, so a form taller than the window ran off its
        // bottom with Annuler and Enregistrer under it. Ours is capped at the
        // window's height less the dialog's title, buttons and margins, again
        // whenever the window changes size. See sheetFit.
        src.add("    std::unordered_map<void*, winrt::event_token> g_sheetRootTokens;\n\n");
        src.add("    winrt_controls::StackPanel sheetContent(winrt_controls::ContentDialog const& dialog) {\n");
        src.add("        if (auto scroll = dialog.Content().try_as<winrt_controls::ScrollViewer>())\n");
        src.add("            return scroll.Content().try_as<winrt_controls::StackPanel>();\n");
        src.add("        return dialog.Content().try_as<winrt_controls::StackPanel>();\n    }\n\n");
        src.add("    void sheetFit(winrt_controls::ContentDialog const& dialog) {\n");
        src.add("        auto scroll = dialog.Content().try_as<winrt_controls::ScrollViewer>();\n");
        src.add("        auto root = dialog.XamlRoot();\n");
        src.add("        if (scroll == nullptr || root == nullptr) return;\n");
        src.add("        double room = root.Size().Height - 220.0;\n");
        src.add("        scroll.MaxHeight(room < 120.0 ? 120.0 : room);\n    }\n\n");
        src.add("    void sheetSetup(winrt_controls::ContentDialog const& c) {\n");
        src.add("        c.Resources().Insert(winrt::box_value(L\"ContentDialogMaxWidth\"), winrt::box_value(720.0));\n");
        src.add("        winrt_controls::StackPanel content;\n");
        src.add("        content.Spacing(12);\n");
        src.add("        content.Tag(winrt::box_value(L\"sheet\"));\n");
        src.add("        winrt_controls::ScrollViewer scroll;\n");
        src.add("        scroll.VerticalScrollBarVisibility(winrt_controls::ScrollBarVisibility::Auto);\n");
        src.add("        scroll.HorizontalScrollBarVisibility(winrt_controls::ScrollBarVisibility::Disabled);\n");
        // The scroll bar overlays the rows' right edge; this keeps it off them.
        src.add("        content.Padding(winrt_xaml::Thickness{ 0, 0, 16, 0 });\n");
        src.add("        scroll.Content(content);\n");
        src.add("        c.Content(scroll);\n");
        src.add("        c.Opened([](winrt_controls::ContentDialog const& sender, auto const&) {\n");
        src.add("            sheetFit(sender);\n");
        src.add("            auto root = sender.XamlRoot();\n");
        src.add("            if (root == nullptr) return;\n");
        src.add("            winrt::weak_ref<winrt_controls::ContentDialog> weak = sender;\n");
        src.add("            g_sheetRootTokens[winrt::get_abi(sender)] = root.Changed([weak](auto const&, auto const&) {\n");
        src.add("                if (auto d = weak.get()) sheetFit(d);\n            });\n        });\n");
        src.add("        c.Closed([](winrt_controls::ContentDialog const& sender, auto const&) {\n");
        src.add("            auto found = g_sheetRootTokens.find(winrt::get_abi(sender));\n");
        src.add("            if (found == g_sheetRootTokens.end()) return;\n");
        src.add("            if (auto root = sender.XamlRoot()) root.Changed(found->second);\n");
        src.add("            g_sheetRootTokens.erase(found);\n        });\n    }\n\n");

        // ---- Stepper and DateInput: see wui.ui.Stepper and DateInput ----
        // A value the application sets, or a bound that coerces it, is not
        // the person's edit: those changes are made quiet.
        src.add("    std::unordered_map<int, bool> g_valueQuiet;\n\n");
        src.add("    void stepperSetup(winrt_controls::NumberBox const& c) {\n");
        src.add("        c.SpinButtonPlacementMode(winrt_controls::NumberBoxSpinButtonPlacementMode::Inline);\n");
        src.add("        c.ValidationMode(winrt_controls::NumberBoxValidationMode::InvalidInputOverwritten);\n");
        src.add("        c.SmallChange(1);\n");
        src.add("        c.LargeChange(1);\n    }\n\n");
        src.add("    void stepperValue(winrt_controls::NumberBox const& c, int h, int v) {\n");
        src.add("        if (!std::isnan(c.Value()) && std::lround(c.Value()) == v) return;\n");
        src.add("        g_valueQuiet[h] = true; c.Value(v); g_valueQuiet[h] = false;\n    }\n\n");
        src.add("    void stepperBound(winrt_controls::NumberBox const& c, int h, bool upper, int v) {\n");
        src.add("        g_valueQuiet[h] = true;\n");
        src.add("        if (upper) c.Maximum(v); else c.Minimum(v);\n");
        src.add("        g_valueQuiet[h] = false;\n    }\n\n");
        // A day as noon UTC: the same day in every time zone.
        src.add("    bool dayOf(winrt::hstring const& v, winrt::Windows::Foundation::DateTime& out) {\n");
        src.add("        int y = 0, m = 0, d = 0;\n");
        src.add("        if (swscanf_s(v.c_str(), L\"%d-%d-%d\", &y, &m, &d) != 3) return false;\n");
        src.add("        std::tm t{};\n");
        src.add("        t.tm_year = y - 1900; t.tm_mon = m - 1; t.tm_mday = d; t.tm_hour = 12;\n");
        src.add("        auto secs = _mkgmtime(&t);\n");
        src.add("        if (secs == -1) return false;\n");
        src.add("        out = winrt::clock::from_time_t(secs);\n");
        src.add("        return true;\n    }\n\n");
        // The day the picker shows, which is the local calendar's.
        src.add("    std::string dayText(winrt::Windows::Foundation::DateTime const& when) {\n");
        src.add("        auto secs = winrt::clock::to_time_t(when);\n");
        src.add("        std::tm t{};\n");
        src.add("        localtime_s(&t, &secs);\n");
        src.add("        char buf[16];\n");
        src.add("        snprintf(buf, sizeof buf, \"%04d-%02d-%02d\", t.tm_year + 1900, t.tm_mon + 1, t.tm_mday);\n");
        src.add("        return buf;\n    }\n\n");
        src.add("    void dateValue(winrt_controls::CalendarDatePicker const& c, int h, winrt::hstring const& v) {\n");
        src.add("        auto now = c.Date();\n");
        src.add("        std::string want = winrt::to_string(v);\n");
        src.add("        if (now ? dayText(now.Value()) == want : want.empty()) return;\n");
        src.add("        g_valueQuiet[h] = true;\n");
        src.add("        winrt::Windows::Foundation::DateTime day;\n");
        src.add("        if (dayOf(v, day)) c.Date(day); else c.Date(nullptr);\n");
        src.add("        g_valueQuiet[h] = false;\n    }\n\n");
        // The week starts where the person's own settings say -- a Monday in
        // France -- and not where the application's language would: the
        // calendar opened on a Sunday-first week on a French desktop.
        src.add("    void dateSetup(winrt_controls::CalendarDatePicker const& c) {\n");
        src.add("        wchar_t first[4] = {};\n");
        src.add("        if (GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, LOCALE_IFIRSTDAYOFWEEK, first, 4) > 0) {\n");
        src.add("            int monday0 = first[0] - L'0';\n");
        src.add("            c.FirstDayOfWeek((winrt::Windows::Globalization::DayOfWeek)((monday0 + 1) % 7));\n        }\n    }\n\n");
        // ---- a text's background ----
        // A TextBlock paints no background, so `backgroundColor` on a Text --
        // an avatar's initials on a coloured disc -- drew the initials alone.
        // Such a text is framed: a Border with the colour and the radius, the
        // TextBlock centred in it, and the Border is what its parent holds.
        // The handle stays the TextBlock's, so every setter still finds it;
        // `placed` is what insert and remove use. The text's own size moves
        // to the frame, which is what a sized avatar means.
        src.add("    std::unordered_map<int, winrt_controls::Border> g_frames;\n\n");
        // A switch asked for its label inline (`wui.labelPlacement`): a row of
        // the label, which takes the width, and the switch at the trailing
        // edge. Made when the label arrives (before the insert); the row is
        // what the parent holds, the handle stays the switch's. See
        // `toggleLabel`.
        src.add("    std::unordered_map<int, winrt_controls::Grid> g_toggleRows;\n\n");
        src.add("    winrt_xaml::UIElement placed(int h) {\n");
        src.add("        auto f = g_frames.find(h);\n");
        src.add("        if (f != g_frames.end()) return f->second;\n");
        src.add("        auto r = g_toggleRows.find(h);\n");
        src.add("        return r != g_toggleRows.end() ? winrt_xaml::UIElement(r->second) : at(h);\n    }\n\n");
        src.add("    winrt_controls::Border frameFor(int h, winrt_controls::TextBlock const& text) {\n");
        src.add("        auto found = g_frames.find(h);\n");
        src.add("        if (found != g_frames.end()) return found->second;\n");
        src.add("        winrt_controls::Border frame;\n");
        src.add("        if (!std::isnan(text.Width())) { frame.Width(text.Width()); text.ClearValue(winrt_xaml::FrameworkElement::WidthProperty()); }\n");
        src.add("        if (!std::isnan(text.Height())) { frame.Height(text.Height()); text.ClearValue(winrt_xaml::FrameworkElement::HeightProperty()); }\n");
        src.add("        frame.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);\n");
        src.add("        text.HorizontalAlignment(winrt_xaml::HorizontalAlignment::Center);\n");
        src.add("        text.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);\n");
        // Already in a panel: the frame takes its place there, columns and all.
        src.add("        if (auto panel = text.Parent().try_as<winrt_controls::Panel>()) {\n");
        src.add("            uint32_t i = 0;\n");
        src.add("            if (panel.Children().IndexOf(text, i)) {\n");
        src.add("                winrt_controls::Grid::SetColumn(frame, winrt_controls::Grid::GetColumn(text));\n");
        src.add("                winrt_controls::Grid::SetRow(frame, winrt_controls::Grid::GetRow(text));\n");
        src.add("                panel.Children().SetAt(i, frame);\n            }\n        }\n");
        src.add("        frame.Child(text);\n");
        src.add("        g_frames[h] = frame;\n");
        src.add("        return frame;\n    }\n\n");
        // A size for a framed text is the frame's, whichever arrives first.
        src.add("    void sizeTo(winrt_xaml::FrameworkElement const& c, int h, bool wide, double v) {\n");
        src.add("        auto f = g_frames.find(h);\n");
        src.add("        winrt_xaml::FrameworkElement target = f != g_frames.end() ? winrt_xaml::FrameworkElement(f->second) : c;\n");
        src.add("        if (wide) target.Width(v); else target.Height(v);\n    }\n\n");
        // Padding, on whatever has it: four edges, top right bottom left.
        src.add("    void padTo(winrt_xaml::UIElement const& e, winrt_xaml::Thickness const& t) {\n");
        src.add("        if (auto b = e.try_as<winrt_controls::Border>()) { b.Padding(t); return; }\n");
        src.add("        if (auto g = e.try_as<winrt_controls::Grid>()) { g.Padding(t); return; }\n");
        src.add("        if (auto s = e.try_as<winrt_controls::StackPanel>()) { s.Padding(t); return; }\n");
        src.add("        if (auto x = e.try_as<winrt_controls::TextBlock>()) { x.Padding(t); return; }\n");
        src.add("        if (auto c = e.try_as<winrt_controls::Control>()) c.Padding(t);\n    }\n\n");
        src.add("    void borderTo(winrt_xaml::UIElement const& e, winrt::Microsoft::UI::Xaml::Media::Brush const& brush, double width) {\n");
        src.add("        winrt_xaml::Thickness t{ width, width, width, width };\n");
        src.add("        if (auto b = e.try_as<winrt_controls::Border>()) { b.BorderBrush(brush); b.BorderThickness(t); return; }\n");
        src.add("        if (auto g = e.try_as<winrt_controls::Grid>()) { g.BorderBrush(brush); g.BorderThickness(t); return; }\n");
        src.add("        if (auto s = e.try_as<winrt_controls::StackPanel>()) { s.BorderBrush(brush); s.BorderThickness(t); return; }\n");
        src.add("        if (auto c = e.try_as<winrt_controls::Control>()) { c.BorderBrush(brush); c.BorderThickness(t); }\n    }\n\n");
        // A radius goes to whatever has corners to round.
        src.add("    void roundCorners(winrt_xaml::UIElement const& e, double r) {\n");
        src.add("        if (r <= 0) return;\n");
        src.add("        winrt_xaml::CornerRadius cr{ r, r, r, r };\n");
        src.add("        if (auto b = e.try_as<winrt_controls::Border>()) { b.CornerRadius(cr); return; }\n");
        src.add("        if (auto g = e.try_as<winrt_controls::Grid>()) { g.CornerRadius(cr); return; }\n");
        src.add("        if (auto s = e.try_as<winrt_controls::StackPanel>()) { s.CornerRadius(cr); return; }\n");
        src.add("        if (auto c = e.try_as<winrt_controls::Control>()) c.CornerRadius(cr);\n    }\n\n");
        // ---- ReorderList: see wui.ui.ReorderList ----
        // The list reports a move and never performs one: a dragged row is
        // put back, and the next tree draws the order the data now has.
        src.add("    struct ReorderParts {\n");
        src.add("        int moveId = -1;\n");
        src.add("        std::wstring up;\n");
        src.add("        std::wstring down;\n");
        src.add("        int dragFrom = -1;\n");
        src.add("        winrt::Windows::Foundation::IInspectable dragged{ nullptr };\n");
        src.add("        bool wired = false;\n    };\n");
        src.add("    std::unordered_map<int, ReorderParts> g_reorders;\n\n");
        // A row is ordinary views, and its container had no name: Narrator
        // met "élément de liste" and nothing else. Named by the texts in it,
        // "1 Lou", when the container is made and again when it takes the
        // focus, since a row's texts change -- its turn number does on
        // every move.
        src.add("    void rowTexts(winrt_xaml::DependencyObject const& from, std::wstring& out) {\n");
        src.add("        namespace media = winrt::Microsoft::UI::Xaml::Media;\n");
        src.add("        if (auto text = from.try_as<winrt_controls::TextBlock>()) {\n");
        src.add("            if (!text.Text().empty()) { if (!out.empty()) out += L\" \"; out += text.Text().c_str(); }\n");
        src.add("            return;\n        }\n");
        // By the logical children, not the visual tree: a container is
        // made before its content has one.
        src.add("        if (auto panel = from.try_as<winrt_controls::Panel>()) { for (auto const& child : panel.Children()) rowTexts(child, out); return; }\n");
        src.add("        if (auto border = from.try_as<winrt_controls::Border>()) { if (auto child = border.Child()) rowTexts(child, out); return; }\n");
        src.add("        if (auto holder = from.try_as<winrt_controls::ContentControl>()) { if (auto child = holder.Content().try_as<winrt_xaml::DependencyObject>()) rowTexts(child, out); return; }\n");
        src.add("        (void)sizeof(media::VisualTreeHelper);\n    }\n\n");
        src.add("    void rowName(winrt_controls::ListViewItem const& row) {\n");
        src.add("        std::wstring said;\n");
        src.add("        if (auto content = row.Content().try_as<winrt_xaml::DependencyObject>()) rowTexts(content, said);\n");
        src.add("        winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetName(row, winrt::hstring(said));\n    }\n\n");
        src.add("    void reorderSetup(winrt_controls::ListView const& c) {\n");
        // Named once the container exists and the row's texts are in it.
        src.add("        c.ContainerContentChanging([](auto const&, winrt_controls::ContainerContentChangingEventArgs const& args) {\n");
        src.add("            auto row = args.ItemContainer().try_as<winrt_controls::ListViewItem>();\n");
        src.add("            auto queue = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();\n");
        src.add("            if (row == nullptr || queue == nullptr) return;\n");
        src.add("            queue.TryEnqueue(winrt::Microsoft::UI::Dispatching::DispatcherQueuePriority::Low, [row]() { rowName(row); });\n");
        src.add("        });\n");
        src.add("        c.SelectionMode(winrt_controls::ListViewSelectionMode::None);\n");
        src.add("        c.CanDragItems(true);\n");
        src.add("        c.CanReorderItems(true);\n");
        src.add("        c.AllowDrop(true);\n    }\n\n");
        src.add("    void reorderLabel(int h, bool up, winrt::hstring const& v) {\n");
        src.add("        auto& r = g_reorders[h];\n");
        src.add("        (up ? r.up : r.down) = std::wstring(v.c_str());\n    }\n\n");
        // The row a focus or a click is in: the container it sits under.
        src.add("    int reorderRowOf(winrt_controls::ListView const& list, winrt::Windows::Foundation::IInspectable const& from) {\n");
        src.add("        namespace media = winrt::Microsoft::UI::Xaml::Media;\n");
        src.add("        auto at_ = from.try_as<winrt_xaml::DependencyObject>();\n");
        src.add("        while (at_ != nullptr) {\n");
        src.add("            if (auto item = at_.try_as<winrt_controls::ListViewItem>()) return list.IndexFromContainer(item);\n");
        src.add("            if (at_ == list) return -1;\n");
        src.add("            at_ = media::VisualTreeHelper::GetParent(at_);\n        }\n");
        src.add("        return -1;\n    }\n\n");
        // A move asked for one step at a time keeps the focus on the row
        // that moved, once the next tree has put it in its place.
        src.add("    void reorderMove(int h, int from, int to, bool refocus) {\n");
        src.add("        auto it = g_reorders.find(h);\n");
        src.add("        if (it == g_reorders.end() || it->second.moveId < 0 || from == to) return;\n");
        src.add("        std::string said = std::to_string(from) + \",\" + std::to_string(to);\n");
        src.add("        wui_bridge_invoke_node_string(it->second.moveId, said.c_str());\n");
        src.add("        if (!refocus) return;\n");
        src.add("        auto queue = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();\n");
        src.add("        if (queue == nullptr) return;\n");
        src.add("        queue.TryEnqueue(winrt::Microsoft::UI::Dispatching::DispatcherQueuePriority::Low, [h, to]() {\n");
        src.add("            auto e = at(h);\n");
        src.add("            auto list = e ? e.try_as<winrt_controls::ListView>() : nullptr;\n");
        src.add("            if (list == nullptr) return;\n");
        src.add("            list.UpdateLayout();\n");
        src.add("            if (auto row = list.ContainerFromIndex(to).try_as<winrt_controls::Control>()) row.Focus(winrt_xaml::FocusState::Keyboard);\n");
        src.add("        });\n    }\n\n");
        src.add("    void reorderWire(winrt_controls::ListView const& list, int h) {\n");
        src.add("        auto& r = g_reorders[h];\n");
        src.add("        if (r.wired) return;\n");
        src.add("        r.wired = true;\n");

        src.add("        list.GotFocus([](auto const& sender, winrt_xaml::RoutedEventArgs const& args) {\n");
        src.add("            auto list = sender.template as<winrt_controls::ListView>();\n");
        src.add("            int row = reorderRowOf(list, args.OriginalSource());\n");
        src.add("            if (row < 0) return;\n");
        src.add("            if (auto item = list.ContainerFromIndex(row).try_as<winrt_controls::ListViewItem>()) rowName(item);\n");
        src.add("        });\n");
        src.add("        list.DragItemsStarting([h](auto const& sender, winrt_controls::DragItemsStartingEventArgs const& args) {\n");
        src.add("            auto& r = g_reorders[h];\n");
        src.add("            r.dragged = nullptr; r.dragFrom = -1;\n");
        src.add("            if (args.Items().Size() != 1) return;\n");
        src.add("            auto list = sender.template as<winrt_controls::ListView>();\n");
        src.add("            uint32_t i = 0;\n");
        src.add("            if (list.Items().IndexOf(args.Items().GetAt(0), i)) { r.dragged = args.Items().GetAt(0); r.dragFrom = (int)i; }\n");
        src.add("        });\n");
        src.add("        list.DragItemsCompleted([h](auto const& sender, auto const&) {\n");
        src.add("            auto& r = g_reorders[h];\n");
        src.add("            auto dragged = r.dragged; int from = r.dragFrom;\n");
        src.add("            r.dragged = nullptr; r.dragFrom = -1;\n");
        src.add("            if (dragged == nullptr) return;\n");
        src.add("            auto list = sender.template as<winrt_controls::ListView>();\n");
        src.add("            uint32_t now = 0;\n");
        src.add("            if (!list.Items().IndexOf(dragged, now) || (int)now == from) return;\n");
        src.add("            list.Items().RemoveAt(now);\n");
        src.add("            list.Items().InsertAt((uint32_t)from, dragged);\n");
        src.add("            reorderMove(h, from, (int)now, false);\n");
        src.add("        });\n");
        // Alt+Up / Alt+Down move the focused row: the keyboard's way.
        src.add("        list.PreviewKeyDown([h](auto const& sender, winrt::Microsoft::UI::Xaml::Input::KeyRoutedEventArgs const& args) {\n");
        src.add("            using winrt::Windows::System::VirtualKey;\n");
        src.add("            if (args.Key() != VirtualKey::Up && args.Key() != VirtualKey::Down) return;\n");
        src.add("            if ((GetKeyState(VK_MENU) & 0x8000) == 0) return;\n");
        src.add("            auto list = sender.template as<winrt_controls::ListView>();\n");
        src.add("            auto focused = winrt::Microsoft::UI::Xaml::Input::FocusManager::GetFocusedElement(list.XamlRoot());\n");
        src.add("            int row = reorderRowOf(list, focused);\n");
        src.add("            if (row < 0) return;\n");
        src.add("            int to = args.Key() == VirtualKey::Up ? row - 1 : row + 1;\n");
        src.add("            args.Handled(true);\n");
        src.add("            if (to < 0 || to >= (int)list.Items().Size()) return;\n");
        src.add("            reorderMove(h, row, to, true);\n");
        src.add("        });\n");
        // The two moves in a row's context menu, named by the application;
        // without both names there is no menu, and the drag stays.
        src.add("        list.ContextRequested([h](auto const& sender, winrt_xaml::Input::ContextRequestedEventArgs const& args) {\n");
        src.add("            auto& r = g_reorders[h];\n");
        src.add("            if (r.up.empty() || r.down.empty()) return;\n");
        src.add("            auto list = sender.template as<winrt_controls::ListView>();\n");
        src.add("            int row = reorderRowOf(list, args.OriginalSource());\n");
        src.add("            if (row < 0) return;\n");
        src.add("            auto container = list.ContainerFromIndex(row).try_as<winrt_xaml::UIElement>();\n");
        src.add("            if (container == nullptr) return;\n");
        src.add("            int last = (int)list.Items().Size() - 1;\n");
        src.add("            winrt_controls::MenuFlyout menu;\n");
        src.add("            winrt_controls::MenuFlyoutItem up;\n");
        src.add("            up.Text(winrt::hstring(r.up));\n");
        src.add("            up.IsEnabled(row > 0);\n");
        src.add("            up.Click([h, row](auto const&, auto const&) { reorderMove(h, row, row - 1, true); });\n");
        src.add("            winrt_controls::MenuFlyoutItem down;\n");
        src.add("            down.Text(winrt::hstring(r.down));\n");
        src.add("            down.IsEnabled(row < last);\n");
        src.add("            down.Click([h, row](auto const&, auto const&) { reorderMove(h, row, row + 1, true); });\n");
        src.add("            menu.Items().Append(up);\n");
        src.add("            menu.Items().Append(down);\n");
        src.add("            winrt::Windows::Foundation::Point where{};\n");
        src.add("            if (args.TryGetPosition(container, where)) {\n");
        src.add("                winrt_controls::Primitives::FlyoutShowOptions options;\n");
        src.add("                options.Position(where);\n");
        src.add("                menu.ShowAt(container, options);\n");
        src.add("            } else {\n");
        src.add("                menu.Placement(winrt_controls::Primitives::FlyoutPlacementMode::BottomEdgeAlignedLeft);\n");
        src.add("                menu.ShowAt(container.as<winrt_xaml::FrameworkElement>());\n            }\n");
        src.add("            args.Handled(true);\n");
        src.add("        });\n    }\n\n");
        // ---- Menu and Divider: see wui.ui.Menu and Divider ----
        src.add("    void menuSetup(winrt_controls::DropDownButton const& c) {\n");
        src.add("        winrt_controls::MenuFlyout flyout;\n");
        src.add("        flyout.Placement(winrt_controls::Primitives::FlyoutPlacementMode::BottomEdgeAlignedLeft);\n");
        src.add("        c.Flyout(flyout);\n    }\n\n");
        src.add("    void dividerSetup(winrt_controls::Border const& c) {\n");
        src.add("        c.Height(1);\n");
        src.add("        c.HorizontalAlignment(winrt_xaml::HorizontalAlignment::Stretch);\n");
        src.add("        c.Margin(winrt_xaml::Thickness{ 0, 4, 0, 4 });\n");
        src.add("        try {\n");
        src.add("            c.Background(winrt_xaml::Application::Current().Resources().Lookup(winrt::box_value(L\"DividerStrokeColorDefaultBrush\")).as<winrt::Microsoft::UI::Xaml::Media::Brush>());\n");
        src.add("        } catch (...) {}\n    }\n\n");
        src.add("    void dateBound(winrt_controls::CalendarDatePicker const& c, bool upper, winrt::hstring const& v) {\n");
        src.add("        winrt::Windows::Foundation::DateTime day;\n");
        src.add("        if (!dayOf(v, day)) return;\n");
        src.add("        if (upper) c.MaxDate(day); else c.MinDate(day);\n    }\n");
        src.add("}\n\n");

        src.add("static void dialogMount(int parent, int child, int index) {\n");
        src.add("    auto& d = g_dialogs[child];\n");
        src.add("    if (d.spot < 0) {\n");
        src.add("        winrt_controls::Border spot;\n");
        src.add("        d.spot = put(spot);\n");
        src.add("        spot.Loaded([](auto const&, auto const&) { dialogPump(); });\n    }\n");
        src.add("    wui_node_insert(parent, d.spot, index);\n}\n\n");

        // Mounting a notice is mounting its spot. Outside the namespace
        // because it goes through `wui_node_insert` like any child.
        //
        // In a ZStack -- a Grid with no tag, the shell a screen keeps its one
        // notice in -- the notice needs no Popup: the ZStack's cell already
        // covers the page, so the InfoBar sits in the tree over
        // the content, and is in the tab order after it. A Popup never is:
        // Tab and F6 both pass it by, and its act was out of the keyboard's
        // reach. The Popup stays for a notice anywhere else.
        src.add("static void noticeMount(int parent, int child, int index) {\n");
        src.add("    auto& n = g_notices[child];\n");
        src.add("    auto p = at(parent);\n");
        src.add("    bool overlay = p != nullptr && p.try_as<winrt_controls::Grid>() != nullptr && tagText(p).empty();\n");
        src.add("    if (n.spot < 0 && overlay) {\n");
        src.add("        auto bar = at(child).as<winrt_controls::InfoBar>();\n");
        src.add("        auto backing = noticeBacking(bar);\n");
        // Across the head of the shell, Windows' place for an InfoBar; or,
        // asked for (`wui.placement` "bottomCenter"), at its foot, centred and
        // no wider than a sentence.
        src.add("        if (n.bottom) {\n");
        src.add("            backing.VerticalAlignment(winrt_xaml::VerticalAlignment::Bottom);\n");
        src.add("            backing.HorizontalAlignment(winrt_xaml::HorizontalAlignment::Center);\n");
        src.add("            backing.MaxWidth(560);\n");
        src.add("            backing.Margin(winrt_xaml::Thickness{ 16, 0, 16, 16 });\n");
        src.add("        } else {\n");
        src.add("            backing.VerticalAlignment(winrt_xaml::VerticalAlignment::Top);\n");
        src.add("            backing.Margin(winrt_xaml::Thickness{ 16, 16, 16, 0 });\n        }\n");
        src.add("        n.inTree = true;\n");
        src.add("        n.spot = put(backing);\n    }\n");
        src.add("    if (n.spot < 0) {\n");
        src.add("        winrt_controls::Border spot;\n");
        src.add("        n.spot = put(spot);\n");
        src.add("        spot.Loaded([child](auto const& sender, auto const&) {\n");
        src.add("            noticeShow(child, sender.template as<winrt_xaml::FrameworkElement>());\n        });\n");
        src.add("        spot.Unloaded([child](auto const&, auto const&) { noticeHide(child); });\n    }\n");
        src.add("    wui_node_insert(parent, n.spot, index);\n}\n\n");

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
        // No title of its own: the application's, from the main window.
        src.add("        auto said = winrt::hstring(wui::runtime::fromUtf8(title));\n");
        src.add("        auto primary = g_windowOf.find(g_primaryRoot);\n");
        src.add("        window.Title(said.empty() && primary != g_windowOf.end() ? primary->second.Title() : said);\n");
        src.add("        winrt_controls::Grid root;\n");
        src.add("        root.Tag(winrt::box_value(L\"column\"));\n");
        src.add("        int handle = registerRoot(root);\n");
        src.add("        window.Content(root);\n");
        src.add("        // The handle crosses by value: the closure must not hold the window\n");
        src.add("        // (a window owning a handler owning the window is a cycle WinRT has\n");
        src.add("        // no collector to break -- the same rule as the sender lambdas below).\n");
        src.add("        window.Closed([handle](auto const&, auto const&) {\n");
        src.add("            g_windowOf.erase(handle);\n");
        src.add("            wui_bridge_surface_closed(handle);\n        });\n");
        src.add("        g_windows.push_back(window);\n");
        src.add("        g_windowOf[handle] = window;\n");
        src.add("        window.Activate();\n");
        src.add("        return handle;\n    }\n\n");
        src.add(SurfacesCpp.source());
        src.add("}}\n\n");
        src.add(SurfacesCpp.externs());

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
            // Labels beside the icons, as a desktop bar draws them: a command
            // with no icon would otherwise show nothing until the bar opens.
            if (winui == "CommandBar") {
                src.add("        c.DefaultLabelPosition(winrt_controls::CommandBarDefaultLabelPosition::Right);\n");
                src.add("        c.HorizontalAlignment(winrt_xaml::HorizontalAlignment::Stretch);\n");
                src.add("        c.VerticalContentAlignment(winrt_xaml::VerticalAlignment::Center);\n");
            }
            // A text wraps at the width it is given: a paragraph in a column
            // was otherwise cut at the window's edge. In a row it is given all
            // it asks for, and stays on one line.
            if (winui == "TextBlock") src.add("        c.TextWrapping(winrt_xaml::TextWrapping::Wrap);\n");
            if (type == "Column") src.add("        c.Tag(winrt::box_value(L\"column\"));\n");
            if (type == "Field") src.add("        fieldSetup(c);\n");
            if (type == "Section") src.add("        sectionSetup(c);\n");
            if (type == "Sheet" || type == "ConfirmDialog") src.add("        dialogSetup(c);\n");
            if (type == "Sheet") src.add("        sheetSetup(c);\n");
            if (type == "Stepper") src.add("        stepperSetup(c);\n");
            if (type == "DateInput") src.add("        dateSetup(c);\n");
            if (type == "Menu") src.add("        menuSetup(c);\n");
            if (type == "Divider") src.add("        dividerSetup(c);\n");
            if (type == "ReorderList") src.add("        reorderSetup(c);\n");
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
            // A label spoken and not drawn -- a control's in a toolbar, where
            // its header would not fit. Set by `WinUISink`, never declared:
            // every element has the attached property, and no control a member.
            if (kind == "KString") {
                src.add("    if (k == \"automationName\") {\n");
                src.add("        if (auto el = e.try_as<winrt_xaml::DependencyObject>())\n");
                src.add("            winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetName(el, text);\n");
                src.add("        return;\n    }\n\n");
                // A form row's label: drawn in the form's label column, and the
                // control's name as well, so Narrator reads the label first.
                src.add("    if (k == \"inlineLabel\") {\n");
                src.add("        auto row = g_inlineRows.find(h);\n");
                src.add("        if (row == g_inlineRows.end()) {\n");
                src.add("            winrt_controls::StackPanel made;\n");
                src.add("            made.Orientation(winrt_controls::Orientation::Horizontal);\n");
                src.add("            made.Spacing(8);\n");
                src.add("            made.Children().Append(labelBlock());\n");
                src.add("            row = g_inlineRows.emplace(h, made).first;\n        }\n");
                src.add("        row->second.Children().GetAt(0).as<winrt_controls::TextBlock>().Text(text);\n");
                src.add("        winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetName(e, text);\n");
                src.add("        return;\n    }\n\n");
                // `wui.placement`, through the sink: set before the insert,
                // which is where the notice is placed. See noticeMount.
                src.add("    if (k == \"noticePlacement\") {\n");
                src.add("        g_notices[h].bottom = (text == L\"bottomCenter\");\n");
                src.add("        return;\n    }\n\n");
                // A switch that is its label and its state (`wui.labelPlacement`
                // "inline", wherever it stands): no "On"/"Off" beside it --
                // Narrator says the state from the Toggle pattern, in the
                // system's words -- and none of the theme's minimum width,
                // which was there to hold that text and would leave a gap.
                src.add("    if (k == \"toggleBare\") {\n");
                src.add("        if (auto sw = e.try_as<winrt_controls::ToggleSwitch>()) {\n");
                src.add("            sw.OnContent(nullptr);\n            sw.OffContent(nullptr);\n            sw.MinWidth(0);\n        }\n");
                src.add("        return;\n    }\n\n");
                src.add("    if (k == \"toggleLabel\") {\n");
                src.add("        auto sw = e.try_as<winrt_controls::ToggleSwitch>();\n");
                src.add("        if (sw == nullptr) return;\n");
                src.add("        auto row = g_toggleRows.find(h);\n");
                src.add("        if (row == g_toggleRows.end()) {\n");
                src.add("            winrt_controls::Grid made;\n");
                src.add("            winrt_controls::ColumnDefinition label;\n");
                src.add("            label.Width(winrt_xaml::GridLength{ 1.0, winrt_xaml::GridUnitType::Star });\n");
                src.add("            winrt_controls::ColumnDefinition control;\n");
                src.add("            control.Width(winrt_xaml::GridLength{ 0.0, winrt_xaml::GridUnitType::Auto });\n");
                src.add("            made.ColumnDefinitions().Append(label);\n");
                src.add("            made.ColumnDefinitions().Append(control);\n");
                src.add("            made.ColumnSpacing(12);\n");
                src.add("            winrt_controls::TextBlock block;\n");
                src.add("            block.TextWrapping(winrt_xaml::TextWrapping::Wrap);\n");
                src.add("            block.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);\n");
                src.add("            made.Children().Append(block);\n");
                src.add("            sw.Header(nullptr);\n");
                src.add("            sw.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);\n");
                src.add("            winrt_controls::Grid::SetColumn(sw, 1);\n");
                src.add("            made.Children().Append(sw);\n");
                src.add("            row = g_toggleRows.emplace(h, made).first;\n        }\n");
                src.add("        row->second.Children().GetAt(0).as<winrt_controls::TextBlock>().Text(text);\n");
                src.add("        winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetName(e, text);\n");
                src.add("        return;\n    }\n\n");
                src.add("    if (k == \"formLabel\") {\n");
                src.add("        g_formLabels[h] = std::wstring(text.c_str());\n");
                src.add("        winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetName(e, text);\n");
                src.add("        auto row = g_formRows.find(h);\n");
                src.add("        if (row != g_formRows.end()) {\n");
                src.add("            row->second.Children().GetAt(0).as<winrt_controls::TextBlock>().Text(text);\n");
                src.add("            formAlign(row->second);\n        }\n");
                src.add("        return;\n    }\n\n");
            }
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
        src.add("            });\n        }\n");
        // A Toggle drawn as a button: Click is the person's alone, so what it
        // reports is never a value the runtime set.
        src.add("        if (auto c = e.try_as<winrt_controls::Primitives::ToggleButton>()) {\n");
        src.add("            if (g_valueTokens[h].value != 0) { c.Click(g_valueTokens[h]); }\n");
        src.add("            g_valueTokens[h] = c.Click([callbackId](auto const& sender, auto const&) {\n");
        src.add("                if (auto s = sender.template try_as<winrt_controls::Primitives::ToggleButton>()) {\n");
        src.add("                    auto checked = s.IsChecked();\n");
        src.add("                    wui_bridge_invoke_node_bool(callbackId, checked && checked.Value());\n                }\n");
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
        src.add("            });\n        }\n");
        // A whole number: a typed 2.6 is 3, shown and reported as such. A
        // box emptied is not a value -- the last one comes back.
        src.add("        if (auto c = e.try_as<winrt_controls::NumberBox>()) {\n");
        src.add("            if (g_valueTokens[h].value != 0) { c.ValueChanged(g_valueTokens[h]); }\n");
        src.add("            g_valueTokens[h] = c.ValueChanged([callbackId, h](auto const& sender, winrt_controls::NumberBoxValueChangedEventArgs const& args) {\n");
        src.add("                auto s = sender.template try_as<winrt_controls::NumberBox>();\n");
        src.add("                if (s == nullptr || g_valueQuiet[h]) return;\n");
        src.add("                double v = args.NewValue();\n");
        src.add("                if (std::isnan(v)) {\n");
        src.add("                    g_valueQuiet[h] = true; s.Value(args.OldValue()); g_valueQuiet[h] = false;\n");
        src.add("                    return;\n                }\n");
        src.add("                int whole = (int)std::lround(v);\n");
        src.add("                if ((double)whole != v) { g_valueQuiet[h] = true; s.Value(whole); g_valueQuiet[h] = false; }\n");
        src.add("                wui_bridge_invoke_node_int(callbackId, whole);\n");
        src.add("            });\n        }\n");
        src.add("        if (auto c = e.try_as<winrt_controls::CalendarDatePicker>()) {\n");
        src.add("            if (g_valueTokens[h].value != 0) { c.DateChanged(g_valueTokens[h]); }\n");
        src.add("            g_valueTokens[h] = c.DateChanged([callbackId, h](auto const&, winrt_controls::CalendarDatePickerDateChangedEventArgs const& args) {\n");
        src.add("                if (g_valueQuiet[h]) return;\n");
        src.add("                auto day = args.NewDate();\n");
        src.add("                std::string text = day ? dayText(day.Value()) : std::string();\n");
        src.add("                wui_bridge_invoke_node_string(callbackId, text.c_str());\n");
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

        // A notice reports its closing, whoever closed it but the application.
        src.add("    if (k == \"onPresented\") {\n");
        src.add("        if (e.try_as<winrt_controls::ContentDialog>()) g_dialogs[h].presentedId = callbackId;\n");
        src.add("        if (auto bar = e.try_as<winrt_controls::InfoBar>()) {\n");
        src.add("            auto& n = g_notices[h];\n");
        src.add("            n.presentedId = callbackId;\n");
        src.add("            if (g_valueTokens[h].value == 0) {\n");
        src.add("                g_valueTokens[h] = bar.Closed([h](auto const&, auto const&) {\n");
        src.add("                    auto it = g_notices.find(h);\n");
        src.add("                    if (it == g_notices.end()) return;\n");
        src.add("                    if (it->second.timer != nullptr) it->second.timer.Stop();\n");
        src.add("                    if (it->second.quiet || it->second.presentedId < 0) return;\n");
        src.add("                    wui_bridge_invoke_node_bool(it->second.presentedId, false);\n                });\n            }\n        }\n");
        src.add("        return;\n    }\n\n");
        src.add("    if (k == \"onConfirm\") {\n");
        src.add("        if (e.try_as<winrt_controls::ContentDialog>()) g_dialogs[h].confirmId = callbackId;\n");
        src.add("        return;\n    }\n\n");
        src.add("    if (k == \"onMove\") {\n");
        src.add("        if (auto list = e.try_as<winrt_controls::ListView>()) {\n");
        src.add("            g_reorders[h].moveId = callbackId;\n");
        src.add("            reorderWire(list, h);\n        }\n");
        src.add("        return;\n    }\n\n");
        src.add("    if (k == \"onAction\") {\n");
        src.add("        if (e.try_as<winrt_controls::InfoBar>()) g_notices[h].actionId = callbackId;\n");
        src.add("        return;\n    }\n\n");
        src.add("    OutputDebugStringA(\"[wui] callback ignored: no event on this control reports it\\n\");\n}\n\n");

        src.add("extern \"C\" void wui_node_modifier(int h, const char* type, const char* modType, double f0, double f1, double f2, double f3, int nf, const char* s0) {\n");
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
        // Sizes, padding, opacity and a whole border, which markup writes as
        // modifiers and which were all ignored here: an avatar asked for 22 by
        // 22 came out the size of its initials. Each goes to what is placed
        // in the parent -- a framed text's frame -- see `placed`.
        src.add("    if (kind == \"width\" || kind == \"height\") {\n");
        src.add("        if (auto fe = at(h).try_as<winrt_xaml::FrameworkElement>()) sizeTo(fe, h, kind == \"width\", f0);\n");
        src.add("        return;\n    }\n");
        src.add("    if (kind == \"padding\") {\n");
        src.add("        if (auto e = placed(h)) padTo(e, winrt_xaml::Thickness{ f3, f0, f1, f2 });\n");
        src.add("        return;\n    }\n");
        src.add("    if (kind == \"opacity\") {\n");
        src.add("        if (auto e = placed(h)) e.Opacity(f0);\n");
        src.add("        return;\n    }\n");
        src.add("    if (kind == \"border\" && nf > 0) {\n");
        src.add("        auto e = placed(h);\n");
        src.add("        if (e) { borderTo(e, wui::runtime::brushFromName(s0), f0); if (nf > 1) roundCorners(e, f1); }\n");
        src.add("        return;\n    }\n");
        src.add("    if (kind == \"backgroundColor\") {\n");
        src.add("        auto e = at(h);\n");
        src.add("        if (auto text = e ? e.try_as<winrt_controls::TextBlock>() : nullptr) {\n");
        src.add("            auto frame = frameFor(h, text);\n");
        src.add("            frame.Background(wui::runtime::brushFromName(s0));\n");
        src.add("            roundCorners(frame, f0);\n");
        src.add("            return;\n        }\n");
        src.add("        wui_node_prop_string(h, type, \"background\", s0);\n");
        src.add("        if (e) roundCorners(e, f0);\n");
        src.add("        return;\n    }\n");
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
        src.add("    auto p = at(parent);\n    auto c = placed(child);\n");
        src.add("    if (p == nullptr || c == nullptr) return;\n\n");
        src.add("    // A notice is not drawn where it stands: see noticeMount.\n");
        src.add("    if (c.try_as<winrt_controls::InfoBar>()) { noticeMount(parent, child, index); return; }\n");
        src.add("    // Nor is a dialog: see dialogMount.\n");
        src.add("    if (c.try_as<winrt_controls::ContentDialog>()) { dialogMount(parent, child, index); return; }\n");
        src.add("    // A sheet's children go into its content.\n");
        src.add("    if (auto dialog = p.try_as<winrt_controls::ContentDialog>()) {\n");
        src.add("        if (auto content = sheetContent(dialog)) {\n");
        src.add("            uint32_t n = content.Children().Size();\n");
        src.add("            uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("            if (i > n) i = n;\n");
        src.add("            content.Children().InsertAt(i, c);\n        }\n");
        src.add("        return;\n    }\n\n");
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
        src.add("            rowColumns(grid);\n");
        // A row centres its children across, as the canon's HStack does on
        // every other backend; a Grid stretches them, which put a name above
        // the middle of the avatar beside it. Only where nothing said otherwise.
        src.add("            if (fe != nullptr && fe.ReadLocalValue(winrt_xaml::FrameworkElement::VerticalAlignmentProperty()) == winrt_xaml::DependencyProperty::UnsetValue())\n");
        src.add("                fe.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);\n");
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
        // So does a shell that is the whole screen: tabs, a sidebar, or a
        // Grid holding one. Sized to its content, a sidebar stopped where
        // its page did, the window bare below. See fillsHeight.
        src.add("            bool share = fillsHeight(c);\n");
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

        // A field's controls go into its own Grid, side by side, each labelled
        // by the field's label for UI Automation.
        src.add("    if (tagText(p) == L\"field\") {\n");
        src.add("        auto field = p.as<winrt_controls::Grid>();\n");
        src.add("        auto controls = fieldControls(field);\n");
        src.add("        uint32_t n = controls.Children().Size();\n");
        src.add("        uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("        if (i > n) i = n;\n");
        src.add("        winrt_xaml::UIElement item = c;\n");
        src.add("        auto inline_ = g_inlineRows.find(child);\n");
        src.add("        if (inline_ != g_inlineRows.end()) {\n");
        src.add("            auto row = inline_->second;\n");
        src.add("            if (row.Children().Size() < 2) {\n");
        src.add("                if (auto fe = c.try_as<winrt_xaml::FrameworkElement>()) fe.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);\n");
        src.add("                row.Children().Append(c);\n            }\n");
        src.add("            uint32_t was = 0;\n");
        src.add("            if (controls.Children().IndexOf(row, was)) { controls.Children().RemoveAt(was); if (was < i) --i; n = controls.Children().Size(); if (i > n) i = n; }\n");
        src.add("            item = row;\n        }\n");
        src.add("        controls.Children().InsertAt(i, item);\n");
        src.add("        fieldColumns(field);\n");
        src.add("        formAlign(p);\n        return;\n    }\n\n");
        // A form's children, and a form section's, are rows: one that is not
        // a row already is put in one. A section's first child is its heading.
        src.add("    {\n        auto tag = tagText(p);\n");
        src.add("        if (tag == L\"form\" || tag == L\"formsection\" || tag == L\"section\") {\n");
        src.add("            auto panel = p.as<winrt_controls::Panel>();\n");
        src.add("            winrt_xaml::UIElement row = c;\n");
        src.add("            auto kind = tagText(c);\n");
        src.add("            if (tag != L\"section\" && kind != L\"field\" && kind != L\"formsection\") {\n");
        src.add("                auto found = g_formRows.find(child);\n");
        src.add("                if (found != g_formRows.end()) {\n");
        src.add("                    uint32_t was = 0;\n");
        src.add("                    if (panel.Children().IndexOf(found->second, was)) panel.Children().RemoveAt(was);\n");
        src.add("                    row = found->second;\n");
        src.add("                } else {\n");
        src.add("                    auto made = formRowFor(child, c);\n");
        src.add("                    g_formRows[child] = made;\n");
        src.add("                    row = made;\n                }\n            }\n");
        src.add("            uint32_t skip = tag == L\"form\" ? 0 : 1;\n");
        src.add("            uint32_t n = panel.Children().Size();\n");
        src.add("            uint32_t i = index < 0 ? n : (uint32_t)index + skip;\n");
        src.add("            if (i > n) i = n;\n");
        src.add("            panel.Children().InsertAt(i, row);\n");
        src.add("            if (tag != L\"section\") formAlign(p);\n");
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
        // A Menu holds its items in its flyout, a nested one in its own list.
        // Before the ContentControl fallback, which a DropDownButton also is.
        src.add("    if (auto drop = p.try_as<winrt_controls::DropDownButton>()) {\n");
        src.add("        auto flyout = drop.Flyout().try_as<winrt_controls::MenuFlyout>();\n");
        src.add("        auto item = c.try_as<winrt_controls::MenuFlyoutItemBase>();\n");
        src.add("        if (flyout != nullptr && item != nullptr) {\n");
        src.add("            uint32_t n = flyout.Items().Size();\n");
        src.add("            uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("            if (i > n) i = n;\n");
        src.add("            flyout.Items().InsertAt(i, item);\n        }\n        return;\n    }\n\n");
        src.add("    if (auto list = p.try_as<winrt_controls::ListView>()) {\n");
        src.add("        uint32_t n = list.Items().Size();\n");
        src.add("        uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("        if (i > n) i = n;\n");
        src.add("        list.Items().InsertAt(i, c);\n");
        src.add("        return;\n    }\n\n");
        src.add("    if (auto sub = p.try_as<winrt_controls::MenuFlyoutSubItem>()) {\n");
        src.add("        if (auto item = c.try_as<winrt_controls::MenuFlyoutItemBase>()) {\n");
        src.add("            uint32_t n = sub.Items().Size();\n");
        src.add("            uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("            if (i > n) i = n;\n");
        src.add("            sub.Items().InsertAt(i, item);\n        }\n        return;\n    }\n\n");

        // A CommandBar holds commands, not elements: a child that is not one
        // goes in a wrapper, the one it had if it had one. Before the
        // ContentControl fallback, which a CommandBar also is -- there, every
        // command replaced the title.
        src.add("    if (auto bar = p.try_as<winrt_controls::CommandBar>()) {\n");
        src.add("        auto commands = bar.PrimaryCommands();\n");
        src.add("        auto command = c.try_as<winrt_controls::ICommandBarElement>();\n");
        src.add("        if (command == nullptr) {\n");
        src.add("            auto found = g_barBoxes.find(child);\n");
        src.add("            winrt_controls::AppBarElementContainer box{ nullptr };\n");
        src.add("            if (found != g_barBoxes.end()) {\n");
        src.add("                box = found->second;\n");
        src.add("                uint32_t was = 0;\n");
        src.add("                if (commands.IndexOf(box, was)) commands.RemoveAt(was);\n");
        src.add("            } else {\n");
        src.add("                box = winrt_controls::AppBarElementContainer();\n");
        src.add("                box.VerticalContentAlignment(winrt_xaml::VerticalAlignment::Center);\n");
        src.add("                box.Content(c);\n");
        src.add("                g_barBoxes[child] = box;\n            }\n");
        src.add("            command = box;\n        }\n");
        src.add("        uint32_t n = commands.Size();\n");
        src.add("        uint32_t i = index < 0 ? n : (uint32_t)index;\n");
        src.add("        if (i > n) i = n;\n");
        src.add("        commands.InsertAt(i, command);\n        return;\n    }\n\n");

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
        src.add("    auto p = at(parent);\n    auto c = placed(child);\n");
        src.add("    if (p == nullptr || c == nullptr) return;\n\n");
        src.add("    {\n        auto dialog = g_dialogs.find(child);\n");
        src.add("        if (dialog != g_dialogs.end() && dialog->second.spot >= 0) {\n");
        src.add("            wui_node_remove(parent, dialog->second.spot);\n");
        src.add("            return;\n        }\n    }\n");
        src.add("    if (auto dialog = p.try_as<winrt_controls::ContentDialog>()) {\n");
        src.add("        if (auto content = sheetContent(dialog)) {\n");
        src.add("            uint32_t index = 0;\n");
        src.add("            if (content.Children().IndexOf(c, index)) content.Children().RemoveAt(index);\n        }\n");
        src.add("        return;\n    }\n\n");
        src.add("    {\n        auto notice = g_notices.find(child);\n");
        src.add("        if (notice != g_notices.end() && notice->second.spot >= 0) {\n");
        src.add("            noticeHide(child);\n");
        src.add("            wui_node_remove(parent, notice->second.spot);\n");
        src.add("            return;\n        }\n    }\n\n");
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
        src.add("                        winrt_controls::Grid::SetColumn(moved, (int)i);\n                }\n");
        src.add("                rowColumns(grid);\n            }\n");
        src.add("            return;\n        }\n    }\n\n");

        src.add("    if (auto grid = p.try_as<winrt_controls::Grid>()) {\n");
        src.add("        if (tagText(p) == L\"column\") {\n");
        src.add("            uint32_t index = 0;\n");
        src.add("            if (grid.Children().IndexOf(c, index)) {\n");
        src.add("                grid.Children().RemoveAt(index);\n");
        src.add("                if (index < grid.RowDefinitions().Size()) grid.RowDefinitions().RemoveAt(index);\n");
        src.add("                columnRenumber(grid, index);\n            }\n");
        src.add("            return;\n        }\n    }\n\n");
        src.add("    if (auto bar = p.try_as<winrt_controls::CommandBar>()) {\n");
        src.add("        auto commands = bar.PrimaryCommands();\n");
        src.add("        auto command = c.try_as<winrt_controls::ICommandBarElement>();\n");
        src.add("        auto found = g_barBoxes.find(child);\n");
        src.add("        if (command == nullptr && found != g_barBoxes.end()) command = found->second;\n");
        src.add("        uint32_t index = 0;\n");
        src.add("        if (command != nullptr && commands.IndexOf(command, index)) commands.RemoveAt(index);\n");
        src.add("        return;\n    }\n\n");
        src.add("    if (auto scroll = p.try_as<winrt_controls::ScrollViewer>()) {\n");
        src.add("        if (auto column = scrollColumn(scroll, false)) {\n");
        src.add("            uint32_t index = 0;\n");
        src.add("            if (column.Children().IndexOf(c, index)) column.Children().RemoveAt(index);\n        }\n");
        src.add("        return;\n    }\n\n");

        src.add("    if (tagText(p) == L\"field\") {\n");
        src.add("        auto field = p.as<winrt_controls::Grid>();\n");
        src.add("        auto controls = fieldControls(field);\n");
        src.add("        uint32_t index = 0;\n");
        src.add("        winrt_xaml::UIElement item = c;\n");
        src.add("        auto inline_ = g_inlineRows.find(child);\n");
        src.add("        if (inline_ != g_inlineRows.end()) item = inline_->second;\n");
        src.add("        if (controls.Children().IndexOf(item, index)) {\n");
        src.add("            controls.Children().RemoveAt(index);\n");
        src.add("            winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetLabeledBy(c, nullptr);\n        }\n");
        src.add("        fieldColumns(field);\n");
        src.add("        return;\n    }\n\n");
        // A row the form made goes with its child; the child stays in it, so
        // putting the child back puts the same row back.
        src.add("    {\n        auto tag = tagText(p);\n");
        src.add("        if (tag == L\"form\" || tag == L\"formsection\") {\n");
        src.add("            auto panel = p.as<winrt_controls::Panel>();\n");
        src.add("            winrt_xaml::UIElement row = c;\n");
        src.add("            auto found = g_formRows.find(child);\n");
        src.add("            if (found != g_formRows.end()) row = found->second;\n");
        src.add("            uint32_t index = 0;\n");
        src.add("            if (panel.Children().IndexOf(row, index)) panel.Children().RemoveAt(index);\n");
        src.add("            formAlign(p);\n");
        src.add("            return;\n        }\n    }\n\n");
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
        src.add("    if (auto drop = p.try_as<winrt_controls::DropDownButton>()) {\n");
        src.add("        auto flyout = drop.Flyout().try_as<winrt_controls::MenuFlyout>();\n");
        src.add("        auto item = c.try_as<winrt_controls::MenuFlyoutItemBase>();\n");
        src.add("        uint32_t index = 0;\n");
        src.add("        if (flyout != nullptr && item != nullptr && flyout.Items().IndexOf(item, index)) flyout.Items().RemoveAt(index);\n");
        src.add("        return;\n    }\n\n");
        src.add("    if (auto list = p.try_as<winrt_controls::ListView>()) {\n");
        src.add("        uint32_t index = 0;\n");
        src.add("        if (list.Items().IndexOf(c, index)) list.Items().RemoveAt(index);\n");
        src.add("        return;\n    }\n\n");
        src.add("    if (auto sub = p.try_as<winrt_controls::MenuFlyoutSubItem>()) {\n");
        src.add("        auto item = c.try_as<winrt_controls::MenuFlyoutItemBase>();\n");
        src.add("        uint32_t index = 0;\n");
        src.add("        if (item != nullptr && sub.Items().IndexOf(item, index)) sub.Items().RemoveAt(index);\n");
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
        src.add("    g_barBoxes.erase(h);\n");
        src.add("    g_formRows.erase(h);\n");
        src.add("    g_formLabels.erase(h);\n");
        src.add("    g_inlineRows.erase(h);\n");
        src.add("    g_reorders.erase(h);\n");
        src.add("    g_frames.erase(h);\n");
        src.add("    g_toggleRows.erase(h);\n");
        src.add("    {\n        auto dialog = g_dialogs.find(h);\n");
        src.add("        if (dialog != g_dialogs.end()) {\n");
        src.add("            int spot = dialog->second.spot;\n");
        src.add("            if (dialog->second.showing) {\n");
        src.add("                dialog->second.quiet = true;\n");
        src.add("                if (auto e = at(h)) { if (auto d = e.try_as<winrt_controls::ContentDialog>()) d.Hide(); }\n            }\n");
        src.add("            if (g_dialogShowing == h) g_dialogShowing = -1;\n");
        src.add("            g_dialogs.erase(dialog);\n");
        src.add("            if (spot >= 0) wui_node_destroy(spot);\n        }\n    }\n");
        src.add("    {\n        auto notice = g_notices.find(h);\n");
        src.add("        if (notice != g_notices.end()) {\n");
        src.add("            int spot = notice->second.spot;\n");
        src.add("            noticeHide(h);\n");
        src.add("            if (notice->second.timer != nullptr) notice->second.timer.Stop();\n");
        src.add("            if (notice->second.inTree) { if (auto backing = at(spot).try_as<winrt_controls::Border>()) backing.Child(nullptr); }\n");
        src.add("            if (notice->second.popup != nullptr) {\n");
        src.add("                if (auto backing = notice->second.popup.Child().try_as<winrt_controls::Border>()) backing.Child(nullptr);\n");
        src.add("                notice->second.popup.Child(nullptr);\n            }\n");
        src.add("            g_notices.erase(notice);\n");
        src.add("            if (spot >= 0) wui_node_destroy(spot);\n        }\n    }\n");
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
			case "ImageSource" | "ImageAlt" | "ImageFit" | "ButtonIcon" | "ButtonIconName" | "ButtonStyle" | "ButtonChecked" | "ToggleStyle"
				| "CommandBarTitle" | "AppBarIcon" | "SectionTitle" | "FieldLabel"
				| "NoticePresented" | "NoticeKind" | "NoticeAction" | "NoticeDismiss"
				| "DialogPresented" | "DialogTitle" | "DialogMessage" | "DialogDestructive"
				| "StepperValue" | "StepperMin" | "StepperMax" | "DateValue" | "DateMin" | "DateMax"
				| "ReorderUpLabel" | "ReorderDownLabel"
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
            case "ButtonStyle":
                "buttonStyle(c, h, " + valueExpr + ");";
            // A ToggleButton's IsChecked is an IReference<bool>; compared
            // before it is set, like every value a person edits.
            case "Width" | "Height":
                "sizeTo(c, h, " + (member == "Width" ? "true" : "false") + ", " + valueExpr + ");";
            case "IsChecked":
                "{ auto now = c.IsChecked(); if (!now || now.Value() != " + valueExpr + ") { c.IsChecked(" + valueExpr + "); } }";
            case "ToggleStyle":
                ";";
            case "CommandBarTitle":
                "commandBarTitle(c, " + valueExpr + ");";
            case "AppBarIcon":
                "appBarIcon(c, " + valueExpr + ");";
            case "SectionTitle":
                "sectionTitle(c, " + valueExpr + ");";
            case "FieldLabel":
                "fieldLabel(c, " + valueExpr + ");";
            case "NoticePresented":
                "noticePresented(c, h, " + valueExpr + ");";
            case "NoticeKind":
                "noticeKind(c, h, " + valueExpr + ");";
            case "NoticeAction":
                "noticeAction(c, h, " + valueExpr + ");";
            case "NoticeDismiss":
                "noticeDismiss(c, h, " + valueExpr + ");";
            case "DialogPresented":
                "dialogPresented(c, h, " + valueExpr + ");";
            case "DialogTitle":
                "dialogTitle(c, " + valueExpr + ");";
            case "DialogMessage":
                "dialogMessage(c, " + valueExpr + ");";
            case "DialogDestructive":
                "dialogDestructive(c, " + valueExpr + ");";
            case "StepperValue":
                "stepperValue(c, h, " + valueExpr + ");";
            case "StepperMin":
                "stepperBound(c, h, false, " + valueExpr + ");";
            case "StepperMax":
                "stepperBound(c, h, true, " + valueExpr + ");";
            case "DateValue":
                "dateValue(c, h, " + valueExpr + ");";
            case "DateMin":
                "dateBound(c, false, " + valueExpr + ");";
            case "DateMax":
                "dateBound(c, true, " + valueExpr + ");";
            case "ReorderUpLabel":
                "reorderLabel(h, true, " + valueExpr + ");";
            case "ReorderDownLabel":
                "reorderLabel(h, false, " + valueExpr + ");";
            case "ButtonChecked":
                "buttonChecked(c, h, " + valueExpr + ");";
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
            case "NavIconGlyph":
                "navIcon(c, " + valueExpr + ");";

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
                    + " : winrt_controls::NavigationViewPaneDisplayMode::Auto)"
                    // Auto narrows the pane to its icons, and below 641 hides
                    // it behind a button that floats over the content's top
                    // corner -- over a toolbar's title. The icons stay instead.
                    + ", c.CompactModeThresholdWidth(std::string(" + valueExpr + ") == \"Auto\" ? 0.0 : 641.0)";
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
#include <winrt/Windows.System.UserProfile.h>
#include <microsoft.ui.xaml.window.h>
#include <string>

namespace winrt_xaml = winrt::Microsoft::UI::Xaml;

// The languages of the person, in their order, for every string WinUI loads
// itself. Its control library reads them already, through MRT; its core
// (the On/Off of a switch, the spoken type of a control) loads from .mui files,
// which follow the Windows display language instead -- English on a
// machine whose display pack is English and whose first language is
// French. A packaged app would get this list; an unpackaged one is given it.
static void preferUserLanguages() {
    try {
        std::wstring list;
        for (auto const& tag : winrt::Windows::System::UserProfile::GlobalizationPreferences::Languages()) {
            list.append(tag.c_str());
            list.push_back(0);
        }
        if (list.empty()) return;
        list.push_back(0);
        ULONG count = 0;
        SetProcessPreferredUILanguages(MUI_LANGUAGE_NAME, list.c_str(), &count);
    } catch (...) {
    }
}

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

    // The size Windows gives a new window, unless the application asked for
    // one: then its client area, in effective pixels at the window\'s scale.
    // 800 by 600 device pixels was a small window at 100% and a smaller one
    // at every scale above.
    // Windows\' own size is three quarters of the screen each way, which on a
    // wide screen is a band: no wider than 1200 then, the height kept.
    if (auto appWindow = m_window.AppWindow()) {
        HWND hwnd = nullptr;
        if (auto native = m_window.try_as<::IWindowNative>()) native->get_WindowHandle(&hwnd);
        double scale = (hwnd ? GetDpiForWindow(hwnd) : 96) / 96.0;
        if ($windowWidth > 0 && $windowHeight > 0) {
            appWindow.ResizeClient(winrt::Windows::Graphics::SizeInt32{ (int)($windowWidth * scale), (int)($windowHeight * scale) });
        } else if (appWindow.Size().Width > (int)(1200 * scale)) {
            appWindow.Resize(winrt::Windows::Graphics::SizeInt32{ (int)(1200 * scale), appWindow.Size().Height });
        }
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
    preferUserLanguages();

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

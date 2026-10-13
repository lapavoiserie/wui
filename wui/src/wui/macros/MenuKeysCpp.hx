package wui.macros;

/**
	A menu bar from the keyboard, as a Windows menu bar is reached.

	- **Alt** shows each menu's key and **Alt+letter** opens it: XAML's
	  access keys. A command set's title carries no mnemonic, so each menu
	  takes the first letter of its title no menu before it has taken, and
	  each item in a menu the first its siblings have not -- the same
	  titles in the same order give the same keys. Letters A to Z and
	  digits only: a key the keyboard cannot type alone is no key.
	- **F10** moves the focus to the first menu, as it does in every
	  Windows application with a menu bar. Not Shift+F10, which is the
	  context menu.
	- **Esc** on a menu, once its list is closed, gives the focus back to
	  where it was before the menu bar took it.
	- The arrows move between menus and the menus are announced by
	  WinUI's own MenuBar; nothing here.

	Keys are worked out when they can be needed -- Alt or F10 pressed --
	rather than at every title change: a language change renames every
	menu at once, and the keys follow on the next press.

	Emitted into `WuiNodes.cpp`, inside `wui::nodes`.
**/
class MenuKeysCpp {
	public static function source():String {
		return '    // ---- a menu bar from the keyboard: see wui.macros.MenuKeysCpp ----
    winrt::hstring menuKeyPick(winrt::hstring const& label, std::wstring& used) {
        for (wchar_t ch : std::wstring_view(label)) {
            wchar_t up = (wchar_t)towupper(ch);
            bool usable = (up >= L\'A\' && up <= L\'Z\') || (up >= L\'0\' && up <= L\'9\');
            if (!usable || used.find(up) != std::wstring::npos) continue;
            used.push_back(up);
            return winrt::hstring(std::wstring(1, up));
        }
        return winrt::hstring();
    }

    void menuKeys(winrt_controls::MenuBar const& bar) {
        std::wstring menus;
        for (auto const& menu : bar.Items()) {
            menu.AccessKey(menuKeyPick(menu.Title(), menus));
            std::wstring items;
            for (auto const& entry : menu.Items()) {
                if (auto item = entry.try_as<winrt_controls::MenuFlyoutItem>()) item.AccessKey(menuKeyPick(item.Text(), items));
                else if (auto sub = entry.try_as<winrt_controls::MenuFlyoutSubItem>()) sub.AccessKey(menuKeyPick(sub.Text(), items));
            }
        }
    }

    struct MenuKeyboard {
        winrt::weak_ref<winrt_controls::MenuBar> bar;
        winrt::weak_ref<winrt_xaml::UIElement> before;
        bool hooked = false;
    };
    static std::vector<std::shared_ptr<MenuKeyboard>> g_menuKeyboards;

    // Once per menu bar, when it is first loaded: then it has a window to
    // listen in. Loaded again after a move (to a title bar row) changes
    // nothing.
    void menuKeyboard(winrt_controls::MenuBar const& bar) {
        for (auto const& k : g_menuKeyboards) if (auto held = k->bar.get(); held != nullptr && held == bar) return;
        auto k = std::make_shared<MenuKeyboard>();
        k->bar = winrt::make_weak(bar);
        g_menuKeyboards.push_back(k);
        std::weak_ptr<MenuKeyboard> weak = k;

        // Where the focus came from, unless from the menus themselves or
        // their lists.
        bar.GettingFocus([weak](auto const&, winrt_xaml::Input::GettingFocusEventArgs const& args) {
            auto k = weak.lock();
            auto bar = k ? k->bar.get() : nullptr;
            if (bar == nullptr) return;
            auto old = args.OldFocusedElement().try_as<winrt_xaml::UIElement>();
            if (old == nullptr || bar.XamlRoot() == nullptr) return;
            // Only what lives in the window\'s own tree: a menu\'s list is a
            // popup, and the focus leaves it on its way back to the menu.
            auto content = bar.XamlRoot().Content();
            bool inWindow = false;
            for (winrt_xaml::DependencyObject up = old; up != nullptr; up = winrt::Microsoft::UI::Xaml::Media::VisualTreeHelper::GetParent(up)) {
                if (up == bar) return;
                if (up == content) { inWindow = true; break; }
            }
            if (inWindow) k->before = winrt::make_weak(old);
        });
        bar.KeyDown([weak](auto const&, winrt_xaml::Input::KeyRoutedEventArgs const& args) {
            if (args.Key() != winrt::Windows::System::VirtualKey::Escape) return;
            auto k = weak.lock();
            if (k == nullptr) return;
            if (auto before = k->before.get()) {
                before.Focus(winrt_xaml::FocusState::Keyboard);
                args.Handled(true);
            }
        });
        bar.Loaded([weak](auto const& sender, auto const&) {
            auto k = weak.lock();
            auto bar = sender.template as<winrt_controls::MenuBar>();
            if (k == nullptr || k->hooked || bar.XamlRoot() == nullptr) return;
            auto root = bar.XamlRoot().Content();
            if (root == nullptr) return;
            k->hooked = true;
            root.PreviewKeyDown([weak](auto const&, winrt_xaml::Input::KeyRoutedEventArgs const& args) {
                using winrt::Windows::System::VirtualKey;
                auto k = weak.lock();
                auto bar = k ? k->bar.get() : nullptr;
                if (bar == nullptr || bar.XamlRoot() == nullptr) return;
                auto key = args.Key();
                if (key == VirtualKey::Menu || key == VirtualKey::LeftMenu || key == VirtualKey::RightMenu) {
                    menuKeys(bar);
                    return;
                }
                if (key != VirtualKey::F10 || (GetKeyState(VK_SHIFT) & 0x8000) || (GetKeyState(VK_CONTROL) & 0x8000)) return;
                if (bar.Items().Size() == 0) return;
                menuKeys(bar);
                auto focused = winrt::Microsoft::UI::Xaml::Input::FocusManager::GetFocusedElement(bar.XamlRoot()).try_as<winrt_xaml::UIElement>();
                if (focused != nullptr) k->before = winrt::make_weak(focused);
                bar.Items().GetAt(0).Focus(winrt_xaml::FocusState::Keyboard);
                args.Handled(true);
            });
        });
    }

';
	}
}

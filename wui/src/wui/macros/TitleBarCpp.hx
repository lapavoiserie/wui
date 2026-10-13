package wui.macros;

/**
	A window's title bar, drawn by wui rather than by the system: the
	content runs up under the caption buttons, on Mica, with the title --
	and the menu bar, when there is one -- in a row of its own, as the
	Windows 11 applications have it (Settings, Notepad).

	`wui.platform.Windows.extendIntoTitleBar` turns it off, giving the
	system caption back; so does a system where the title bar cannot be
	customised. Emitted into `WuiNodes.cpp`, inside `wui::nodes`, before
	the windows that use it.

	What the row has to keep doing that the system caption did:

	- **Name the window.** `Window.Title` stays set -- the taskbar,
	  Alt+Tab and UI Automation read it -- and the drawn title follows it
	  (`chromeTitle`, called wherever a title is set).
	- **Say whether the window is active**: the title dims with it.
	- **Follow the theme**: the caption buttons' colours are set for the
	  backdrop, again at every theme change; in high contrast they are left
	  to the system, and so is the backdrop.
	- **Leave the menus clickable.** The row is the drag region; the menu
	  bar's rectangle is cut out of it as pass-through, in device pixels,
	  again whenever the row, the title or the menu bar change size, and
	  whenever the scale does.
	- **Make room for the caption buttons** on whichever side they are,
	  from the title bar's own insets: they change sides right to left.
**/
class TitleBarCpp {
	public static function source():String {
		return '    // ---- a window\'s title bar: see wui.macros.TitleBarCpp ----
    struct Chrome {
        winrt::weak_ref<winrt_xaml::Window> window;
        winrt_controls::Grid outer{ nullptr };
        winrt_controls::Grid row{ nullptr };
        winrt_controls::ColumnDefinition start{ nullptr };
        winrt_controls::ColumnDefinition end{ nullptr };
        winrt_controls::TextBlock title{ nullptr };
        winrt_controls::Grid menus{ nullptr };
        winrt::Microsoft::UI::WindowId id{};
    };
    static std::vector<std::shared_ptr<Chrome>> g_chromes;

    std::shared_ptr<Chrome> chromeOf(winrt_xaml::Window const& w) {
        for (auto const& c : g_chromes) if (auto held = c->window.get(); held != nullptr && held == w) return c;
        return nullptr;
    }

    bool chromeHighContrast() {
        try { return winrt::Windows::UI::ViewManagement::AccessibilitySettings().HighContrast(); } catch (...) { return false; }
    }

    // The caption buttons, drawn over the backdrop: transparent, in the
    // theme\'s ink. In high contrast, the system\'s own colours.
    void chromeButtons(Chrome& c) {
        auto w = c.window.get();
        if (w == nullptr) return;
        auto bar = w.AppWindow().TitleBar();
        if (chromeHighContrast()) {
            bar.ButtonBackgroundColor(nullptr);
            bar.ButtonInactiveBackgroundColor(nullptr);
            bar.ButtonForegroundColor(nullptr);
            bar.ButtonInactiveForegroundColor(nullptr);
            bar.ButtonHoverBackgroundColor(nullptr);
            bar.ButtonHoverForegroundColor(nullptr);
            bar.ButtonPressedBackgroundColor(nullptr);
            bar.ButtonPressedForegroundColor(nullptr);
            return;
        }
        bool dark = c.outer.ActualTheme() == winrt_xaml::ElementTheme::Dark;
        uint8_t ink = dark ? 255 : 0;
        winrt::Windows::UI::Color clear{ 0, 0, 0, 0 };
        winrt::Windows::UI::Color fg{ 255, ink, ink, ink };
        winrt::Windows::UI::Color faint{ 0x5D, ink, ink, ink };
        winrt::Windows::UI::Color hover{ (uint8_t)(dark ? 0x15 : 0x09), ink, ink, ink };
        winrt::Windows::UI::Color pressed{ (uint8_t)(dark ? 0x0F : 0x06), ink, ink, ink };
        bar.ButtonBackgroundColor(clear);
        bar.ButtonInactiveBackgroundColor(clear);
        bar.ButtonForegroundColor(fg);
        bar.ButtonInactiveForegroundColor(faint);
        bar.ButtonHoverBackgroundColor(hover);
        bar.ButtonHoverForegroundColor(fg);
        bar.ButtonPressedBackgroundColor(pressed);
        bar.ButtonPressedForegroundColor(fg);
    }

    // Mica, or the theme\'s plain background where there is none: in high
    // contrast, and wherever the system has no Mica to give.
    void chromeBackdrop(Chrome& c) {
        auto w = c.window.get();
        if (w == nullptr) return;
        bool mica = !chromeHighContrast() && winrt::Microsoft::UI::Composition::SystemBackdrops::MicaController::IsSupported();
        if (mica) {
            if (w.SystemBackdrop() == nullptr) w.SystemBackdrop(winrt::Microsoft::UI::Xaml::Media::MicaBackdrop());
            c.outer.ClearValue(winrt_controls::Panel::BackgroundProperty());
        } else {
            w.SystemBackdrop(nullptr);
            try {
                c.outer.Background(winrt_xaml::Application::Current().Resources().Lookup(
                    winrt::box_value(L"SolidBackgroundFillColorBaseBrush")).as<winrt::Microsoft::UI::Xaml::Media::Brush>());
            } catch (...) {}
        }
    }

    // Room for the caption buttons, on their side; and the menu bar cut out
    // of the drag region. Device pixels both ways.
    void chromeRegions(Chrome& c) {
        auto w = c.window.get();
        if (w == nullptr || c.row.XamlRoot() == nullptr) return;
        double scale = c.row.XamlRoot().RasterizationScale();
        if (scale <= 0) scale = 1;
        auto bar = w.AppWindow().TitleBar();
        bool rtl = c.row.FlowDirection() == winrt_xaml::FlowDirection::RightToLeft;
        double left = bar.LeftInset() / scale, right = bar.RightInset() / scale;
        c.start.Width(winrt_xaml::GridLength{ rtl ? right : left, winrt_xaml::GridUnitType::Pixel });
        c.end.Width(winrt_xaml::GridLength{ rtl ? left : right, winrt_xaml::GridUnitType::Pixel });
        auto source = winrt::Microsoft::UI::Input::InputNonClientPointerSource::GetForWindowId(c.id);
        if (c.menus.Children().Size() == 0 || c.menus.ActualWidth() <= 0) {
            source.ClearRegionRects(winrt::Microsoft::UI::Input::NonClientRegionKind::Passthrough);
            return;
        }
        auto box = c.menus.TransformToVisual(nullptr).TransformBounds(
            winrt::Windows::Foundation::Rect{ 0, 0, (float)c.menus.ActualWidth(), (float)c.menus.ActualHeight() });
        winrt::Windows::Graphics::RectInt32 rect{ (int32_t)(box.X * scale), (int32_t)(box.Y * scale),
            (int32_t)(box.Width * scale), (int32_t)(box.Height * scale) };
        source.SetRegionRects(winrt::Microsoft::UI::Input::NonClientRegionKind::Passthrough, { rect });
    }

    void chromeTitle(winrt_xaml::Window const& w, winrt::hstring const& text) {
        w.Title(text);
        if (auto c = chromeOf(w)) c->title.Text(text);
    }

    // The window\'s content, in a column under the title bar row; or the
    // content itself, with the system\'s caption, where the row is not wanted.
    winrt_xaml::UIElement chromeWrap(winrt_xaml::Window const& w, winrt_xaml::UIElement const& content) {
        if (!wui_bridge_extends_title_bar()) return content;
        try {
            if (!winrt::Microsoft::UI::Windowing::AppWindowTitleBar::IsCustomizationSupported()) return content;
        } catch (...) { return content; }
        auto c = std::make_shared<Chrome>();
        c->window = winrt::make_weak(w);
        c->id = w.AppWindow().Id();

        c->outer = winrt_controls::Grid();
        c->outer.Tag(winrt::box_value(L"chrome"));
        winrt_controls::RowDefinition top;
        top.Height(winrt_xaml::GridLength{ 0.0, winrt_xaml::GridUnitType::Auto });
        winrt_controls::RowDefinition rest;
        rest.Height(winrt_xaml::GridLength{ 1.0, winrt_xaml::GridUnitType::Star });
        c->outer.RowDefinitions().Append(top);
        c->outer.RowDefinitions().Append(rest);

        c->row = winrt_controls::Grid();
        c->row.Height(48);
        c->start = winrt_controls::ColumnDefinition();
        c->end = winrt_controls::ColumnDefinition();
        winrt_controls::ColumnDefinition titleColumn;
        titleColumn.Width(winrt_xaml::GridLength{ 0.0, winrt_xaml::GridUnitType::Auto });
        winrt_controls::ColumnDefinition menuColumn;
        menuColumn.Width(winrt_xaml::GridLength{ 0.0, winrt_xaml::GridUnitType::Auto });
        winrt_controls::ColumnDefinition drag;
        drag.Width(winrt_xaml::GridLength{ 1.0, winrt_xaml::GridUnitType::Star });
        for (auto const& d : { c->start, titleColumn, menuColumn, drag, c->end }) c->row.ColumnDefinitions().Append(d);

        c->title = winrt_controls::TextBlock();
        try {
            c->title.Style(winrt_xaml::Application::Current().Resources().Lookup(
                winrt::box_value(L"CaptionTextBlockStyle")).as<winrt_xaml::Style>());
        } catch (...) {}
        c->title.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);
        c->title.TextTrimming(winrt_xaml::TextTrimming::CharacterEllipsis);
        c->title.TextWrapping(winrt_xaml::TextWrapping::NoWrap);
        c->title.Margin(winrt_xaml::Thickness{ 16, 0, 8, 0 });
        c->title.Text(w.Title());
        // Read as the window\'s name already; once is enough for a screen reader.
        winrt::Microsoft::UI::Xaml::Automation::AutomationProperties::SetAccessibilityView(
            c->title, winrt::Microsoft::UI::Xaml::Automation::Peers::AccessibilityView::Raw);
        winrt_controls::Grid::SetColumn(c->title, 1);
        c->menus = winrt_controls::Grid();
        c->menus.VerticalAlignment(winrt_xaml::VerticalAlignment::Center);
        winrt_controls::Grid::SetColumn(c->menus, 2);
        c->row.Children().Append(c->title);
        c->row.Children().Append(c->menus);

        winrt_controls::Grid::SetRow(c->row, 0);
        c->outer.Children().Append(c->row);
        if (auto fe = content.try_as<winrt_xaml::FrameworkElement>()) winrt_controls::Grid::SetRow(fe, 1);
        c->outer.Children().Append(content);

        w.ExtendsContentIntoTitleBar(true);
        w.AppWindow().TitleBar().PreferredHeightOption(winrt::Microsoft::UI::Windowing::TitleBarHeightOption::Tall);
        w.SetTitleBar(c->row);
        g_chromes.push_back(c);

        std::weak_ptr<Chrome> weak = c;
        auto again = [weak](auto const&, auto const&) { if (auto c = weak.lock()) chromeRegions(*c); };
        c->row.SizeChanged(again);
        c->title.SizeChanged(again);
        c->menus.SizeChanged(again);
        c->row.Loaded([weak](auto const&, auto const&) {
            auto c = weak.lock();
            if (c == nullptr) return;
            chromeButtons(*c);
            chromeBackdrop(*c);
            chromeRegions(*c);
            c->row.XamlRoot().Changed([weak](auto const&, auto const&) { if (auto c = weak.lock()) chromeRegions(*c); });
        });
        c->outer.ActualThemeChanged([weak](auto const&, auto const&) {
            if (auto c = weak.lock()) { chromeButtons(*c); chromeBackdrop(*c); }
        });
        // The caption dimmed its title when the window lost the focus.
        w.Activated([weak](auto const&, winrt_xaml::WindowActivatedEventArgs const& args) {
            auto c = weak.lock();
            if (c == nullptr) return;
            bool away = args.WindowActivationState() == winrt_xaml::WindowActivationState::Deactivated;
            c->title.Opacity(away ? 0.5 : 1.0);
            c->menus.Opacity(away ? 0.5 : 1.0);
        });
        w.Closed([weak](auto const&, auto const&) {
            auto c = weak.lock();
            if (c == nullptr) return;
            g_chromes.erase(std::remove(g_chromes.begin(), g_chromes.end(), c), g_chromes.end());
        });
        return c->outer;
    }

    // A menu bar belongs in its window\'s title bar row, where there is one.
    // It is moved there once it is loaded -- before, it is in no window yet --
    // and a collapsed stand-in keeps its place among its siblings, so the
    // indices the reconciler inserts at still hold.
    std::unordered_map<int, winrt_xaml::UIElement> g_menuStandIns;

    void chromeAdoptMenu(int child, winrt_controls::MenuBar const& menu) {
        menu.Loaded([child](auto const& sender, auto const&) {
            auto menu = sender.template as<winrt_controls::MenuBar>();
            if (g_menuStandIns.count(child)) return;
            std::shared_ptr<Chrome> chrome;
            for (auto const& c : g_chromes) if (c->outer.XamlRoot() == menu.XamlRoot()) { chrome = c; break; }
            if (chrome == nullptr) return;
            auto weak = winrt::make_weak(menu);
            std::weak_ptr<Chrome> weakChrome = chrome;
            menu.DispatcherQueue().TryEnqueue([child, weak, weakChrome]() {
                auto menu = weak.get();
                auto c = weakChrome.lock();
                if (menu == nullptr || c == nullptr || g_menuStandIns.count(child)) return;
                auto parent = winrt::Microsoft::UI::Xaml::Media::VisualTreeHelper::GetParent(menu).try_as<winrt_controls::Panel>();
                if (parent == nullptr) return;
                uint32_t at = 0;
                if (!parent.Children().IndexOf(menu, at)) return;
                winrt_controls::Border standIn;
                standIn.Visibility(winrt_xaml::Visibility::Collapsed);
                winrt_controls::Grid::SetRow(standIn, winrt_controls::Grid::GetRow(menu));
                winrt_controls::Grid::SetColumn(standIn, winrt_controls::Grid::GetColumn(menu));
                parent.Children().SetAt(at, standIn);
                winrt_controls::Grid::SetRow(menu, 0);
                winrt_controls::Grid::SetColumn(menu, 0);
                menu.Background(nullptr);
                c->menus.Children().Append(menu);
                g_menuStandIns.insert_or_assign(child, standIn);
            });
        });
    }

    // Whether `c` was a menu bar moved to a title bar; if so it leaves both
    // places, and its stand-in\'s index is given back for the caller to drop.
    bool chromeReleaseMenu(int child, winrt_xaml::UIElement const& c, winrt_controls::Panel const& parent, uint32_t& at) {
        auto found = g_menuStandIns.find(child);
        if (found == g_menuStandIns.end()) return false;
        bool there = parent.Children().IndexOf(found->second, at);
        if (auto holder = winrt::Microsoft::UI::Xaml::Media::VisualTreeHelper::GetParent(c).try_as<winrt_controls::Panel>()) {
            uint32_t i = 0;
            if (holder.Children().IndexOf(c, i)) holder.Children().RemoveAt(i);
        }
        g_menuStandIns.erase(found);
        return there;
    }

';
	}
}

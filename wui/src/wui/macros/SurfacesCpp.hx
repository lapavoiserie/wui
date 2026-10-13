package wui.macros;

/**
	The native half of the surfaces past the main window -- Present, the
	notification area and its panel -- as emitted into `WuiNodes.cpp`.

	Kept out of `BridgeGenerator` because it is a different subject: windows
	and the shell, not nodes. `source()` lands inside `wui::nodes` (it needs
	`registerRoot` and the window table); `externs()` after it, at file scope,
	is what the hxcpp library calls (`wui.bridge.Surfaces`). The library is
	called back through `wui_bridge_panel_opened` / `_closed`, defined in
	`wui.bridge.HaxeBridge`.
**/
class SurfacesCpp {
	/** Headers the code below needs, for the top of the file. **/
	public static function includes():String {
		return '#include <windows.h>
#include <shellapi.h>
#include <dwmapi.h>
#include <microsoft.ui.xaml.window.h>
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Windows.UI.ViewManagement.h>
#include <winrt/Microsoft.UI.Input.h>
#include <winrt/Microsoft.UI.Composition.SystemBackdrops.h>
#include <algorithm>
#include <string_view>
#include <winrt/Windows.Storage.Streams.h>
#include <memory>
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "advapi32.lib")
extern "C" void wui_bridge_panel_opened(int rootHandle);
extern "C" void wui_bridge_panel_closed(int rootHandle);
extern "C" void wui_bridge_tray_command(int index);
extern "C" void wui_bridge_dispose_primary();
extern "C" bool wui_bridge_extends_title_bar();
';
	}

	public static function source():String {
		return '    // ---- windows: the Primary, Present ----
    // Closing the main window hides it while the application lives in the
    // notification area; otherwise closing it ends the application.
    static bool g_hideOnClose = false;

    HWND hwndOf(winrt_xaml::Window const& w) {
        HWND h = nullptr;
        if (auto native = w.try_as<::IWindowNative>()) native->get_WindowHandle(&h);
        return h;
    }

    void setPrimaryWindow(winrt_xaml::Window const& window, int root) {
        g_windowOf[root] = window;
        g_primaryRoot = root;
        window.AppWindow().Closing([](auto const&, winrt::Microsoft::UI::Windowing::AppWindowClosingEventArgs const& args) {
            if (!g_hideOnClose) return;
            args.Cancel(true);
            auto it = g_windowOf.find(g_primaryRoot);
            if (it != g_windowOf.end()) it->second.AppWindow().Hide();
        });
    }

    // As wide as the content asks, never narrower than minWidth, as tall as
    // it is at that width -- in device pixels, at the window\'s own scale.
    void fitWindow(winrt_xaml::Window const& window, double minWidth) {
        auto content = window.Content().try_as<winrt::Microsoft::UI::Xaml::UIElement>();
        if (content == nullptr) return;
        content.Measure(winrt::Windows::Foundation::Size{ 100000, 100000 });
        double width = content.DesiredSize().Width < minWidth ? minWidth : content.DesiredSize().Width;
        content.Measure(winrt::Windows::Foundation::Size{ (float)width, 100000 });
        double height = content.DesiredSize().Height;
        HWND h = hwndOf(window);
        double scale = (h ? GetDpiForWindow(h) : 96) / 96.0;
        window.AppWindow().ResizeClient(winrt::Windows::Graphics::SizeInt32{ (int)(width * scale), (int)(height * scale) });
    }

    // Restored if minimised, shown if hidden, raised, and the application
    // brought to the front.
    bool presentWindow(winrt_xaml::Window const& w) {
        auto app = w.AppWindow();
        if (auto overlapped = app.Presenter().try_as<winrt::Microsoft::UI::Windowing::OverlappedPresenter>()) {
            if (overlapped.State() == winrt::Microsoft::UI::Windowing::OverlappedPresenterState::Minimized) overlapped.Restore();
        }
        app.Show();
        w.Activate();
        if (HWND h = hwndOf(w)) SetForegroundWindow(h);
        return true;
    }

    // ---- the notification area ----
    const UINT WM_WUI_TRAY = WM_APP + 41;
    HWND g_trayHwnd = nullptr;
    UINT g_taskbarCreated = 0;
    bool g_trayAdded = false;
    std::wstring g_trayTitle;
    std::wstring g_trayGlyph;
    int g_trayBadge = 0;
    HICON g_trayIcon = nullptr;

    winrt_xaml::Window g_panel{ nullptr };
    int g_panelRoot = -1;
    ULONGLONG g_panelClosedAt = 0;

    bool taskbarIsLight() {
        DWORD value = 0, size = sizeof value;
        return RegGetValueW(HKEY_CURRENT_USER, L"Software\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Themes\\\\Personalize",
            L"SystemUsesLightTheme", RRF_RT_REG_DWORD, nullptr, &value, &size) == ERROR_SUCCESS && value == 1;
    }

    // How much of each pixel a text covers, drawn white on black by GDI.
    std::vector<BYTE> coverage(int size, std::wstring const& text, wchar_t const* face, int height, int weight, RECT box) {
        BITMAPINFO bi{};
        bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bi.bmiHeader.biWidth = size;
        bi.bmiHeader.biHeight = -size;
        bi.bmiHeader.biPlanes = 1;
        bi.bmiHeader.biBitCount = 32;
        bi.bmiHeader.biCompression = BI_RGB;
        void* bits = nullptr;
        HDC screen = GetDC(nullptr);
        HDC dc = CreateCompatibleDC(screen);
        HBITMAP bmp = CreateDIBSection(screen, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
        HGDIOBJ oldBmp = SelectObject(dc, bmp);
        HFONT font = CreateFontW(-height, 0, 0, 0, weight, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
            OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY, DEFAULT_PITCH, face);
        HGDIOBJ oldFont = SelectObject(dc, font);
        SetBkMode(dc, TRANSPARENT);
        SetTextColor(dc, RGB(255, 255, 255));
        DrawTextW(dc, text.c_str(), -1, &box, DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOCLIP);
        GdiFlush();
        std::vector<BYTE> out(size * size);
        auto px = static_cast<BYTE*>(bits);
        for (int i = 0; i < size * size; ++i) out[i] = px[i * 4 + 2];
        SelectObject(dc, oldFont);
        SelectObject(dc, oldBmp);
        DeleteObject(font);
        DeleteObject(bmp);
        DeleteDC(dc);
        ReleaseDC(nullptr, screen);
        return out;
    }

    // The label as an icon: the glyph in the taskbar\'s ink, and the count on
    // an accent disc at the bottom right when there is one.
    HICON makeTrayIcon(std::wstring const& glyph, int badge) {
        UINT dpi = GetDpiForSystem();
        int size = GetSystemMetricsForDpi(SM_CXSMICON, dpi);
        // No glyph of its own: the application\'s icon, when it has one. A
        // copy, since the caller destroys the icon it replaces. The count,
        // if any, is in the tooltip.
        if (glyph.empty()) {
            if (HICON own = appIcon(size)) return CopyIcon(own);
        }
        auto ink = taskbarIsLight() ? RGB(0x1A, 0x1A, 0x1A) : RGB(0xFF, 0xFF, 0xFF);
        // The count in the taskbar\'s own ink, its digits in the opposite: an
        // accent disc vanished on a taskbar drawn in the accent colour.
        auto paper = taskbarIsLight() ? RGB(0xFF, 0xFF, 0xFF) : RGB(0x1A, 0x1A, 0x1A);

        // With a count, the glyph steps up and left to make room for it.
        int room = badge > 0 ? (int)(size * 0.8) : size;
        std::vector<BYTE> mark = coverage(size, glyph, L"Segoe Fluent Icons", (int)(room * 0.9), FW_NORMAL, RECT{ 0, 0, room, room });
        std::vector<BYTE> disc(size * size, 0), ring(size * size, 0), digits(size * size, 0);
        double r = size * 0.27;
        double cx = size - r, cy = size - r;
        if (badge > 0) {
            for (int y = 0; y < size; ++y) for (int x = 0; x < size; ++x) {
                double d = std::sqrt((x + 0.5 - cx) * (x + 0.5 - cx) + (y + 0.5 - cy) * (y + 0.5 - cy));
                double a = r + 0.5 - d;
                disc[y * size + x] = (BYTE)(a <= 0 ? 0 : a >= 1 ? 255 : a * 255);
                // A gap around the disc, cut out of the glyph, so the two read
                // as two things.
                double g = r + 1.5 + 0.5 - d;
                ring[y * size + x] = (BYTE)(g <= 0 ? 0 : g >= 1 ? 255 : g * 255);
            }
            std::wstring said = badge > 9 ? std::wstring(L"9+") : std::to_wstring(badge);
            RECT box{ (LONG)(cx - r), (LONG)(cy - r), (LONG)(cx + r), (LONG)(cy + r) };
            digits = coverage(size, said, L"Segoe UI", (int)(r * 1.6), FW_BOLD, box);
        }

        BITMAPINFO bi{};
        bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bi.bmiHeader.biWidth = size;
        bi.bmiHeader.biHeight = -size;
        bi.bmiHeader.biPlanes = 1;
        bi.bmiHeader.biBitCount = 32;
        bi.bmiHeader.biCompression = BI_RGB;
        void* bits = nullptr;
        HDC screen = GetDC(nullptr);
        HBITMAP color = CreateDIBSection(screen, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
        ReleaseDC(nullptr, screen);
        auto px = static_cast<BYTE*>(bits);
        for (int i = 0; i < size * size; ++i) {
            // Straight colour and alpha, layered, then premultiplied.
            double a = 0, rr = 0, gg = 0, bb = 0;
            auto over = [&](double cr, double cg, double cb, double ca) {
                double out = ca + a * (1 - ca);
                if (out <= 0) return;
                rr = (cr * ca + rr * a * (1 - ca)) / out;
                gg = (cg * ca + gg * a * (1 - ca)) / out;
                bb = (cb * ca + bb * a * (1 - ca)) / out;
                a = out;
            };
            over(GetRValue(ink), GetGValue(ink), GetBValue(ink), mark[i] / 255.0 * (1 - ring[i] / 255.0));
            over(GetRValue(ink), GetGValue(ink), GetBValue(ink), disc[i] / 255.0);
            over(GetRValue(paper), GetGValue(paper), GetBValue(paper), digits[i] / 255.0 * (disc[i] / 255.0));
            px[i * 4 + 0] = (BYTE)(bb * a);
            px[i * 4 + 1] = (BYTE)(gg * a);
            px[i * 4 + 2] = (BYTE)(rr * a);
            px[i * 4 + 3] = (BYTE)(a * 255);
        }
        std::vector<BYTE> zeros(((size + 15) / 16) * 2 * size, 0);
        HBITMAP mask = CreateBitmap(size, size, 1, 1, zeros.data());
        ICONINFO info{ TRUE, 0, 0, mask, color };
        HICON icon = CreateIconIndirect(&info);
        DeleteObject(mask);
        DeleteObject(color);
        return icon;
    }

    void closePanel();
    void openPanel();
    void trayApply();
    void trayRemove();

    // The icon\'s context menu: the labels the application\'s Status offers,
    // replaced on every pass. None, and the right button opens the panel too.
    static std::vector<std::wstring> g_trayMenu;

    void trayMenu(HWND h, POINT at) {
        HMENU menu = CreatePopupMenu();
        for (size_t i = 0; i < g_trayMenu.size(); i++)
            AppendMenuW(menu, MF_STRING, (UINT_PTR)(i + 1), g_trayMenu[i].c_str());
        // The documented dance: the owner in front, or the menu never closes
        // when the person clicks elsewhere.
        SetForegroundWindow(h);
        UINT align = GetSystemMetrics(SM_MENUDROPALIGNMENT) ? TPM_RIGHTALIGN : TPM_LEFTALIGN;
        int chosen = (int)TrackPopupMenuEx(menu, align | TPM_BOTTOMALIGN | TPM_RETURNCMD | TPM_NONOTIFY,
            at.x, at.y, h, nullptr);
        PostMessageW(h, WM_NULL, 0, 0);
        DestroyMenu(menu);
        if (chosen > 0) wui_bridge_tray_command(chosen - 1);
    }

    void togglePanel() {
        if (g_panel != nullptr) { closePanel(); return; }
        // The click that took the focus from an open panel closed it on its
        // way here: it must not open it again.
        if (GetTickCount64() - g_panelClosedAt < 300) return;
        openPanel();
    }

    LRESULT CALLBACK trayProc(HWND h, UINT m, WPARAM w, LPARAM l) {
        if (m == WM_WUI_TRAY) {
            UINT event = LOWORD(l);
            if (event == WM_CONTEXTMENU && !g_trayMenu.empty()) {
                // Version 4: the anchor arrives in wParam, in screen coordinates.
                if (g_panel != nullptr) closePanel();
                trayMenu(h, POINT{ (short)LOWORD(w), (short)HIWORD(w) });
            } else if (event == NIN_SELECT || event == NIN_KEYSELECT || event == WM_CONTEXTMENU) togglePanel();
            return 0;
        }
        // Windows is shutting down or the person signing out: no objection,
        // and the end of Present.quit done here and now -- the process is
        // ended once WM_ENDSESSION returns, so there is no later turn to
        // queue it on. The panel\'s record goes with the surfaces. A
        // cancelled end (wParam FALSE) changes nothing.
        if (m == WM_QUERYENDSESSION) return TRUE;
        if (m == WM_ENDSESSION) {
            if (w) {
                g_hideOnClose = false;
                trayRemove();
                wui_bridge_dispose_primary();
            }
            return 0;
        }
        // Explorer restarted: the icon has to be added again.
        if (m == g_taskbarCreated && g_taskbarCreated != 0) {
            g_trayAdded = false;
            trayApply();
            return 0;
        }
        return DefWindowProcW(h, m, w, l);
    }

    // A hidden top-level window, not a message-only one: only a top-level
    // window hears that the taskbar was created again.
    HWND trayWindow() {
        if (g_trayHwnd != nullptr) return g_trayHwnd;
        WNDCLASSEXW cls{ sizeof cls };
        cls.lpfnWndProc = trayProc;
        cls.hInstance = GetModuleHandleW(nullptr);
        cls.lpszClassName = L"WuiNotificationArea";
        RegisterClassExW(&cls);
        g_taskbarCreated = RegisterWindowMessageW(L"TaskbarCreated");
        g_trayHwnd = CreateWindowExW(WS_EX_TOOLWINDOW, cls.lpszClassName, L"", WS_POPUP, 0, 0, 0, 0,
            nullptr, nullptr, cls.hInstance, nullptr);
        return g_trayHwnd;
    }

    void trayApply() {
        NOTIFYICONDATAW nid{ sizeof nid };
        nid.hWnd = trayWindow();
        nid.uID = 1;
        nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
        nid.uCallbackMessage = WM_WUI_TRAY;
        HICON old = g_trayIcon;
        g_trayIcon = makeTrayIcon(g_trayGlyph, g_trayBadge);
        nid.hIcon = g_trayIcon;
        std::wstring tip = g_trayBadge > 0 ? g_trayTitle + L" (" + std::to_wstring(g_trayBadge) + L")" : g_trayTitle;
        wcsncpy_s(nid.szTip, tip.c_str(), _TRUNCATE);
        if (!g_trayAdded) {
            g_trayAdded = Shell_NotifyIconW(NIM_ADD, &nid) != FALSE;
            nid.uVersion = NOTIFYICON_VERSION_4;
            Shell_NotifyIconW(NIM_SETVERSION, &nid);
        } else {
            Shell_NotifyIconW(NIM_MODIFY, &nid);
        }
        if (old != nullptr) DestroyIcon(old);
    }

    void trayRemove() {
        if (!g_trayAdded) return;
        NOTIFYICONDATAW nid{ sizeof nid };
        nid.hWnd = g_trayHwnd;
        nid.uID = 1;
        Shell_NotifyIconW(NIM_DELETE, &nid);
        g_trayAdded = false;
    }

    // Above the icon, inside the work area, 380 wide and as tall as what it
    // holds.
    void placePanel(double dipHeight) {
        if (g_panel == nullptr) return;
        HWND h = hwndOf(g_panel);
        double scale = (h ? GetDpiForWindow(h) : 96) / 96.0;
        int width = (int)(380 * scale);
        int height = (int)((dipHeight < 48 ? 48 : dipHeight) * scale);
        NOTIFYICONIDENTIFIER id{ sizeof id };
        id.hWnd = g_trayHwnd;
        id.uID = 1;
        RECT icon{};
        POINT anchor{};
        if (SUCCEEDED(Shell_NotifyIconGetRect(&id, &icon))) anchor = POINT{ (icon.left + icon.right) / 2, icon.top };
        else GetCursorPos(&anchor);
        MONITORINFO mi{ sizeof mi };
        GetMonitorInfoW(MonitorFromPoint(anchor, MONITOR_DEFAULTTONEAREST), &mi);
        RECT work = mi.rcWork;
        int margin = (int)(12 * scale);
        if (height > (work.bottom - work.top) - 2 * margin) height = (work.bottom - work.top) - 2 * margin;
        int x = anchor.x - width / 2;
        if (x > work.right - width - margin) x = work.right - width - margin;
        if (x < work.left + margin) x = work.left + margin;
        int y = anchor.y < work.top ? work.top + margin : work.bottom - height - margin;
        g_panel.AppWindow().MoveAndResize(winrt::Windows::Graphics::RectInt32{ x, y, width, height });
    }

    void openPanel() {
        namespace windowing = winrt::Microsoft::UI::Windowing;
        winrt_xaml::Window w;
        auto app = w.AppWindow();
        auto presenter = windowing::OverlappedPresenter::Create();
        presenter.IsResizable(false);
        presenter.IsMaximizable(false);
        presenter.IsMinimizable(false);
        presenter.IsAlwaysOnTop(true);
        presenter.SetBorderAndTitleBar(true, false);
        app.SetPresenter(presenter);
        app.IsShownInSwitchers(false);
        try { w.SystemBackdrop(winrt::Microsoft::UI::Xaml::Media::DesktopAcrylicBackdrop()); } catch (...) {}
        if (HWND h = hwndOf(w)) {
            DWORD round = 2;
            DwmSetWindowAttribute(h, 33, &round, sizeof round);
        }

        winrt_controls::Grid root;
        root.Tag(winrt::box_value(L"column"));
        root.VerticalAlignment(winrt_xaml::VerticalAlignment::Top);
        winrt_controls::Grid host;
        host.Children().Append(root);
        w.Content(host);
        int handle = registerRoot(root);
        g_panel = w;
        g_panelRoot = handle;

        host.KeyDown([](auto const&, winrt::Microsoft::UI::Xaml::Input::KeyRoutedEventArgs const& args) {
            if (args.Key() != winrt::Windows::System::VirtualKey::Escape) return;
            args.Handled(true);
            closePanel();
        });
        w.Activated([](auto const&, winrt_xaml::WindowActivatedEventArgs const& args) {
            if (args.WindowActivationState() == winrt_xaml::WindowActivationState::Deactivated) closePanel();
        });

        wui_bridge_panel_opened(handle);

        root.Measure(winrt::Windows::Foundation::Size{ 380, 100000 });
        placePanel(root.DesiredSize().Height);
        root.SizeChanged([](auto const&, winrt_xaml::SizeChangedEventArgs const& args) {
            placePanel(args.NewSize().Height);
        });
        w.Activate();
        if (HWND h = hwndOf(w)) SetForegroundWindow(h);
    }

    // Closed on the next turn, never inside the event that asked: a command
    // in the panel that opens a window takes the activation from it, and
    // closing then disposed the panel under the click still running in it --
    // an access violation, on "Réglages…".
    bool g_panelClosing = false;

    void closePanel() {
        if (g_panel == nullptr || g_panelClosing) return;
        g_panelClosing = true;
        g_panelClosedAt = GetTickCount64();
        auto finish = []() {
            auto w = g_panel;
            int root = g_panelRoot;
            g_panel = nullptr;
            g_panelRoot = -1;
            g_panelClosing = false;
            if (w == nullptr) return;
            wui_bridge_panel_closed(root);
            w.Close();
        };
        auto queue = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();
        if (queue == nullptr || !queue.TryEnqueue(finish)) finish();
    }
';
	}

	/** What the hxcpp library calls, at file scope after `wui::nodes`. **/
	public static function externs():String {
		return '// ---- surfaces past the main window: see wui.bridge.Surfaces ----
extern "C" bool wui_window_present(int root) {
    auto it = g_windowOf.find(root < 0 ? g_primaryRoot : root);
    if (it == g_windowOf.end()) return false;
    return wui::nodes::presentWindow(it->second);
}

extern "C" void wui_window_fit(int root, double minWidth) {
    auto it = g_windowOf.find(root);
    if (it == g_windowOf.end()) return;
    auto window = it->second;
    wui::nodes::fitWindow(window, minWidth);
    // Again once the content is loaded: before, a control whose template is
    // not applied yet measures short -- a ToggleSwitch is its header alone,
    // and the window came out cutting the switch off.
    auto content = window.Content().try_as<winrt::Microsoft::UI::Xaml::FrameworkElement>();
    if (content == nullptr || content.IsLoaded()) return;
    auto token = std::make_shared<winrt::event_token>();
    *token = content.Loaded([window, minWidth, token](winrt::Windows::Foundation::IInspectable const& sender, auto const&) {
        sender.as<winrt::Microsoft::UI::Xaml::FrameworkElement>().Loaded(*token);
        wui::nodes::fitWindow(window, minWidth);
    });
}

extern "C" void wui_window_title(int root, const char* title) {
    auto it = g_windowOf.find(root);
    if (it == g_windowOf.end()) return;
    wui::nodes::chromeTitle(it->second, winrt::hstring(wui::runtime::fromUtf8(title)));
}

extern "C" void wui_window_hide_on_close(bool on) {
    wui::nodes::g_hideOnClose = on;
}

extern "C" void wui_tray_set(const char* title, const char* glyph, int badge) {
    wui::nodes::g_trayTitle = std::wstring(wui::runtime::fromUtf8(title));
    wui::nodes::g_trayGlyph = std::wstring(wui::runtime::fromUtf8(glyph));
    wui::nodes::g_trayBadge = badge;
    wui::nodes::trayApply();
}

// The context menu\'s labels, one per line; empty for none.
extern "C" void wui_tray_menu(const char* labels) {
    auto& menu = wui::nodes::g_trayMenu;
    menu.clear();
    std::wstring all(wui::runtime::fromUtf8(labels));
    size_t start = 0;
    while (start < all.size()) {
        size_t end = all.find(L\'\\n\', start);
        if (end == std::wstring::npos) end = all.size();
        menu.push_back(all.substr(start, end - start));
        start = end + 1;
    }
}

extern "C" void wui_tray_remove() {
    wui::nodes::trayRemove();
}

extern "C" void wui_panel_close() {
    wui::nodes::closePanel();
}

// Asked for from a command: done once the command has returned, as
// Present.show is. The icon goes, every surface is disposed -- the
// application\'s lifetime last -- and the application exits.
extern "C" void wui_app_quit() {
    auto finish = []() {
        wui::nodes::g_hideOnClose = false;
        wui::nodes::closePanel();
        wui::nodes::trayRemove();
        wui_bridge_dispose_primary();
        winrt::Microsoft::UI::Xaml::Application::Current().Exit();
    };
    auto queue = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();
    if (queue == nullptr || !queue.TryEnqueue(finish)) finish();
}

';
	}
}

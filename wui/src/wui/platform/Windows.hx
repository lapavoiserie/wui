package wui.platform;

/**
 * Windows-specific APIs for customizing the application window.
 */
class Windows {
    /**
        Whether windows draw their own title bar: the content running up
        under the caption buttons, on Mica, with the title and the menu bar
        in a row of their own, as Windows 11 applications have it. `false`
        gives back the system caption -- for an application that hosts
        something the row would get in the way of. Read when each window
        is made; see `wui.macros.TitleBarCpp`.
    **/
    public static var extendIntoTitleBar:Bool = true;

    /** Custom title bar background color (ARGB hex). */
    public static var titleBarColor:Null<String> = null;

    /** Whether to show the minimize button. */
    public static var showMinimize:Bool = true;

    /** Whether to show the maximize button. */
    public static var showMaximize:Bool = true;

    /** Minimum window size. */
    public static var minWidth:Int = 320;
    public static var minHeight:Int = 240;
}

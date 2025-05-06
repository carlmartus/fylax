using Gtk;
using GLib;

void fatal_error(Error err) {
    stderr.printf("Fatal error: %s (%d)\n", err.message, err.code);
    Gtk.main_quit();
}

void main(string[] args) {
    Gtk.init(ref args);

    var css = new Gtk.CssProvider ();
    css.load_from_resource("/org/carlmartus/fylax/style.css");

    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default (),
        css,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    );

    FylaxTs.Init();

    try {
        var app_win = new App.Window();
        app_win.ready();
        app_win.show_all();

        Gtk.main();
    } catch (Error err) {
        stderr.printf("Failed to create GTK application: %s\n", err.message);
    } finally {
        FylaxTs.Deinit();
    }
}

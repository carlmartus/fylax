using Gtk;

[GtkTemplate(ui="/org/carlmartus/fylax/settings.glade")]
class Settings : Gtk.Dialog {
    [GtkChild] private unowned Gtk.FileChooserButton path;
    [GtkChild] private unowned Gtk.Button btn_ok;
    [GtkChild] private unowned Gtk.Button btn_cancel;

    public signal void settings_ok(ConfigFields fields);
    public signal void settings_cancel();

    private ConfigFields fields;

    construct {
        this.btn_ok.clicked.connect(this.ok);
        this.btn_cancel.clicked.connect(this.cancel);
    }

    public void activate_dialog(Gtk.Window? overlay) throws Error {
        ConfigFile cfg = new ConfigFile.from_user();
        this.fields = cfg.fields;
        this.path.set_current_folder(fields.base_dir);

        if (overlay != null) {
            this.set_transient_for(overlay);
        }

        this.set_transient_for(overlay);
        this.set_modal(true);
        this.show();
    }

    private void ok() {
        uint changes = 0;
        string? dir_name = this.path.get_filename();

        if (dir_name != null) {
            this.fields.base_dir = dir_name;
            changes++;
        }

        if (changes > 0) {
            try {
                ConfigFile cfg = new ConfigFile.from_fields(this.fields);
                cfg.save();
            } catch (Error err) {
                assert_not_reached();
            }
        }

        this.close();
        this.settings_ok(this.fields);
    }

    private void cancel() {
        this.close();
        this.settings_cancel();
    }
}

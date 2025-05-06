[GtkTemplate(ui="/org/carlmartus/fylax/widget_loading.glade")]
class Widget.Loading : Gtk.Revealer {
    [GtkChild] private unowned Gtk.Label info;
    private uint count;
    private string msg_init;

    construct {
        this.msg_init = info.get_text();
    }

    public void increase_count(uint increase = 1) {
        this.count += increase;

        if (count % 10 == 0) {
            this.info.set_text(@"Loaded $(this.count) documents");
        }
    }

    public void begin() {
        this.count = 0;
        this.set_reveal_child(true);
    }

    public void done() {
        this.set_reveal_child(false);
    }
}


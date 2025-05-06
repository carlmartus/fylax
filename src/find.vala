[GtkTemplate(ui="/org/carlmartus/fylax/find.glade")]
class Find.Prompt : Gtk.Dialog {
    private SourceFunc async_close;
    private MetaDocument? mdoc;
    private Query.View<Gtk.TreePath> qv;

    [GtkChild] private unowned Gtk.Button btn_ok;
    [GtkChild] private unowned Gtk.Button btn_cancel;
    [GtkChild] private unowned Gtk.TreeView store_view;
    [GtkChild] private unowned Gtk.ListStore store;
    [GtkChild] private unowned Gtk.TreeModelFilter store_filter;
    [GtkChild] private unowned Gtk.SearchEntry entry_filter;
    [GtkChild] private unowned Gtk.AccelGroup accel_main;

    construct {
        this.async_close = null;
        this.mdoc = null;
        this.qv = new Query.View<Gtk.TreePath>();
        this.qv.view_add.connect((mdoc, visible, icon) => {
            Gtk.TreeIter iter;
            this.store.append(out iter);

            this.store.set(iter,
                    0, mdoc.zknid,
                    1, mdoc.title,
                    2, mdoc,
                    3, visible,
                    -1);

            Gtk.TreePath path = this.store.get_path(iter);
            assert_nonnull(path);
            mdoc.set_data<Gtk.TreePath>("tree_path", path);
            return path;
        });
        this.qv.view_remove.connect((mdoc, path) => {
            Gtk.TreeIter iter;
            this.store.get_iter(out iter, path);
            this.store.remove(ref iter);
        });
        this.qv.view_update.connect((mdoc, path) => {
            assert_not_reached();
        });
        this.qv.view_visibility.connect((mdoc, path, visible) => {
            Gtk.TreeIter iter;
            this.store.get_iter(out iter, path);
            this.store.set(iter, 3, visible, -1);
        });

        // Store filter function
        this.store_filter.set_visible_func((_, iter) => {
            bool show;
            this.store.get(iter, 3, out show, -1);
            return show;
        });

        // Buttons
        this.btn_ok.clicked.connect(this.ok);
        this.btn_cancel.clicked.connect(this.abort);

        // Window clone
        this.destroy.connect(this.abort);

        // Search entry
        this.entry_filter.changed.connect(() => {
            this.qv.prompt(this.entry_filter.get_text());
        });

        // Acceleration group
        this.accel_main.connect(Gdk.Key.Escape, 0, Gtk.AccelFlags.VISIBLE, () => {
            this.abort();
            return false;
        });
        this.accel_main.connect(Gdk.Key.Return, 0, Gtk.AccelFlags.VISIBLE, () => {
            this.ok();
            return false;
        });
    }

    public async MetaDocument? prompt(Gtk.Window? overlay, Center center) {
        this.async_close = this.prompt.callback;
        if (overlay != null) {
            this.set_transient_for(overlay);
        }
        this.show_all();
        this.qv.use(center, true);

        yield;

        Idle.add(() => {
            this.close();
            return false;
        });

        return this.mdoc;
    }

    private void ok() {
        Gtk.TreeSelection sel = this.store_view.get_selection();
        Gtk.TreeIter iter_filter;
        Gtk.TreeIter iter;
        if (sel.get_selected(null, out iter_filter)) {
            this.store_filter.convert_iter_to_child_iter(out iter, iter_filter);
            this.store.get(iter, 2, out this.mdoc, -1);

            this.trigger_async_close();
        }
    }

    private void trigger_async_close() {
        if (this.async_close != null) {
            Idle.add(this.async_close);
            this.async_close = null;
        }
    }

    private void abort() {
        this.mdoc = null;
        this.trigger_async_close();
    }
}

using Gtk;
using GLib;

enum MetaType {
    DOCUMENT,
    TAG,
    LINK,
}

enum DocumentMode {
    EMPTY,
    VIEW,
    EDIT,
}

[GtkTemplate(ui="/org/carlmartus/fylax/application.glade")]
class App.Window : Gtk.ApplicationWindow {

    [GtkChild] private unowned Gtk.Entry file_filter;
    [GtkChild] private unowned Gtk.TextView editor;
    [GtkChild] private unowned Gtk.HeaderBar header_bar;
    [GtkChild] private unowned Gtk.Button header_save;
    [GtkChild] private unowned Gtk.Button header_new;
    [GtkChild] private unowned Gtk.Button header_jumpto;
    [GtkChild] private unowned Gtk.Button header_edit;
    [GtkChild] private unowned Gtk.Button header_next;
    [GtkChild] private unowned Gtk.Button header_prev;
    [GtkChild] private unowned Gtk.Stack mode_stack;
    [GtkChild] private unowned Gtk.Widget mode_stack_empty;
    [GtkChild] private unowned Gtk.Widget mode_stack_view;
    [GtkChild] private unowned Gtk.Widget mode_stack_edit;
    [GtkChild] private unowned Gtk.Box read_box;
    [GtkChild] private unowned Gtk.Box tree_box;
    [GtkChild] private unowned Gtk.TreeView file_view;
    [GtkChild] private unowned Gtk.TreeView meta_view;
    [GtkChild] private unowned Gtk.MenuItem menu_item_settings;

    // Editor text buffer
    private unowned Gtk.TextBuffer texbuf;
    private unowned Gtk.TextTagTable editor_tagtable;

    // File view
    private unowned Gtk.ListStore file_tree_store;
    private unowned Gtk.TreeModelFilter file_tree_store_filter;
    private unowned Gtk.TreeModelSort file_tree_store_sort;

    private Query.View<Gtk.TreePath> file_tree_qv;
    private Query.View<Gtk.TreePath>? meta_qv = null;

    // Meta view
    private unowned Gtk.ListStore meta_tree_store;
    private unowned Gtk.TreeModelFilter meta_tree_filter;

    // From theme
    private Gtk.Image img_edit;
    private Gtk.Image img_view;

    // Loading revealer
    private Widget.Loading loading_revealer;

    private DocumentMode doc_mode;
    private MetaDocument? active_mdoc;

    // Read view
    private Read.Container? read_selected;
    private int read_count;

    // History
    private History history;

    private Center center;

    construct {
    }

    public void ready() throws Error {
        ConfigFile cfg = new ConfigFile.from_user();
        this.center = new Center(cfg.fields.base_dir);

        this.active_mdoc = null;
        this.read_selected = null;
        this.read_count = 0;

        this.build_ui();
        this.connect_accelerator();
        this.connect_center();

        // Init center, scan files
        this.center.ready.begin((obj, res) => {
            try {
                this.center.ready.end(res);
            } catch (Error err) {
                fatal_error(err);
            }
        });

    }

    private void build_ui() throws Error {
        // var builder = new Builder();
        // builder.add_from_resource("/org/carlmartus/fylax/application.glade");

        this.texbuf = this.editor.get_buffer();

        // this.img_edit = builder.get_object("img-edit") as Gtk.Image;
        // assert_nonnull(this.img_edit);
        this.img_edit = this.header_edit.get_image() as Gtk.Image;
        assert_nonnull(this.img_edit);
        this.img_view = new Gtk.Image.from_icon_name("view-reveal-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
        assert_nonnull(this.img_view);

        this.destroy.connect((_) => {
            Gtk.main_quit();
        });

        // Header save button
        this.header_save.clicked.connect(this.on_document_save_click);

        // New file button
        this.header_new.clicked.connect(() => {
            var mdoc_new = this.center.new_document();
            this.center.select_file(mdoc_new);
            // this.on_toggle_edit_mode();
        });

        // Jump to button
        this.header_jumpto.clicked.connect(() => {
            Find.Prompt f = new Find.Prompt();
            f.prompt.begin(this, this.center, (obj, res) => {
                MetaDocument? selected = f.prompt.end(res);
                if (selected != null) {
                    this.center.select_file(selected);
                }
            });
        });

        // Edit button
        this.header_edit.clicked.connect(this.on_toggle_edit_mode);

        // History buttons
        this.history = new History();
        this.history.status_prev.connect(this.header_prev.set_sensitive);
        this.history.status_next.connect(this.header_next.set_sensitive);
        this.header_next.clicked.connect(() => this.history_go(1));
        this.header_prev.clicked.connect(() => this.history_go(-1));
        this.history.reset();

        // File view storage
        this.file_tree_qv = new Query.View<Gtk.TreePath>();
        // this.file_tree_store_sort.set_sort_func(3, (model, itr0, itr1) => {
        //     int64 mod0, mod1;
        //     model.get(itr0, 3, out mod0, -1);
        //     model.get(itr1, 3, out mod1, -1);
        //     return (int) (mod0 - mod1);
        // });
        // this.file_tree_store_sort.set_sort_column_id(-1, Gtk.SortType.DESCENDING);

        // Bind file_tree_qv to UI
        this.file_tree_qv.view_add.connect((mdoc, visible, icon) => {
            Gtk.TreeIter iter;
            this.file_tree_store.append(out iter);

            Gtk.TreePath path = this.file_tree_store.get_path(iter);
            assert_nonnull(path); // NULL POINTER!
            // stdout.printf("PATH %i\n", path.get_depth());
            mdoc.set_data<Gtk.TreePath>("tree_path", path);

            this.file_tree_store.set(iter,
                    0, mdoc.title,
                    1, mdoc,
                    2, visible,
                    3, mdoc.unix_modified,
                    -1);
            return path;
        });
        this.file_tree_qv.view_remove.connect((mdoc, path) => {
            Gtk.TreeIter iter;
            this.file_tree_store.get_iter(out iter, path);
            this.file_tree_store.remove(ref iter);
        });
        this.file_tree_qv.view_update.connect((mdoc, path) => {
            assert_not_reached();
        });
        this.file_tree_qv.view_visibility.connect((mdoc, path, visible) => {
            Gtk.TreeIter iter;
            this.file_tree_store.get_iter(out iter, path);
            this.file_tree_store.set(iter, 2, visible, -1);
        });
        this.file_tree_qv.use(this.center, true);

        // Click on file row
        this.file_view.row_activated.connect((path, _) => {
            Gtk.TreePath? child_path_ex =
                this.file_tree_store_filter.convert_path_to_child_path(path);
            assert_nonnull(child_path_ex);
            Gtk.TreePath? child_path =
                this.file_tree_store_sort.convert_path_to_child_path(child_path_ex);
            assert_nonnull(child_path);

            Gtk.TreeIter iter;
            this.file_tree_store.get_iter(out iter, child_path);
            MetaDocument mdoc;
            this.file_tree_store.get(iter, 1, out mdoc, -1);
            this.center.select_file(mdoc);
        });

        // File view models
        this.file_tree_store_filter = this.file_view.get_model() as Gtk.TreeModelFilter;
        this.file_tree_store_sort = this.file_tree_store_filter.get_model() as Gtk.TreeModelSort;
        this.file_tree_store = this.file_tree_store_sort.get_model() as Gtk.ListStore;

        // File store filter function
        this.file_tree_store_filter.set_visible_func((_, iter_sort) => {
            Gtk.TreeIter iter;
            this.file_tree_store_sort.convert_iter_to_child_iter(out iter, iter_sort);

            bool show;
            this.file_tree_store.get(iter, 2, out show, -1);
            return show;
        });

        // Meta view storage
        this.meta_tree_filter = this.meta_view.get_model() as Gtk.TreeModelFilter;
        this.meta_tree_store = this.meta_tree_filter.get_model() as Gtk.ListStore;
        assert_nonnull(this.meta_tree_filter);
        assert_nonnull(this.meta_tree_store);

        this.meta_tree_filter.set_visible_func((_, iter) => {
            bool show;
            this.meta_tree_store.get(iter, 4, out show, -1);
            return show;
        });

        meta_view.row_activated.connect((path, _) => {
            Gtk.TreeIter iter;
            Gtk.TreePath? child_path =
                this.meta_tree_filter.convert_path_to_child_path(path);
            this.meta_tree_store.get_iter(out iter, child_path);

            int type;
            string name, zknid;
            MetaDocument? mdoc;
            this.meta_tree_store.get(iter,
                0, out type,
                2, out name,
                3, out zknid,
                -1);

            switch (type) {
                case MetaType.DOCUMENT :
                    // TODO Link to document
                    break;

                case MetaType.TAG :
                    this.file_filter.set_text(@"#$(name)");
                    break;

                case MetaType.LINK :
                    mdoc = this.center.find_document_by_zknid(zknid);
                    this.center.select_file(mdoc);
                    break;

                default : assert_not_reached();
            }
        });

        // File view filter
        this.file_filter.changed.connect(this.on_file_filter_change);

        this.editor_tagtable = this.texbuf.get_tag_table();
        assert_nonnull(this.editor_tagtable);

        this.texbuf.insert_text.connect(this.on_texbuf_insert_text);
        this.texbuf.modified_changed.connect(this.on_texbuf_modified);

        this.menu_item_settings.activate.connect(() => {
            try {
                var s = new Settings();
                s.activate_dialog(this);
            } catch (Error err) {
                assert_not_reached();
            }
        });

        this.set_document_mode(DocumentMode.EMPTY);

        // Add loading revealer
        this.loading_revealer = new Widget.Loading();
        this.tree_box.pack_end(this.loading_revealer, false);
    }

    private void read_box_change_focus(Read.Container? selected) {
        this.read_selected = selected;
        this.read_box.forall((child) => {
            var c = child as Read.Container;
            if (c != selected) {
                c.defocus();
            }
        });
    }

    private void clicked_link(string uri) {
        bool ok = false;
        try {
            var mdoc = this.center.find_document_by_zknid(uri);
            if (mdoc != null) {
                this.center.select_file(mdoc);
                ok = true;
            } else if (Uri.is_valid(uri, UriFlags.NONE)) {
                ok = Gtk.show_uri_on_window(null, uri, Gtk.get_current_event_time());
            }
        } catch (Error err) {
            ok = false;
        }

        if (!ok) {
            Gtk.MessageDialog error_msg = new Gtk.MessageDialog(
                    this,
                    Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.WARNING,
                    Gtk.ButtonsType.OK,
                    "Unable to open ZKN link \"" + uri + "\".");
            error_msg.response.connect((response_id) => {
                error_msg.destroy();
            });
            error_msg.show();
        }
    }

    private void fill_view_cells(Document doc, uint selection_offset = 0) {
        this.read_box.forall((child) => {
            this.read_box.remove(child);
        });

        this.read_count = 0;

        uint focus_on = 0;

        FylaxTs.document_to_cells(doc.content, (container) => {
            container.focused.connect(this.read_box_change_focus);
            container.link_click.connect(this.clicked_link);
            container.set_data<int>("index", this.read_count);
            this.read_box.add(container);

            // Check if selected
            uint start, stop;
            container.get_range(out start, out stop);
            // if (selection_offset >= start && selection_offset < stop) {
            if (selection_offset >= start) {
                focus_on = this.read_count;
            }

            this.read_count++;
        });

        this.read_focus_on(focus_on);
    }

    private bool read_mode_edit() {
        if (this.doc_mode == DocumentMode.VIEW && this.read_selected != null) {
            uint text_start, text_stop;
            this.read_selected.get_range(out text_start, out text_stop);

            Gtk.TextIter i_ins, i_bnd;
            this.texbuf.get_iter_at_offset(out i_ins, (int) text_start);
            this.texbuf.get_iter_at_offset(out i_bnd, (int) text_stop);

            this.set_document_mode(DocumentMode.EDIT);
            this.editor.grab_focus();
            this.texbuf.select_range(i_ins, i_bnd);
            return true;
        }
        return false;
    }

    private void read_focus_on(uint index) {
        this.read_box.forall((child) => {
            var c = child as Read.Container;
            int child_index = c.get_data<int>("index");
            if (child_index == index) {
                c.grab_container_focus();
            }
        });
    }

    private bool read_move_focus(int direction) {
        if (this.doc_mode == DocumentMode.VIEW && this.read_selected != null) {
            int index = this.read_selected.get_data<int>("index");
            this.read_focus_on(index + direction);
            return true;
        } else {
            return false;
        }
    }

    private void connect_accelerator() {
        // Filter <C-S-t>
        Gtk.AccelGroup ag = new Gtk.AccelGroup();
        ag.connect(
            Gdk.Key.T,
            Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK,
            Gtk.AccelFlags.VISIBLE,
            () => {
                this.file_filter.grab_focus();
                this.file_filter.select_region(0, -1);
                return false;
            }
        );

        // Save <S-s>
        ag.connect(
            Gdk.Key.S,
            Gdk.ModifierType.CONTROL_MASK,
            Gtk.AccelFlags.VISIBLE,
            () => {
                this.save_if_possible();
                return false;
            }
        );

        // Go to read mode <ESC>
        ag.connect(Gdk.Key.Escape, 0, Gtk.AccelFlags.VISIBLE, () => {
            if (this.doc_mode == DocumentMode.EDIT) {
                this.set_document_mode(DocumentMode.VIEW);
                return true;
            } else {
                return false;
            }
        });

        // Edit e
        ag.connect(Gdk.Key.E, 0, 0, this.read_mode_edit);
        ag.connect(Gdk.Key.K, 0, 0, () => { return this.read_move_focus(-1); });
        ag.connect(Gdk.Key.J, 0, 0, () => { return this.read_move_focus(1); });
        this.add_accel_group(ag);
    }

    private void connect_center() {
        // this.center.file_tree_clear.connect(this.on_file_tree_clear);
        // this.center.file_tree_add.connect(this.on_file_tree_add);
        this.center.body_set_file.connect(this.on_body_set_file);

        this.center.scan_begin.connect(() => {
            this.loading_revealer.begin();
            this.set_sensitive(false);
        });
        this.center.scan_step.connect(() => {
            this.loading_revealer.increase_count();
        });
        this.center.scan_done.connect(() => {
            this.loading_revealer.done();
            this.set_sensitive(true);
            this.file_tree_store_sort.set_sort_column_id(3, Gtk.SortType.DESCENDING);
        });
    }

    private void save_if_possible() {
        if (this.texbuf.get_modified()) {
            this.texbuf.set_modified(false);
            this.texbuf.set_modified(false);

            Gtk.TextIter start, end;
            this.texbuf.get_bounds(out start, out end);
            this.center.save_document(
                this.active_mdoc,
                this.texbuf.get_text(start, end, true)
            );
        }
    }

    private void on_document_save_click() {
        save_if_possible();
    }

    private void on_file_filter_change() {
        this.file_tree_qv.prompt(this.file_filter.get_text());
    }

    private string icon_to_string(Query.Icon icon) {
        switch (icon) {
            case Query.Icon.DOCUMENT : return "📝";
            case Query.Icon.LINK_IN : return "▶️";
            case Query.Icon.LINK_OUT : return "◀️";
            case Query.Icon.LINK_BOTH : return "↔️";
        }
        assert_not_reached();
    }

    private void update_meta_store() {
        // Use symbols
        // '▶️' Link to
        // '◀️' Link from
        // '🏷️' same tag
        // All of these can be combined

        this.meta_qv = new Query.View<Gtk.TreePath>();

        this.meta_qv.view_add.connect((mdoc, visible, icon) => {
            TreeIter add;
            this.meta_tree_store.append(out add);
            this.meta_tree_store.set(add,
                    0, (int) MetaType.LINK,
                    1, icon_to_string(icon),
                    2, mdoc.title,
                    3, mdoc.zknid,
                    4, visible,
                    -1);

            Gtk.TreePath? path = this.meta_tree_store.get_path(add);
            assert_nonnull(path);
            return path;
        });

        this.meta_qv.view_visibility.connect((mdoc, path, visible, icon) => {
            Gtk.TreeIter iter;
            this.meta_tree_store.get_iter(out iter, path);
            this.meta_tree_store.set(
                iter,
                1, icon_to_string(icon),
                4, visible,
                -1
            );
        });

        this.meta_qv.use(this.center, false);
        this.meta_qv.track_document(this.active_mdoc);

        foreach (var tag in this.active_mdoc.tags) {
            TreeIter tmp_add;
            this.meta_tree_store.append(out tmp_add);
            this.meta_tree_store.set(tmp_add,
                    0, (int) MetaType.TAG,
                    1, "🏷️",
                    2, tag,
                    4, true,
                    -1);
        }
    }

    private void clear_meta_store() {
        this.meta_tree_store.clear();
        if (this.meta_qv != null) {
            // TODO Does this acctually delete the object?
            this.meta_qv = null;
        }
    }

    private void update_file_status() {
        if (this.active_mdoc != null) {
            bool modified = this.texbuf.get_modified();
            this.header_save.set_sensitive(modified);

            StringBuilder sb = new StringBuilder();
            if (modified) {
                sb.append_c('*');
            }
            sb.append("[[");
            sb.append(this.active_mdoc.zknid);
            sb.append("]] ");
            if (this.active_mdoc.title != this.active_mdoc.zknid) {
                sb.append(this.active_mdoc.title);
            }
            this.header_bar.set_subtitle(sb.str);

            // Update item in file tree
            Gtk.TreePath path = this.active_mdoc.get_data<Gtk.TreePath>("tree_path");
            assert_nonnull(path);

            Gtk.TreeIter iter;
            this.file_tree_store.get_iter(out iter, path);
            this.file_tree_store.set(iter, 0, this.active_mdoc.title, -1);

            this.clear_meta_store();
            this.update_meta_store();
        } else {
            this.header_save.set_sensitive(false);
            this.header_bar.set_subtitle("");
            this.clear_meta_store();
        }
    }

    private void on_texbuf_modified() {
        this.update_file_status();
    }

    private async void trigger_prompt_link() {
        Find.Prompt f = new Find.Prompt();

        var selected = yield f.prompt(this, this.center);

        if (selected != null) {
            StringBuilder sb = new StringBuilder();
            sb.append(selected.zknid);
            sb.append("]] ");
            sb.append(selected.title);
            string insert = sb.str;
            this.texbuf.insert_at_cursor(insert, insert.length);
        }
    }

    private void on_texbuf_insert_text(ref Gtk.TextIter iter, string text) {
        if (text == "[") {
            Gtk.TextIter start = iter;
            Gtk.TextIter stop = iter;
            start.backward_char();
            if (this.texbuf.get_text(start, stop, true) == "[") {
                this.trigger_prompt_link.begin((obj, res) => {
                    this.trigger_prompt_link.end(res);
                });
            }
        }

    }

    private void on_active_mdoc_update() {
        this.update_file_status();
    }

    private void on_body_set_file(MetaDocument mdoc, Document doc) {
        uint select_offset = 0;

        if (this.active_mdoc != null) {
            if (this.active_mdoc.equals(mdoc)) {
                Gtk.TextIter start, stop;
                this.texbuf.get_selection_bounds(out start, out stop);
                select_offset = (uint) start.get_offset();
            }
            this.active_mdoc.updated.disconnect(this.on_active_mdoc_update);
        }
        this.active_mdoc = null;

        this.texbuf.set_text(doc.content);
        this.header_bar.set_subtitle(mdoc.title);
        this.texbuf.set_modified(false);

        this.set_document_mode(DocumentMode.VIEW);

        this.fill_view_cells(doc, select_offset );
        this.active_mdoc = mdoc;

        this.active_mdoc.updated.connect(this.on_active_mdoc_update);
        this.update_file_status();

        HistoryRecord hr = { mdoc.zknid };
        this.history.push(hr);
    }

    private void history_go(int direction) {
        HistoryRecord hr;
        if (this.history.move(direction, out hr)) {
            var mdoc = this.center.find_document_by_zknid(hr.zknid);
            if (mdoc != null) {
                this.center.select_file(mdoc);
            }
        }
    }

    private void on_toggle_edit_mode() {
        assert_nonnull(this.active_mdoc);
        if (this.doc_mode == DocumentMode.EDIT) {
            this.set_document_mode(DocumentMode.VIEW);
        } else {
            this.set_document_mode(DocumentMode.EDIT);
        }
    }

    private void set_document_mode(DocumentMode mode) {
        bool sensitive = true;
        unowned Gtk.Widget? select = null;
        unowned Gtk.Image? image = null;
        unowned Gtk.Widget? focus = null;

        switch (mode) {
            case DocumentMode.EMPTY :
                select = this.mode_stack_empty;
                focus = this.file_filter;
                sensitive = false;
                break;

            case DocumentMode.VIEW :
                if (this.active_mdoc != null) {
                    this.save_if_possible();
                    this.center.select_file(this.active_mdoc);
                }
                select = focus = this.mode_stack_view;
                image = this.img_edit;
                break;

            case DocumentMode.EDIT :
                select = focus = this.mode_stack_edit;
                image = this.img_view;
                break;
        }

        assert_nonnull(select);

        this.header_edit.set_sensitive(sensitive);
        if (image != null) {
            this.header_edit.set_image(image);
        }
        if (focus != null) {
            focus.grab_focus();
        }
        this.mode_stack.set_visible_child(select);
        this.doc_mode = mode;
    }
}


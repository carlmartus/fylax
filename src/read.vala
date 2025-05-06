using Gtk;

public struct Read.EditRef {
    string? content;
    uint text_start;
    uint text_stop;

    public static Read.EditRef from_match(GLib.MatchInfo match_info, uint add_offset, int match_id = 1) {
        int start_pos, end_pos;
        string? match = match_info.fetch(match_id);
        assert_nonnull(match);

        match_info.fetch_pos(match_id, out start_pos, out end_pos);

        Read.EditRef er = {
            match,
            start_pos + add_offset,
            end_pos + add_offset
        };
        return er;
    }
}

[GtkTemplate(ui="/org/carlmartus/fylax/read_paragraph.glade")]
class Read.Paragraph : Gtk.Box {
    [GtkChild] private unowned Gtk.Label label;

    private Read.EditRef er_text;

    construct {}

    public void propagate(Read.Container rc) {
        rc.propagate_focus_label(label);
    }

    public void set_text(ref Read.EditRef er) {
        this.er_text = er;
        this.label.set_markup(FylaxTs.to_pango(er.content));
    }
}

[GtkTemplate(ui="/org/carlmartus/fylax/read_metadata.glade")]
class Read.Metadata : Gtk.Box {
    [GtkChild] private unowned Gtk.Label label;

    private Read.EditRef er_text;

    construct {}

    public void propagate(Read.Container rc) {
        rc.propagate_focus_label(label);
    }

    public void set_text(ref Read.EditRef er) {
        this.er_text = er;
        this.label.set_text(er.content);
    }
}

private double heading_level_to_scale(uint level) {
    switch (level) {
        case 1 : return 1.6;
        case 2 : return 1.5;
        case 3 : return 1.4;
        case 4 : return 1.3;
        case 5 : return 1.2;
        default: return 1.1;
    }
}

[GtkTemplate(ui="/org/carlmartus/fylax/read_heading.glade")]
class Read.Heading : Gtk.Box {
    [GtkChild] private unowned Gtk.Label label;

    private Read.EditRef er_text;

    construct {}

    public void propagate(Read.Container rc) {
        rc.propagate_focus_label(label);
    }

    public void set_text(ref Read.EditRef er) {
        this.er_text = er;
        this.label.set_markup(FylaxTs.to_pango(er.content));
    }

    public void set_level(uint level) {
        Pango.AttrList attrs = this.label.get_attributes();
        assert_nonnull(attrs);

        attrs.insert(Pango.attr_scale_new(
            heading_level_to_scale(level)
        ));
    }
}

[GtkTemplate(ui="/org/carlmartus/fylax/read_checkbox.glade")]
class Read.Checkbox : Gtk.Box {
    [GtkChild] private unowned Gtk.CheckButton check_box;
    [GtkChild] private unowned Gtk.Label label;

    private Read.EditRef er_text;
    private Read.EditRef? er_checkbox;

    construct {
        this.check_box.toggled.connect(this.on_checkbox);
        this.check_box.set_visible(false);
        this.er_checkbox = null;
    }

    public void set_text(ref Read.EditRef er) {
        this.er_text = er;
        this.label.set_markup(FylaxTs.to_pango(er.content));
    }

    public void set_indent(int level) {
        this.set_margin_start(5 * level);
    }

    public void set_checkbox(ref Read.EditRef er) {
        this.check_box.set_visible(true);
        this.check_box.set_active(er.content[0] != ' ');
        this.er_checkbox = er;
    }

    public void propagate(Read.Container rc) {
        rc.propagate_focus_label(this.label);
        rc.propagate_focus_chekbox(this.check_box);
    }

    private void on_checkbox() {
    }
}

[GtkTemplate(ui="/org/carlmartus/fylax/read_container.glade")]
public class Read.Container : Gtk.Box {
    [GtkChild] private unowned Gtk.Box select_mark;
    private Read.EditRef er_content;

    construct {
        this.set_focus_child.connect(() => {
            read_focus();
        });
    }

    public Read.Container.from_edit_reference(Read.EditRef er) {
        this.er_content = er;
    }

    public void propagate_focus_label(Gtk.Label l) {
        l.motion_notify_event.connect(() => {
            this.grab_container_focus();
            return true;
        });

        l.button_press_event.connect(() => {
            this.grab_container_focus();
            return false;
        });
        l.activate_link.connect((label, uri) => {
            this.link_click(uri);
            return true;
        });
    }

    public void grab_container_focus() {
        this.grab_focus();
        this.read_focus();
    }

    public void propagate_focus_chekbox(Gtk.CheckButton c) {
    }

    public void mount(Gtk.Widget w) {
        this.add(w);
    }

    private void read_focus() {
        var style = this.select_mark.get_style_context();
        style.add_class("info");
        this.focused(this);
    }

    public void defocus() {
        var style = this.select_mark.get_style_context();
        style.remove_class("info");
    }

    public void get_range(out uint start, out uint stop) {
        start = this.er_content.text_start;
        stop = this.er_content.text_stop;
    }

    public signal void focused(Read.Container selected);
    public signal void link_click(string uri);
}

private struct Read.Parser {
    bool in_fm;

    public void reset() {
        this.in_fm = false;
    }
}

class Read.Factory {
    private Read.Parser parse;
    private GLib.StringBuilder buffer_paragraph;
    private uint buffer_paragraph_start;
    private uint buffer_paragraph_stop;
    private GLib.Regex regex_line;
    private GLib.Regex regex_list;

    public Factory() {
        this.parse.reset();
        this.buffer_paragraph = new GLib.StringBuilder();
        this.buffer_paragraph_start = 0;
        this.buffer_paragraph_stop = 0;

        try {
            this.regex_line = new Regex("^(.*)$", GLib.RegexCompileFlags.MULTILINE);
            this.regex_list = new Regex("^(\\s*)[-*]\\s(\\[.\\])?\\s*(.*)$");
        } catch (Error err) {
            assert_not_reached();
        }
    }

    private void feed_checkbox(GLib.MatchInfo match_info, Read.EditRef er) {
        string match_indentation = match_info.fetch(1);
        string? match_checkbox = match_info.fetch(2);

        var rc = new Read.Checkbox();
        Read.EditRef er_text = Read.EditRef.from_match(match_info, er.text_start, 3);
        rc.set_text(ref er_text);
        string? match_indent = match_indentation;
        rc.set_indent(match_indent != null ? match_indent.length : 0);

        if (match_checkbox != null && match_checkbox.length >= 3) {
            Read.EditRef er_checkbox = Read.EditRef.from_match(match_info, er.text_start, 2);
            rc.set_checkbox(ref er_checkbox);
        }

        Read.Container container = new Read.Container.from_edit_reference(er_text);
        rc.propagate(container);
        container.mount(rc);

        this.emit_container(container);
    }

    private void feed_text(Read.EditRef er) {
        // Normal lines
        if (er.content.length == 0) {
            this.flush_paragraph();
        } else {
            if (this.buffer_paragraph.len == 0) {
                this.buffer_paragraph_start = er.text_start;
            } else {
                this.buffer_paragraph.append("\n");
            }
            this.buffer_paragraph.append(er.content);
            this.buffer_paragraph_stop = er.text_stop;
        }
    }

    private void feed_line(Read.EditRef er) {
        GLib.MatchInfo match_info;

        if (this.regex_list.match(er.content, 0, out match_info)) {
            this.flush_paragraph();
            this.feed_checkbox(match_info, er);
        } else {
            this.feed_text(er);
        }
    }

    private void feed_eof(uint offset) {
        this.flush_paragraph();
    }

    private void flush_paragraph() {
        if (this.buffer_paragraph.len > 0) {
            var str_paragraph = this.buffer_paragraph.str;
            var rp = new Read.Paragraph();

            Read.EditRef er = {
                str_paragraph,
                this.buffer_paragraph_start,
                this.buffer_paragraph_stop
            };

            rp.set_text(ref er);
            Read.Container container = new Read.Container.from_edit_reference(er);

            rp.propagate(container);
            container.mount(rp);
            this.emit_container(container);
            this.buffer_paragraph.erase(0, -1);
        }
    }

    public void scan(Document doc) throws Error {
        MatchInfo match_line;
        uint match_line_offset = 0;

        bool scan_more = this.regex_line.match(doc.content, GLib.RegexMatchFlags.NEWLINE_ANY, out match_line);
        while (scan_more) {
            Read.EditRef er = Read.EditRef.from_match(match_line, 0, 1);
            this.feed_line(er);

            scan_more = match_line.next();
            match_line_offset = er.text_stop;
        }

        this.feed_eof(match_line_offset);
    }

    public signal void emit_container(Read.Container container);
}

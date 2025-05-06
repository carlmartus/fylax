// [CCode (has_target = true)]
// extern void scan(char *buf, scan_cb cb);

namespace FylaxTs {
    enum ElementType {
        HEADER = 0,
        COUNT,
    }

    enum CellType {
        NONE = 0,
        HEADING,
        PARAGRPH,
        METADATA,
        LIST_ITEM,
    }

    public delegate void make_cell(owned Read.Container c);

    extern void init();
    extern void deinit();

    [CCode (has_target = true)]
    delegate void element(uint32 element_id, uint32 i0, uint32 i1);
    // extern void tmp_scan(char *str, element cb);

    [CCode (has_target = true)]
    // delegate void cell_text(string local_str, uint32 element_type, uint32[] args);
    delegate void cell_text(string local_str, uint32 element_type, uint32 a0, uint32 a1, uint32 a2);
    extern void scan_cells(char *str, cell_text cb);

    public void Init() {
        init();
    }

    public void Deinit() {
        deinit();
    }

    private Read.EditRef reference_from_offset(string str, uint a0, uint a1) {
        string sub = str.slice(a0, a1).strip();
        uint char_offset0 = str.char_count(a0);
        uint char_offset1 = char_offset0 + sub.char_count(a1);
        Read.EditRef er = { sub, str.char_count(a0), char_offset1 };
        return er;
    }

    private void push_cell_paragraph(string str, uint a0, uint a1, make_cell mc) {
        Read.EditRef er = reference_from_offset(str, a0, a1 - 1);

        var container = new Read.Container.from_edit_reference(er);
        var rp = new Read.Paragraph();
        rp.set_text(ref er);

        container.mount(rp);
        rp.propagate(container);
        mc(container);
    }

    private void push_cell_metadata(string str, uint a0, uint a1, make_cell mc) {
        Read.EditRef er = reference_from_offset(str, a0, a1);

        var container = new Read.Container.from_edit_reference(er);
        var rp = new Read.Metadata();
        rp.set_text(ref er);

        container.mount(rp);
        rp.propagate(container);
        mc(container);
    }

    private void push_cell_heading(string str, uint a0, uint a1, uint level, make_cell mc) {
        Read.EditRef er = reference_from_offset(str, a0, a1);

        var container = new Read.Container.from_edit_reference(er);
        var rh = new Read.Heading();
        rh.set_text(ref er);
        rh.set_level(level);

        container.mount(rh);
        rh.propagate(container);
        mc(container);
    }

    private void push_cell_list_item(string str, uint a0, uint a1, uint a2, make_cell mc) {
        Read.EditRef er = reference_from_offset(str, a0, a1 - 1);

        var container = new Read.Container.from_edit_reference(er);
        var rc = new Read.Checkbox();
        rc.set_text(ref er);

        if (a2 > 0) {
            string sub_checkbox = str.substring(a2, 1);
            Read.EditRef er_checkbox = { sub_checkbox, a0, a1 };
            rc.set_checkbox(ref er_checkbox);
        }

        container.mount(rc);
        rc.propagate(container);
        mc(container);
    }

    public void document_to_cells(owned string str, make_cell mc) {
        scan_cells(str, (local_str, element_id, a0, a1, a2) => {
            // Paragraph
            switch (element_id) {
                case CellType.NONE :
                    assert_not_reached();

                case CellType.HEADING :
                    push_cell_heading(local_str, a0, a1, a2, mc);
                    break;

                case CellType.PARAGRPH :
                    push_cell_paragraph(local_str, a0, a1, mc);
                    break;

                case CellType.METADATA :
                    push_cell_metadata(local_str, a0, a1, mc);
                    break;

                case CellType.LIST_ITEM :
                    push_cell_list_item(local_str, a0, a1, a2, mc);
                    break;
            }
        });
    }
}

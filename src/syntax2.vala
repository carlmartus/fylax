// private extern uint32 strlen(char *str);

namespace FylaxTs {
    enum PangoMarkup {
        NONE = 0,
        BOLD_POS,
        BOLD_NEG,
        ITALIC_POS,
        ITALIC_NEG,
        SHORTCUT,
        LINK_POS,
        LINK_NEG,
        AUTOLINK_POS,
        AUTOLINK_NEG,
        ZKN_POS,
        ZKN_NEG,
        CODE_SPAN_POS,
        CODE_SPAN_NEG,
        STRIKETHROUGH_POS,
        STRIKETHROUGH_NEG,
    }

    enum ScanType {
        STRING_LENGTH = 0,
        BOLD,
        ITALIC,
        SHORTCUT,
        LINK,
        AUTOLINK,
        CODE_SPAN,
        STRIKETHROUGH,
    }

    class ScanToken {
        public PangoMarkup pango_mu;
        public uint32 offset;
        public uint32 length;
        public string? arg;

        public ScanToken(PangoMarkup pango_mu,
                uint32 offset, uint32 length, string? arg) {
            this.pango_mu = pango_mu;
            this.offset = offset;
            this.length = length;
            this.arg = arg;
        }
    }

    private void insert_token(
            ref List<ScanToken> tks,
            PangoMarkup pango_mu,
            uint32 offset,
            uint32 length,
            string? arg = null) {
        ScanToken st = new ScanToken(pango_mu, offset, length, arg);

        CompareFunc<ScanToken> cmp_func = (a, b) => {
            return (int) a.offset - (int) b.offset;
        };

        tks.insert_sorted(st, cmp_func);
    }

    [CCode (has_target = true)]
    delegate void scan_cb(
        string local_str, uint32 element_type,
        uint32 a0, uint32 a1, uint32 a2, uint32 a3, uint32 a4, uint32 a5
    );
    extern void scan_syntax(char *str, scan_cb cb);

    public string to_pango(string str) {
        List<ScanToken> tks = new List<ScanToken>();

        var escaped = GLib.Markup.escape_text(str);
        uint32 escaped_len = 0;
        string? arg = null;
        scan_syntax(escaped, (local_str, pango_mu, a0, a1, a2, a3, a4, a5) => {
            switch (pango_mu) {
                case ScanType.STRING_LENGTH :
                    escaped_len = a0;
                    break;

                case ScanType.BOLD :
                    insert_token(ref tks, PangoMarkup.BOLD_POS, a0, 2);
                    insert_token(ref tks, PangoMarkup.BOLD_NEG, a1-2, 2);
                    break;

                case ScanType.ITALIC :
                    insert_token(ref tks, PangoMarkup.ITALIC_POS, a0, 1);
                    insert_token(ref tks, PangoMarkup.ITALIC_NEG, a1-1, 1);
                    break;

                case ScanType.SHORTCUT :
                    arg = escaped.slice(a0, a1);
                    if (
                            arg.length > 2 &&
                            arg[0] == '[' &&  arg[arg.length-1] == ']') {
                        var zkn_link = arg.slice(1, arg.length - 1);
                        insert_token(ref tks, PangoMarkup.ZKN_POS, a0+1, 0, zkn_link);
                        insert_token(ref tks, PangoMarkup.ZKN_NEG, a1-1, 0);
                    }
                    break;

                case ScanType.LINK :
                    arg = escaped.slice(a4, a5);
                    insert_token(ref tks, PangoMarkup.LINK_POS, a0, a2-a0, arg);
                    insert_token(ref tks, PangoMarkup.LINK_NEG, a3, a1-a3);
                    break;

                case ScanType.AUTOLINK :
                    arg = escaped.slice(a0+1, a1-1);
                    insert_token(ref tks, PangoMarkup.AUTOLINK_POS, a0, 1, arg);
                    insert_token(ref tks, PangoMarkup.AUTOLINK_NEG, a1-1, 1);
                    break;

                case ScanType.CODE_SPAN :
                    arg = escaped.slice(a0+1, a1-1);
                    insert_token(ref tks, PangoMarkup.CODE_SPAN_POS, a0, 1);
                    insert_token(ref tks, PangoMarkup.CODE_SPAN_NEG, a1-1, 1);
                    break;

                case ScanType.STRIKETHROUGH :
                    arg = escaped.slice(a0+1, a1-1);
                    insert_token(ref tks, PangoMarkup.STRIKETHROUGH_POS, a0, 2);
                    insert_token(ref tks, PangoMarkup.STRIKETHROUGH_NEG, a1-2, 2);
                    break;

                default :
                    assert_not_reached();
            }
        });

        uint32? last_valid = 0;
        StringBuilder sb = new StringBuilder();

        tks.foreach((entry) => {
            if (last_valid != null) {
                var slice = escaped.slice(last_valid, entry.offset);
                sb.append(slice);
                last_valid = entry.offset + entry.length;
            }

            switch (entry.pango_mu) {
                case PangoMarkup.BOLD_POS : sb.append("<b>"); break;
                case PangoMarkup.BOLD_NEG : sb.append("</b>"); break;
                case PangoMarkup.ITALIC_POS : sb.append("<i>"); break;
                case PangoMarkup.ITALIC_NEG : sb.append("</i>"); break;
                case PangoMarkup.LINK_POS :
                    sb.append("<a href=\"");
                    sb.append(entry.arg);
                    sb.append("\">");
                    break;
                case PangoMarkup.LINK_NEG : sb.append("</a>"); break;
                case PangoMarkup.AUTOLINK_POS :
                    sb.append("<a href=\"");
                    sb.append(entry.arg);
                    sb.append("\">");
                    break;
                case PangoMarkup.AUTOLINK_NEG : sb.append("</a>"); break;
                case PangoMarkup.ZKN_POS :
                    sb.append("<a href=\"");
                    sb.append(entry.arg);
                    sb.append("\">");
                    break;
                case PangoMarkup.ZKN_NEG : sb.append("</a>"); break;
                case PangoMarkup.CODE_SPAN_POS : sb.append("<tt>"); break;
                case PangoMarkup.CODE_SPAN_NEG : sb.append("</tt>"); break;
                case PangoMarkup.STRIKETHROUGH_POS : sb.append("<s>"); break;
                case PangoMarkup.STRIKETHROUGH_NEG : sb.append("</s>"); break;
                default :
                    assert_not_reached();
            }
        });

        if (last_valid != null && last_valid < escaped_len) {
            var slice = escaped.slice(last_valid, escaped_len);
            sb.append(slice);
        }

        return sb.str;
    }
}


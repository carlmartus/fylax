using GLib;

namespace FrontMatterExtern {

    enum InfoType {
        NONE = 0,
        TITLE,
        H1,
        TAG,
        LINK,
    }

    delegate void emit_info(
        uint32 type,
        uint32 a0,
        uint32 a1
    );

    extern void scan(
        string str,
        emit_info emit
    );
}

public class FrontMatter {
    public string? title = null;
    public string[] tags;
    public string[] links;

    public FrontMatter(string content) {
        string[] found_tags = {};
        string[] found_links = {};
        FrontMatterExtern.scan(content, (type, a0, a1) => {
            var value = content.slice(a0, a1);

            switch (type) {
                case FrontMatterExtern.InfoType.TITLE :
                    this.title = value;
                    break;

                case FrontMatterExtern.InfoType.H1 :
                    if (this.title == null) {
                        this.title = content.slice(a0, a1);
                    }
                    break;

                case FrontMatterExtern.InfoType.TAG :
                    found_tags += value;
                    break;

                case FrontMatterExtern.InfoType.LINK :
                    found_links += value;
                    break;

                default:
                    assert_not_reached();
            }
        });

        this.tags = found_tags;
        this.links = found_links;
    }
}

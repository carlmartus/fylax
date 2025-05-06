class Query.Pair <T> : GLib.Object {
    public GLib.WeakRef mdoc_ref;
    public bool match;
    public T data;

    public Pair(MetaDocument mdoc, T data, bool visible) {
        this.mdoc_ref = GLib.WeakRef(mdoc);
        this.match = visible;
        this.data = data;
    }
}

private enum Query.MatchMode {
    ALL,
    PROMPT,
    TRACK_DOCUMENT,
}

public enum Query.Icon {
    DOCUMENT,
    LINK_IN,
    LINK_OUT,
    LINK_BOTH,
}

enum Query.PromptKeyMode {
    WORD,
    TAG,
}

struct Query.PromptKey {
    // Component of a prompt string. Combine with AND match.
    public Query.PromptKeyMode mode;
    public string arg;
}

class Query.View <T> : GLib.Object {
    private Array<Query.Pair<T>> all_mdoc_pairs;

    private Query.MatchMode mode;
    private Query.PromptKey[]? mode_prompt;
    private GLib.WeakRef? mode_mdoc;
    private MetaDocument? tracking_document;

    public View() {
        this.all_mdoc_pairs = new Array<Query.Pair<T>>();
        this.mode = Query.MatchMode.ALL;
        this.mode_prompt = null;
        this.mode_mdoc = null;
    }

    public void use(Center center, bool default_visibility) {
        foreach (MetaDocument mdoc in center.get_all_metadocs()) {
            add_as_pair(mdoc, default_visibility, Icon.DOCUMENT);
        }

        center.cud_add.connect((mdoc) => {
            add_as_pair(mdoc, default_visibility, Icon.DOCUMENT);
        });
        center.cud_remove.connect((mdoc) => {
            var found = this.scan_for(mdoc);
            assert_nonnull(found);
        });
        center.cud_update.connect(this.cud_update);
    }

    private Pair<T>? scan_for(MetaDocument mdoc) {
        return null;
    }

    private void add_as_pair(MetaDocument mdoc, bool default_visibility, Icon icon) {
        T? data = this.view_add(mdoc, default_visibility, icon);
        assert_nonnull(data);
        Query.Pair<T> p = new Query.Pair<T>(mdoc, data, default_visibility);
        this.all_mdoc_pairs.append_val(p);
    }

    private void cud_remove(MetaDocument mdoc) {
        assert_not_reached();
    }

    private void cud_update(MetaDocument mdoc) {
        assert_not_reached();
    }

    private Query.PromptKey? prompt_component(string word) {
        if (word == "") {
            return null;
        }

        if (word[0] == '#') {
            if (word.length > 1) {
                Query.PromptKey pk = {
                    Query.PromptKeyMode.TAG,
                    word[1:word.length]
                };
                return pk;
            }
            return null;
        }

        Query.PromptKey pk = {
            Query.PromptKeyMode.WORD,
            word
        };
        return pk;
    }

    public void prompt(string msg) {
        this.mode = Query.MatchMode.PROMPT;

        this.mode_prompt = {};
        foreach (string word in msg.split(" ")) {
            var pk = this.prompt_component(word);
            if (pk != null) {
                this.mode_prompt += pk;
            }
        }

        this.scan_matches();
    }

    public void track_document(MetaDocument mdoc) {
        this.mode = Query.MatchMode.TRACK_DOCUMENT;
        this.tracking_document = mdoc;
        this.scan_matches();
    }

    private bool match_prompt_tag(string find_tag, MetaDocument mdoc) {
        foreach (string tag in mdoc.tags) {
            if (tag == find_tag) {
                return true;
            }
        }
        return false;
    }

    private bool match_prompt(MetaDocument mdoc) {
        foreach (unowned Query.PromptKey pk in this.mode_prompt) {
            // TODO Check lower case
            switch (pk.mode) {
                case Query.PromptKeyMode.WORD :
                    if (mdoc.zknid == pk.arg) {
                        return true;
                    } else if (mdoc.title.index_of(pk.arg, 0) < 0) {
                        return false;
                    }
                    break;
                case Query.PromptKeyMode.TAG :
                    if (!match_prompt_tag(pk.arg, mdoc)) {
                        return false;
                    }
                    break;
            }
        }
        return true;
    }

    private bool match_tracking(MetaDocument mdoc, out Icon icon) {
        uint match_bits = 0;
        icon = Icon.LINK_IN;

        // Match incomming links
        foreach (string zknid_link in mdoc.links) {
            if (zknid_link == this.tracking_document.zknid) {
                match_bits |= 1;
            }
        }

        // Match outgoing links
        foreach (string zknid_link in this.tracking_document.links) {
            if (zknid_link == mdoc.zknid) {
                match_bits |= 2;
            }
        }

        switch (match_bits) {
            case 0 :
                return false;
            case 1 :
                icon = Icon.LINK_IN;
                return true;
            case 2 :
                icon = Icon.LINK_OUT;
                return true;
            case 3 :
                icon = Icon.LINK_BOTH;
                return true;
            default : assert_not_reached();
        }
    }

    private void scan_matches() {
        foreach (Query.Pair<T> pair in this.all_mdoc_pairs) {
            Icon icon = Icon.DOCUMENT;
            MetaDocument? mdoc = pair.mdoc_ref.get() as MetaDocument?;
            assert_nonnull(mdoc);

            bool visible = pair.match;
            switch (this.mode) {
                case Query.MatchMode.ALL:
                    assert_not_reached();

                case Query.MatchMode.TRACK_DOCUMENT:
                    visible = this.match_tracking(mdoc, out icon);
                    break;

                case Query.MatchMode.PROMPT:
                    visible = this.match_prompt(mdoc);
                    break;

                default :
                    assert_not_reached();
            }

            if (pair.match != visible) {
                pair.match = visible;
                this.view_visibility(mdoc, pair.data, pair.match, icon);
            }
        }
    }

    // Signals for changes
    public signal T? view_add(MetaDocument mdoc, bool visible, Icon vm = Icon.DOCUMENT);
    public signal void view_remove(MetaDocument mdoc, T data);
    public signal void view_update(MetaDocument mdoc, T data);
    public signal void view_visibility(MetaDocument mdoc, T data, bool visible, Icon vm = Icon.DOCUMENT);
}

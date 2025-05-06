class Center {
    private string root_path;
    private MetaDocument[] all_mdocs;

    public Center(string root_path) {
        this.root_path = root_path;
        this.all_mdocs = {};
    }

    public async void ready() throws Error {
        this.scan_begin();
        Scanner s = new Scanner();

        s.found_document.connect((mdoc) => {
            this.cud_add(mdoc);
            this.all_mdocs += mdoc;
            this.scan_step();
        });
        s.found_directory.connect((path) => {
            // this.file_tree_add(path);
        });
        // this.file_tree_clear();
        yield s.scan(this.root_path);
        this.scan_done();
    }

    public void save_document(MetaDocument mdoc, string new_content) {
        try {
            mdoc.save_file(new_content);
        } catch (Error err) {
            stderr.printf("Error saving file '%s': %s\n", mdoc.zknid, err.message);
            this.set_fatal(err);
        }
    }

    public Document? select_file(MetaDocument mdoc) {
        try {
            Document doc = mdoc.reload_file();

            this.body_set_file(mdoc, doc);
            return doc;
        } catch (Error err) {
            stderr.printf("Error loading file '%s': %s\n", mdoc.path, err.message);
            this.set_fatal(err);
            return null;
        }
    }

    public unowned MetaDocument[] get_all_metadocs() {
        return this.all_mdocs;
    }

    public MetaDocument? find_document_by_zknid(string zknid) {
        foreach (MetaDocument mdoc in this.all_mdocs) {
            if (mdoc.zknid == zknid) {
                return mdoc;
            }
        }

        return null;
    }

    public MetaDocument new_document() {
        DateTime dt = new DateTime.now_local();
        string zknid = dt.format("%Y%m%d%H%M%S");

        MetaFields mf = { };
        mf.path = @"$(this.root_path)/$(zknid).md";
        mf.title = "";
        mf.zknid = zknid;
        mf.unix_modified = dt.to_unix();
        MetaDocument mdoc = new MetaDocument(mf);
        try {
            mdoc.save_file("");
        } catch (Error err) {
            assert_not_reached();
        }

        this.all_mdocs += mdoc;

        this.cud_add(mdoc);
        return mdoc;
    }

    // public signal void file_tree_clear();
    // public signal void file_tree_add(MetaDocument mdoc);
    public signal void body_set_file(MetaDocument mdoc, Document doc);
    public signal void set_fatal(Error err);

    // Create Update, Delete of files
    public signal void cud_add(MetaDocument mdoc);
    public signal void cud_remove(MetaDocument mdoc);
    public signal void cud_update(MetaDocument mdoc);

    public signal void scan_begin();
    public signal void scan_step();
    public signal void scan_done();
}

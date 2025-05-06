using GLib;

private int64 current_unix_time() {
    var d = new DateTime.now_utc();
    return d.to_unix();
}

struct MetaFields {
    public string path;
    public string title;
    public string zknid;
    public string[] tags;
    public string[] links;
    public int64 unix_modified;

    public bool equal(ref MetaFields other) {
        if (this.tags.length != other.tags.length) {
            return false;
        }

        for (uint i=0; i<this.tags.length; i++) {
            if (this.tags[i] != other.tags[i]) {
                return false;
            }
        }

        return
            this.path == other.path &&
            this.title == other.title &&
            this.zknid == other.zknid &&
            this.unix_modified == other.unix_modified;
    }
}

class MetaDocument : Object {
    private MetaFields fields;

    public MetaDocument(MetaFields fields) {
        this.fields = fields;
    }

    public string path { get { return this.fields.path; } }
    public string title { get { return this.fields.title; } }
    public string zknid { get { return this.fields.zknid; } }
    public string[] tags { get { return this.fields.tags; } }
    public string[] links { get { return this.fields.links; } }
    public int64 unix_modified { get { return this.fields.unix_modified; } }

    private void reload(Document doc) {
        if (!this.fields.equal(ref doc.metafields)) {
            this.fields = doc.metafields;
            this.updated();
        }
    }

    public Document reload_string(string content) {
        Document doc = new Document.from_string(
            content,
            this.fields.path,
            current_unix_time()
        );
        reload(doc);
        return doc;
    }

    public Document reload_file() throws Error {
        Document doc = new Document.from_file(this.path);

        reload(doc);
        return doc;
    }

    public void save_file(string content) throws Error {
        write_file(this.fields.path, content);
        reload_string(content);
    }

    public bool equals(MetaDocument other) {
        return other.fields.path == this.fields.path;
    }

    public signal void updated();
}

private string load_file(string path) throws Error {
    var file = File.new_for_path(path);
    GLib.FileIOStream stream = file.open_readwrite();
    var input = stream.get_input_stream();

    uint8[] data = new uint8[4000];
    var ba = new ByteArray();
    while (true) {
        size_t read_size = input.read(data);
        if (read_size == 0) {
            break;
        }

        unowned uint8[] add_slice = data[0:read_size];
        ba.append(add_slice);
    }

    uint8[] terminator = { 0 };
    ba.append(terminator);
    return (string) ba.data;
}

private void write_file(string path, string content) throws Error {
    var file = File.new_for_path(path);
    if (file.query_exists()) {
        file.delete();
    }

    FileIOStream stream = file.create_readwrite(FileCreateFlags.REPLACE_DESTINATION);
    OutputStream output = stream.get_output_stream();
    output.write(content.data);
}

private FrontMatter? scan_frontmatter(string text) {
    if (text.length > 3) {
        var frontmatter_slice = text[0:3];
        if (frontmatter_slice == "---") {
            return new FrontMatter(text);
        }
    }
    return null;
}

private string extract_file_zknid(string path) {
    string basename = Path.get_basename(path);
    var cut_point = basename.index_of(".");

    if (cut_point > 0) {
        return basename[0:cut_point];
    } else {
        return basename;
    }
}

class Document : Object {
    public MetaFields metafields;
    public string content;

    public Document.from_string(
        string text,
        string file_source,
        int64 unix_modified
    ) {
        this.content = text;

        string? zknid = extract_file_zknid(file_source);

        FrontMatter fm = new FrontMatter(text);
        string? title = fm.title;
        string[] tags = fm.tags;
        string[] links = fm.links;

        if (title == null) {
            title = zknid;
        }

        assert_nonnull(title);
        assert_nonnull(zknid);

        this.metafields.path = file_source;
        this.metafields.title = title;
        this.metafields.zknid = zknid;
        this.metafields.tags = tags;
        this.metafields.links = links;
        this.metafields.unix_modified = unix_modified;
    }

    public Document.from_file(string path, FileInfo? fi = null) throws Error {
        DateTime? modified_date = null;
        if (fi != null) {
            modified_date = fi.get_modification_date_time();
        } else {
            var file = File.new_for_path(path);
            var fi_new = file.query_info(FileAttribute.TIME_MODIFIED, 0);
            modified_date = fi_new.get_modification_date_time();
        }

        assert_nonnull(modified_date);

        string file_content = load_file(path);
        this.from_string(file_content, path, modified_date.to_unix());
    }
}

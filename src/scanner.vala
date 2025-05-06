using GLib;

private bool is_hidden_dir(string dir_name) {
    return dir_name[0] == '.';
}

class Scanner {
    private async void process_file_info(File dir_name, FileInfo fi) throws Error {
        string name = fi.get_name();
        string path = @"$(dir_name.get_path())/$name";
        switch (fi.get_file_type()) {
            case FileType.DIRECTORY :
                this.found_directory(fi.get_name());
                if (!is_hidden_dir(fi.get_name())) {
                    yield this.process_dir(File.new_for_path(path));
                }
                break;
            case FileType.REGULAR :
                yield this.process_file(path, fi);
                break;

            default :
                // Skip unknown file type
                break;
        }
    }

    private async void process_file(string path, FileInfo fi) throws Error {

        if (path.length < 4) {
            // Can't check markdown extension
            return;
        }

        string ext = path[path.length-3:path.length];
        if (ext != ".md") {
            // Incorrect extension
            return;
        }

        Document doc = new Document.from_file(path, fi);
        MetaDocument mdoc = new MetaDocument(doc.metafields);
        this.found_document(mdoc);
    }

    private async void process_dir(File dir) throws Error {
        var e = yield dir.enumerate_children_async(
            "standard::name,time::modified",
            0,
            Priority.DEFAULT
        );

        while (true) {
            var files = yield e.next_files_async(50, Priority.DEFAULT);

            if (files == null) {
                break;
            }

            foreach (var fi in files) {
                yield this.process_file_info(dir, fi);
            }
        }
    }

    public async void scan(string path) throws Error {
        yield this.process_dir(File.new_for_path(path));
    }

    public signal void found_directory(string dir);
    public signal void found_document(MetaDocument mdoc);
}

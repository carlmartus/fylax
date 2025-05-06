const string KF_FILE_NAME = "fylax.config";

public struct ConfigFields {
    public string base_dir;

    public void keyfile_store(KeyFile kf) {
        // Set default
        kf.set_string("default", "base_dir", this.base_dir);
    }

    public void keyfile_load(KeyFile kf) throws Error {
        this.base_dir = kf.get_string("default", "base_dir");
    }
}

private KeyFile ensure_config(out string config_path) throws Error {
        string cfg_dir = Path.build_filename(
            Environment.get_user_config_dir(),
            "fylax"
        );

        string file_path = Path.build_filename(cfg_dir, KF_FILE_NAME);
        config_path = file_path;

        if (!FileUtils.test(file_path, FileTest.EXISTS)) {
            DirUtils.create_with_parents(cfg_dir, 0755);

            var default_root_path = Environment.get_user_special_dir(UserDirectory.DOCUMENTS);

            ConfigFields cf_default = {
                default_root_path,
            };
            KeyFile kf_default = new KeyFile();
            cf_default.keyfile_store(kf_default);

            assert_true(kf_default.save_to_file(file_path));
            return kf_default;
        } else {
            var key_file = new KeyFile();
            key_file.load_from_file(file_path, KeyFileFlags.NONE);
            return key_file;
        }
}

public class ConfigFile {

    public ConfigFields fields;

    public ConfigFile.from_user() throws Error {

        string config_path;
        var key_file = ensure_config(out config_path);
        fields.keyfile_load(key_file);
    }

    public ConfigFile.from_fields(ConfigFields fields) {
        this.fields = fields;
    }

    public void save() throws Error {
        string config_file;
        var key_file = ensure_config(out config_file);
        this.fields.keyfile_store(key_file);
        key_file.save_to_file(config_file);
    }
}

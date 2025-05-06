#include "tree_sitter.h"
#include <tree_sitter/api.h>
#include <assert.h>
#include <string.h>

extern const TSLanguage *tree_sitter_markdown(void);
extern const TSLanguage *tree_sitter_markdown_inline(void);
extern const TSLanguage *tree_sitter_yaml(void);
TSParser *md_parser;
TSParser *md_inline_parser;
TSParser *yaml_parser;
TSQuery *query_md_frontmatter;
TSQuery *query_md_inline_frontmatter;
TSQuery *query_yaml_frontmatter;

void fylax_ts_init() {
    // Markdown
    md_parser = ts_parser_new();
    const TSLanguage *md_lang = tree_sitter_markdown();
    ts_parser_set_language(md_parser, md_lang);

    // Markdown inline
    md_inline_parser = ts_parser_new();
    const TSLanguage *md_inline_lang = tree_sitter_markdown_inline();
    ts_parser_set_language(md_inline_parser, md_inline_lang);

    // Yaml
    yaml_parser = ts_parser_new();
    const TSLanguage *yaml_lang = tree_sitter_yaml();
    ts_parser_set_language(yaml_parser, yaml_lang);

    uint32_t error_offset;
    TSQueryError error_type;

    const char *src_md_frontmatter =
        "(document (minus_metadata) @meta_data)"
        "\n"
        "(atx_heading (atx_h1_marker) (inline) @h1)"
        "\n"
        "(setext_heading heading_content: (paragraph (inline) @h1_underscore) (setext_h1_underline))"
        ;

    query_md_frontmatter = ts_query_new(md_lang, src_md_frontmatter, strlen(src_md_frontmatter), &error_offset, &error_type);
    assert(error_type == TSQueryErrorNone);

    const char *src_md_inline_frontmatter =
        "(strong_emphasis (emphasis_delimiter) (emphasis_delimiter) (emphasis_delimiter) (emphasis_delimiter)) @value"
        "\n"
        "(emphasis (emphasis_delimiter) (emphasis_delimiter)) @value"
        "\n"
        "(shortcut_link (link_text) @arg0) @value"
        "\n"
        "(inline_link (link_text) @arg0 (link_destination) @arg1) @value"
        "\n"
        "(uri_autolink) @value"
        "\n"
        "(code_span (code_span_delimiter) (code_span_delimiter)) @value"
        "\n"
        "(strikethrough (emphasis_delimiter) (strikethrough (emphasis_delimiter) (emphasis_delimiter)) (emphasis_delimiter)) @value"
        ;

    query_md_inline_frontmatter = ts_query_new(md_inline_lang, src_md_inline_frontmatter, strlen(src_md_inline_frontmatter), &error_offset, &error_type);
    assert(error_type == TSQueryErrorNone);

    const char *src_yaml_frontmatter =
        "(block_mapping_pair key: (flow_node (plain_scalar) @key) value: (flow_node [(plain_scalar (string_scalar)) (double_quote_scalar) (single_quote_scalar)] @value) (#eq? @key \"title\"))"
        "\n"
        "(block_mapping_pair key: (flow_node (plain_scalar) @key) value: (flow_node (flow_sequence (flow_node (_) @value))) (#eq? @key \"tags\"))"
        "\n"
        "(block_mapping_pair key: (flow_node (plain_scalar) @key) value: (block_node (block_sequence (block_sequence_item (flow_node (_) @value)))) (#eq? @key \"tags\"))"
        ;

    query_yaml_frontmatter = ts_query_new(yaml_lang, src_yaml_frontmatter, strlen(src_yaml_frontmatter), &error_offset, &error_type);
    assert(error_type == TSQueryErrorNone);
}

void fylax_ts_deinit() {
    ts_query_delete(query_md_frontmatter);
    ts_query_delete(query_md_inline_frontmatter);
    ts_parser_delete(md_parser);
    ts_parser_delete(md_inline_parser);
    ts_parser_delete(yaml_parser);
    md_parser = NULL;
    yaml_parser = NULL;
}


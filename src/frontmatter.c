#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <tree_sitter/api.h>
#include "tree_sitter.h"

typedef void (*emit_info)(uint32_t type, uint32_t a0, uint32_t a1, void *user_pointer);

enum {
    FM_NONE = 0,
    FM_TITLE,
    FM_H1,
    FM_TAG,
    FM_LINK,
} info_type;

static void emit_quoted(uint32_t type, const char *str, TSNode value, emit_info emit, void *user_pointer) {
    uint32_t a0 = ts_node_start_byte(value);
    uint32_t a1 = ts_node_end_byte(value);

    if (str[a0] == '"' && str[a1-1] == '"') {
        a0++;
        a1--;
    }

    if (str[a0] == '\'' && str[a1-1] == '\'') {
        a0++;
        a1--;
    }

    emit(type, a0, a1, user_pointer);
}

static bool node_cmp(const char *str, TSNode n, const char *expected) {
    return memcmp(str + ts_node_start_byte(n), expected, strlen(expected)) == 0;
}

static void front_matter_yaml_scan(const char *str, size_t str_len, emit_info emit, void *user_pointer) {
    TSTree *tree = ts_parser_parse_string(yaml_parser, NULL, str, str_len);
    TSNode document = ts_tree_root_node(tree);

    TSQueryCursor *cur = ts_query_cursor_new();
    ts_query_cursor_exec(cur, query_yaml_frontmatter, document);

    TSQueryMatch match;
    while (ts_query_cursor_next_match(cur, &match)) {
        switch (match.pattern_index) {
            case 0 :
                if (node_cmp(str, match.captures[0].node, "title")) {
                    emit_quoted(FM_TITLE, str, match.captures[1].node, emit, user_pointer);
                }
                break;

            case 1 :
            case 2 :
                if (node_cmp(str, match.captures[0].node, "tags")) {
                    emit_quoted(FM_TAG, str, match.captures[1].node, emit, user_pointer);
                }
                break;
        }
    }

    ts_query_cursor_delete(cur);
    ts_tree_delete(tree);
}

static void scan_markdown(const char *str, uint32_t *fm_start, emit_info emit, void *user_pointer) {
    TSTree *tree = ts_parser_parse_string(md_parser, NULL, str, strlen(str));
    TSNode root_node = ts_tree_root_node(tree);

    if (ts_node_is_null(root_node) || strcmp(ts_node_type(root_node), "document") != 0) {
        return;
    }

    TSQueryCursor *cur = ts_query_cursor_new();
    ts_query_cursor_exec(cur, query_md_frontmatter, root_node);

    TSQueryMatch match;
    while (ts_query_cursor_next_match(cur, &match)) {
        TSNode n;
        uint32_t n0, n1;
        switch (match.pattern_index) {
            case 0 : // Frontmatter
                n = match.captures[0].node;
                n0 = ts_node_start_byte(n);
                n1 = ts_node_end_byte(n);
                *fm_start = n1+1;
                // String length
                front_matter_yaml_scan(str + n0, n1 - n0, emit, user_pointer);
                break;

            case 1 :
            case 2 :
                n = match.captures[0].node;
                emit(FM_TITLE, ts_node_start_byte(n), ts_node_end_byte(n), user_pointer);
                break;
        }
    }

    ts_query_cursor_delete(cur);
    ts_tree_delete(tree);
}

static void scan_markdown_inline(const char *str, uint32_t fm_start, emit_info emit, void *user_pointer) {
    uint32_t str_len = strlen(str);
    const char *ignore_fm_str = str + fm_start;
    TSTree *tree = ts_parser_parse_string(md_inline_parser, NULL, ignore_fm_str, strlen(ignore_fm_str));
    TSNode root_node = ts_tree_root_node(tree);

    TSQueryCursor *cur = ts_query_cursor_new();
    ts_query_cursor_exec(cur, query_md_inline_frontmatter, root_node);

    TSQueryMatch match;
    while (ts_query_cursor_next_match(cur, &match)) {
        TSNode n = match.captures[0].node;
        uint32_t n0, n1;

        if (match.pattern_index == 2) {
            n0 = ts_node_start_byte(n) + fm_start;
            n1 = ts_node_end_byte(n) + fm_start;

            if (
                    n0 > 0 && n1+1 < str_len &&
                    str[n0-1] == '[' && str[n0] == '[' &&
                    str[n1-1] == ']' && str[n1] == ']'
                    ) {
                emit(FM_LINK, n0+1, n1-1, user_pointer);
            }
        }
    }

    ts_query_cursor_delete(cur);
    ts_tree_delete(tree);
}

void front_matter_extern_scan(const char *str, emit_info emit, void *user_pointer) {
    uint32_t fm_start = 0;
    scan_markdown(str, &fm_start, emit, user_pointer);
    scan_markdown_inline(str, fm_start, emit, user_pointer);
}


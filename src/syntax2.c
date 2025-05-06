#include <stdint.h>
#include <string.h>
#include <tree_sitter/api.h>

#include "tree_sitter.h"

typedef void (*emit_syntax)(
        const char *local_str, uint32_t type,
        uint32_t a0, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5,
        void *user_pointer);

enum {
    SX_STRING_LENGTH = 0,
    SX_BOLD,
    SX_ITALIC,
    SX_SHORTCUT,
    SX_LINK,
    SX_AUTOLINK,
    SX_CODE_SPAN,
    SX_STRIKETHROUGH,
} sx_type;

struct syntax_ctx {
    void *user_pointer;
    emit_syntax emit_syntax;
    const char *string;
};

void fylax_ts_scan_syntax(const char *str, emit_syntax emit_syntax, void *user_pointer) {
    uint32_t str_len = strlen(str);
    TSTree *tree = ts_parser_parse_string(md_inline_parser, NULL, str, str_len);
    TSNode root_node = ts_tree_root_node(tree);

    emit_syntax(str, SX_STRING_LENGTH, str_len, 0, 0, 0, 0, 0, user_pointer);

    if (ts_node_is_null(root_node)) {
        return;
    }

    TSQueryCursor *cur = ts_query_cursor_new();
    ts_query_cursor_exec(cur, query_md_inline_frontmatter, root_node);

    TSQueryMatch match;
    TSNode n, arg_a, arg_b;
    uint32_t n0, n1, arg_a0, arg_a1, arg_b0, arg_b1;
    while (ts_query_cursor_next_match(cur, &match)) {
        n = match.captures[0].node;
        n0 = ts_node_start_byte(n);
        n1 = ts_node_end_byte(n);

        switch (match.pattern_index) {
            case 0 :
                emit_syntax(str, SX_BOLD, n0, n1, 0, 0, 0, 0, user_pointer);
                break;

            case 1 :
                emit_syntax(str, SX_ITALIC, n0, n1, 0, 0, 0, 0, user_pointer);
                break;

            case 2 :
                emit_syntax(str, SX_SHORTCUT, n0, n1, 0, 0, 0, 0, user_pointer);
                break;

            case 3 :
                arg_a = match.captures[1].node;
                arg_b = match.captures[2].node;
                arg_a0 = ts_node_start_byte(arg_a);
                arg_a1 = ts_node_end_byte(arg_a);
                arg_b0 = ts_node_start_byte(arg_b);
                arg_b1 = ts_node_end_byte(arg_b);
                emit_syntax(str, SX_LINK,
                        n0, n1,
                        arg_a0, arg_a1,
                        arg_b0, arg_b1,
                        user_pointer);
                break;

            case 4 :
                emit_syntax(str, SX_AUTOLINK, n0, n1, 0, 0, 0, 0, user_pointer);
                break;

            case 5 :
                emit_syntax(str, SX_CODE_SPAN, n0, n1, 0, 0, 0, 0, user_pointer);
                break;

            case 6 :
                emit_syntax(str, SX_STRIKETHROUGH, n0, n1, 0, 0, 0, 0, user_pointer);
                break;
        }
    }

    ts_query_cursor_delete(cur);
    ts_tree_delete(tree);
}

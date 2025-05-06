#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <tree_sitter/api.h>
#include "tree_sitter.h"

enum md_type {
    MT_HEADER = 0,
    MT_COUNT,
};

typedef void (*emit_scan)(uint32_t element_id, uint32_t i0, uint32_t i1, void *user_pointer);

struct scan_ctx {
    void *user_pointer;
    emit_scan es;
};

// static const char *str2md_type[] = {
//     [MT_HEADER] = "atx_heading",
// };

static void found_heading(TSNode node, const struct scan_ctx *ctx) {
    TSNode title = ts_node_named_child(node, 1);
    ctx->es(MT_HEADER, ts_node_start_byte(title), ts_node_end_byte(title), ctx->user_pointer);
}

static struct {
    enum md_type type;
    const char *ts_type;
    void (*func)(TSNode, const struct scan_ctx*);
} str2found_syntax[] = {
     { MT_HEADER, "atx_heading", found_heading },
     { MT_HEADER, "setext_heading", found_heading },
};

#define STR2FOUND_COUNT (sizeof(str2found_syntax) / sizeof(str2found_syntax[0]))

static void recurse_syntax(TSNode node, const struct scan_ctx *ctx) {
    for (uint_fast8_t i=0; i<STR2FOUND_COUNT; i++) {
        if (strncmp(ts_node_type(node), str2found_syntax[i].ts_type, 40) == 0) {
            return str2found_syntax[i].func(node, ctx);
        }
    }

    uint32_t child_count = ts_node_child_count(node);
    for (uint32_t i=0; i<child_count; i++) {
        TSNode child = ts_node_child(node, i);
        recurse_syntax(child, ctx);
    }
}

void fylax_ts_tmp_scan(const char *str, emit_scan es, void *user_pointer) {
    struct scan_ctx ctx = {
        .user_pointer = user_pointer,
        .es = es,
    };

    TSTree *tree = ts_parser_parse_string(md_parser, NULL, str, strlen(str));
    TSNode root_node = ts_tree_root_node(tree);
    recurse_syntax(root_node, &ctx);

    ts_tree_delete(tree);
}

enum cell_type {
    CT_NONE = 0,
    CT_HEADING,
    CT_PARAGRPH,
    CT_METADATA,
    CT_LIST_ITEM,
    CT_COUNT,
};

// typedef void (*emit_cell)(const char *local_str, uint32_t type, uint32_t *args, void *user_pointer);
typedef void (*emit_cell)(
        const char *local_str, uint32_t type,
        uint32_t a0, uint32_t a1, uint32_t a2, void *user_pointer);

struct cells_ctx {
    void *user_pointer;
    emit_cell emit_cell;
    enum cell_type prev_type;
    uint32_t prev_start_byte;
    const char *string;
};

static void cell_flush_and_set(struct cells_ctx *ctx, enum cell_type ct, uint32_t sb) {
    if (ctx->prev_type != CT_NONE) {
        // uint32_t args[] = { ctx->prev_start_byte, sb };
        ctx->emit_cell(ctx->string, CT_PARAGRPH, ctx->prev_start_byte, sb+1, 0, ctx->user_pointer);
    }

    ctx->prev_type = ct;
    ctx->prev_start_byte = sb;
}

static uint32_t heading_node_to_level(const char *node_type) {
    if (strncmp(node_type, "atx_h1_marker", 18) == 0) {
        return 1;
    } else if (strncmp(node_type, "atx_h2_marker", 18) == 0) {
        return 2;
    } else if (strncmp(node_type, "atx_h3_marker", 18) == 0) {
        return 3;
    } else if (strncmp(node_type, "atx_h4_marker", 18) == 0) {
        return 4;
    } else if (strncmp(node_type, "atx_h5_marker", 18) == 0) {
        return 5;
    } else if (strncmp(node_type, "atx_h6_marker", 18) == 0) {
        return 6;
    } else if (strncmp(node_type, "atx_h7_marker", 18) == 0) {
        return 7;
    } else {
        return 7;
    }
}

static void cell_heading(TSNode node, struct cells_ctx *ctx) {
    cell_flush_and_set(ctx, CT_NONE, ts_node_start_byte(node));

    TSNode node_level = ts_node_child(node, 0);
    TSNode node_content = ts_node_child(node, 1);
    uint32_t sb = ts_node_start_byte(node_content);
    uint32_t eb = ts_node_end_byte(node_content);
    uint32_t level = heading_node_to_level(ts_node_type(node_level));
    ctx->emit_cell(ctx->string, CT_HEADING, sb, eb, level, ctx->user_pointer);
}

static void cell_paragraph(TSNode node, struct cells_ctx *ctx) {
    cell_flush_and_set(ctx, CT_PARAGRPH, ts_node_start_byte(node));
}

static void cell_metadata(TSNode node, struct cells_ctx *ctx) {
    cell_flush_and_set(ctx, CT_NONE, ts_node_start_byte(node));

    uint32_t sb = ts_node_start_byte(node);
    uint32_t eb = ts_node_end_byte(node) - 1;
    ctx->emit_cell(ctx->string, CT_METADATA, sb, eb, 2, ctx->user_pointer);

    cell_flush_and_set(ctx, CT_NONE, ts_node_end_byte(node));
}

static void cell_list_item(TSNode node, struct cells_ctx *ctx) {
    cell_flush_and_set(ctx, CT_NONE, ts_node_start_byte(node));

    uint32_t check_start_byte = 0;

    // Find first "paragraph" node
    for (int i=0; i<ts_node_child_count(node); i++) {
        TSNode n = ts_node_named_child(node, i);
        if (strncmp(ts_node_type(n), "paragraph", 9) == 0) {
            uint32_t sb = ts_node_start_byte(n);
            uint32_t eb = ts_node_end_byte(n);

            ctx->emit_cell(ctx->string, CT_LIST_ITEM, sb, eb, check_start_byte, ctx->user_pointer);
            break;
        } else if (strncmp(ts_node_type(n), "task_list_marker_unchecked", 28) == 0) {
            check_start_byte = ts_node_start_byte(n) + 1;
        } else if (strncmp(ts_node_type(n), "task_list_marker_checked", 26) == 0) {
            check_start_byte = ts_node_start_byte(n) + 1;
        }
    }

    ctx->prev_start_byte = ts_node_end_byte(node);
    ctx->prev_type = CT_NONE;
}

static struct {
    const char *ts_type;
    void (*func)(TSNode, struct cells_ctx*);
} str2found_cells[] = {
     { "atx_heading", cell_heading },
     { "setext_heading", cell_heading },
     { "paragraph", cell_paragraph },
     { "minus_metadata", cell_metadata },
     { "list_item", cell_list_item },
};

#define STR2FOUND_CELLS_COUNT (sizeof(str2found_cells) / sizeof(str2found_cells[0]))

static void recurse_cells(TSNode node, struct cells_ctx *ctx) {
    const char *node_desc = ts_node_type(node);
    for (uint_fast8_t i=0; i<STR2FOUND_CELLS_COUNT; i++) {
        if (strncmp(node_desc, str2found_cells[i].ts_type, 40) == 0) {
            return str2found_cells[i].func(node, ctx);
        }
    }

    uint32_t child_count = ts_node_child_count(node);
    for (uint32_t i=0; i<child_count; i++) {
        TSNode child = ts_node_child(node, i);
        recurse_cells(child, ctx);
    }
}

void fylax_ts_scan_cells(const char *str, emit_cell emit_cell, void *user_pointer) {
    struct cells_ctx ctx = {
        .user_pointer = user_pointer,
        .emit_cell = emit_cell,
        .prev_type = CT_NONE,
        .prev_start_byte = 0,
        .string = str,
    };

    TSTree *tree = ts_parser_parse_string(md_parser, NULL, str, strlen(str));
    TSNode root_node = ts_tree_root_node(tree);
    recurse_cells(root_node, &ctx);
    cell_flush_and_set(&ctx, CT_NONE, strlen(ctx.string));
}


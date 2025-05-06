#pragma once
#include <tree_sitter/api.h>

extern TSParser *md_parser;
extern TSParser *md_inline_parser;
extern TSParser *yaml_parser;
extern TSQuery *query_md_frontmatter;
extern TSQuery *query_md_inline_frontmatter;
extern TSQuery *query_yaml_frontmatter;


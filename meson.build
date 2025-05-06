project('fylax', 'vala', 'c', 'cpp', version: '0.1.0')

subdir('resources')

vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

cc = meson.get_compiler('c')
lib_ts = cc.find_library('tree-sitter')

executable(
  meson.project_name(),
  'src/fylax.vala',
  'src/app_win.vala',
  'src/syntax2.c',
  'src/syntax2.vala',
  'src/center.vala',
  'src/scanner.vala',
  'src/document.vala',
  'src/history.vala',
  'src/frontmatter.vala',
  'src/frontmatter.c',
  'src/query_view.vala',
  'src/find.vala',
  'src/read.vala',
  'src/tree_sitter.c',
  'src/cells.c',
  'src/cells.vala',
  'src/config_file.vala',
  'src/settings.vala',
  'src/widget_loading.vala',
  'src/tree-sitter-markdown/parser.c',
  'src/tree-sitter-markdown/scanner.c',
  'src/tree-sitter-markdown-inline/parser.c',
  'src/tree-sitter-markdown-inline/scanner.c',
  'src/tree-sitter-yaml/parser.c',
  'src/tree-sitter-yaml/scanner.c',
  gresources,
  dependencies: [
    dependency('gtk+-3.0'),
    dependency('glib-2.0'),
    dependency('gio-2.0'),
    lib_ts,
    ],
  )


# 📓 Fylax
A fast desktop [Zettelkasten](https://en.wikipedia.org/wiki/Zettelkasten) editor build for local use with a minimal GTK UI. Written in [Vala](https://vala.dev/) to align with the [Gnome and GTK](https://apps.gnome.org/sv/#core) application ecosystem.

This project is under development and quality of usage may vary. Fylax is largly inspired by [Zettlr](https://github.com/Zettlr/Zettlr) and comes from the need of having a faster *Zettelkasten* tool for managing large collections of notes.

## Features
The application UI consists of a central view for the loaded document and a side bar to the left of all available files and links to and from the current document.

The central view can be either in read mode or edit mode.

When the main pane is in view mode, the document can be navigated with bindings akin to *Vim*: `j` and `k` for navigation up and down.
Press `e` to go over to the edit mode.

To the lift there are two lists, the *file view* and the *links view*.
Press to load documents in the file view.
When a document is loaded, use the link view to open documents that have any type of link to / from the loaded document according to the methods of Zettelkasten.

The create a link to a different document. In the editor type `[[` to bring up a *find document* dialog.

## Build
Requires Vala, [meson](https://mesonbuild.com), GTK3 and [Tree-sitter](https://tree-sitter.github.io/tree-sitter/).

In [Debian](https://www.debian.org/) install dependencies with:

```bash
apt install libvala-0.56-dev valac meson libgtk-3-dev libtree-sitter-dev cmake
```

Create a Meson build directory and build the project:

```bash
meson setup build
cd build
ninja
```

Now you may run the Fylax executable:

```bash
./fylax
```

## Roadmap
- Display pictures.
- Undo+redo.
- *i18n*.
- Build and distribute a [Flatpak](https://flatpak.org/).
- Insert Emoji shortcut.

Many of these features comes "for free" by upgrading to GTK4.

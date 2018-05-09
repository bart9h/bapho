BaPhO (bart9h's photo organizer)
================================

http://github.com/bart9h/bapho


Why
---

Keeping your photos is a very long term business.
You don't want to invest time to organize your photos
just to have the software you relied on to stop working,
(you moved to a different system where it is not available,
it stopped being maintained or supported, etc).

I tried some photo managers, but I was always wary of
committing to a specific software. Of course, if I choose
an open source software, I could code a export/import
tool if I decide to switch to another one.
But I also didn't want to commit to a specific layout
for the folders, or a database for the metadata.
What I really want, and fell it's the Right Thing To Do,
it's to just use the filesystem.
None of the available photo managers did that (by the end of 2008),
so I decided to create my own.


Features
--------

- You can rename or rearrange the folders or photos
  any way you like, because:

- Everything is in the file system:
  - All metadata (rating, tags, etc) is kept in
    a simple text file alongside the image files.
  - Unixy extensibility: easy to do complex operations
    using your file manager or command line tools.
  - Don't rely on databases:
    the data will still be useful even without BaPhO.

- Simple on-screen-display, keyboard driven interface.
  - [planned, currently only uses wheel to navigate: Mouse works too.]

- Handles multiple files of the same photo.
  - [planned: Pick which version to display.]
    (currently it uses the most recently modified).

- Import tool automatically copy (or move) photos to
  a folder structure based on EXIF date/time.

- Use external tools for editing (Darktable, UFRaw, GIMP).

- Handles video too (uses mpv or MPlayer to play,
  and extract a frame for thumbnail).

- Use tags, names, places, stars (rating).
  - Key to repeat last tag edit (tags added, removed) to current photo.
  - Easily apply multiple tags to multiple photos.
  - [planned: Tags for folders.
    Works like implicit tags for the photos inside.]

- Multiple views (tab-like)
  - Built-in view editor.
  - Filter by rating and tags.
  - Persist views between sessions.

- Use system memory to cache pictures on memory
  for super fast viewing.
  - [planned: Read-ahead in background.]

- Keys to advance to next/prev day/month/year.

- Thumbnail view.

- [planned: Folder view.]

- Display EXIF info.

- Print files from selected photos to stdout,
  to facilitate integration with other tools.

(check the [TODO file](TODO.md) for known bugs and more planned features)


Installation
------------

- Check the system requirements bellow.

- Download [zip](https://github.com/bart9h/bapho/archive/master.zip)
  or use `git clone https://github.com/bart9h/bapho.git`.

- Copy baphorc.example to ~/.baphorc and edit it.

- You can symlink the `bapho` executable to somewhere in your path.


Usage
-----

Arrow keys (or k/j) to move between pictures, +/- to zoom (for thumbnail mode).

For the complete keybinding list, please refer to src/main.pm (search for "keybindings").

| key | action                  |
|:---:|-------------------------|
|  q  | quit                    |
| f11 | toggle fullscreen       |
|  i  | toggle info display     |
|  e  | toggle exif display     |
|  ve | edit view (filters)     |
|  vc | create new view         |
|  vd | delete current view     |
| tab | switch to next view     |
| d/D | skip to next/prev day   |
| m/M | skip to next/prev month |
| y/Y | skip to next/prev year  |
|  t  | tag editor              |
|  .  | repeat last tag edit    |
| s/S | add/remove star         |
| s/S | add/remove star         |
|enter| play video              |
|  fr | mark folder as reviewd  |
|  f0 | reset folder review     |


System requirements
-------------------

- Perl 5.10

- SDL Perl module
  <http://search.cpan.org/~dgoehrig/SDL_Perl-2.1.3/>

- Image::ExifTool Perl module
  <http://search.cpan.org/~exiftool/Image-ExifTool-7.67/>

- fontconfig and other system tools found on
  any Linux system (mkdir, which, cmp, rm, mv, cp, xdpyinfo)


Optional external tools
-----------------------

- Darktable or UFRaw, to develop raw files

- Gimp, to edit other image files

- ImageMagick or GraphicsMagick, to auto-apply sharpening
  when saving .ppm files from UFRaw

- gphoto2, to import files directly from the camera

- any text editor (defined by the EDITOR environment variable)
  to enter new tags

- mpv or MPlayer, to handle video
  https://mpv.io/
  http://mplayerhq.hu/


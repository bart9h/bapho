BaPhO -- the [ba]rt9h's [ph]oto [o]rganizer
===========================================

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
for the folders. What I really want, and fell it's
the Right Thing To Do, it's to just use the filesystem.
None did that, so I decided to create my own.


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
  - [planned, currently only uses wheel to navigate] Mouse works too.

- Handles multiple files of the same photo.
  - [planned] Pick which version to display
    (currently it uses the most recently modified).

- Import tool automatically copy (or move) photos to
  a folder structure based on EXIF date/time.

- Use external tools for editing (UFRaw, GIMP).
  - [planned] Built-in raw developing (using libRAW).

- Handles video too (with MPlayer).

- Use tags, names, places, stars (rating);
  and a view editor to filter those.
  - [planned] Persist views between sessions.

- Easily apply multiple tags to multiple photos.

- Use system memory to cache pictures on memory
  for super fast viewing.
  - [planned] Read-ahead in background.

- Keys to advance to next/prev day/month/year.

- Thumbnail view.

- [planned] Folder view.

- Display EXIF info.

- Print files from selected photos to stdout,
  to facilitate integration with other tools.

(check ./TODO file for known bugs and more planned features)


System requirements
-------------------

- Perl 5.10

- SDL Perl module
  http://search.cpan.org/~dgoehrig/SDL_Perl-2.1.3/

- Image::ExifTool Perl module
  http://search.cpan.org/~exiftool/Image-ExifTool-7.67/

- fontconfig and other system tools found on
  any Linux system (mkdir, which, cmp, rm, mv, cp, xdpyinfo)


Optional external tools
-----------------------

- UFRaw, to develop raw files

- gphoto2, to import files directly from the camera

- any text editor (defined by the EDITOR environment variable) to enter new tags

- MPlayer, to handle video
  http://mplayerhq.hu/


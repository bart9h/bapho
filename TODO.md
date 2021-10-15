Poor man's issue tracker
========================

Bugs
----

- --readonly not fully implemented



Missing features
----------------

- Tag renaming.

- Handle tags for people and places separately.

- Cycle through multiple files of a picture.
  - Option to set selected one.

- Picture size.
  - Choose from three picture sizes: small (15cm), normal (30cm) and large (60cm).

- Zoom in (1 pixel per pixel).
  - Pan.

- Image rotation.

- Text line editing (to enter new tags, renaming files/dirs).

- Documentation (usage, keyboard commands).


Enhancements
------------

- Offline support.

- Export images
  - Select resolution.
  - Upload to photo-hosting web services (PicasaWeb, Flickr, Imgur, etc).
  - Set a picture as wallpaper.

- Folder handling
  - Folder iterator.
  - Toggle between file view and folder view.
  - Folder tagging.

- Slideshow.

- Option to import then run the gui showing only the just-imported pics.

- Mouse support.

- Display image histogram.

- Screensaver.

- OSD transparency.

- When importing, load files first, to check for duplicates
  (ex: in case of a renamed directory).


Optimizations
-------------

- Asynchronous image loading.

- Faster image loading (disk cache).
  - Save jpegs with fullscreen size, and maybe thumbnails too.
  - Load directly from EXIF (in C?).

- Read-ahead image loading.

- Filesystem cache (keep database of pictures).


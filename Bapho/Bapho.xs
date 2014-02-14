#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

MODULE = Bapho		PACKAGE = Bapho

bool
display_init(title, x, y, w, h, isFullscreen)
	const char* title
	int x
	int y
	int w
	int h
	bool isFullscreen

void
display_flush()

int
display_w()

int
display_h()

void
display_image(path, x, y, w, h)
	const char* path
	int x
	int y
	int w
	int h

const char*
get_event()

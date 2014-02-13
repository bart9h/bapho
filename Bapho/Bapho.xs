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

int
display_w()

int
display_h()

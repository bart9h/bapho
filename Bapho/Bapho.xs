#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"


MODULE = Bapho		PACKAGE = Bapho

void
hello()
	CODE:
		printf("Hello, world!\n");

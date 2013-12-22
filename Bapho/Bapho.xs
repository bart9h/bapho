#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

MODULE = Bapho		PACKAGE = Bapho

void
hello()

int
triplo(input)
	int input

void
salute(input)
	const char* input

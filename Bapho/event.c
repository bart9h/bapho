#include <stdio.h>
#include <stdbool.h>
#include <SDL2/SDL.h>
#include <SDL2/SDL_events.h>

extern struct Display g_bapho_data;

const char* get_event()
{
	static char* event_name = NULL;
	if (event_name == NULL)
		event_name = malloc(40);
	event_name[0] = '\0';

	static SDL_Event event;

	SDL_WaitEvent(&event);
	switch(event.type) {
		case SDL_QUIT:
			strcpy(event_name, "quit");
			break;
		case SDL_KEYDOWN:
			if (event.key.keysym.mod & KMOD_CTRL)   strcat(event_name, "control-");
			if (event.key.keysym.mod & KMOD_SHIFT)  strcat(event_name, "shift-");
			strcat(event_name, SDL_GetKeyName(event.key.keysym.sym));
			break;
		case SDL_MOUSEMOTION:
			strcpy(event_name, "move");
			break;
	}

	return event_name;
}

// vim600:foldmethod=syntax:foldnestmax=1:

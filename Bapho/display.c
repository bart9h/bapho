#include <stdio.h>
#include <stdbool.h>
#include <SDL2/SDL.h>
#include <SDL2/SDL_video.h>
#include <SDL2/SDL_image.h>

/* global data */
struct Display
{
	SDL_Window* window;
};
static struct Display g_bapho_display;
#define G g_bapho_display


bool display_init (const char* title,
		int x, int y, int w, int h,
		bool isFullscreen)
{
	/* initialize SDL */
	SDL_Init(SDL_INIT_VIDEO);
	if (SDL_Init(SDL_INIT_VIDEO) != 0) {
		fprintf(stderr, "SDL_Init(): %s\n", SDL_GetError());
		return false;
	}
	atexit(SDL_Quit);

	/* create window */
	Uint32 flags =
		SDL_WINDOW_SHOWN |
		SDL_WINDOW_ALLOW_HIGHDPI |
		(isFullscreen ? SDL_WINDOW_FULLSCREEN_DESKTOP : SDL_WINDOW_RESIZABLE)
	;
	G.window = SDL_CreateWindow(title, x, y, w, h, flags);
	if (G.window == NULL)
		return false;

	return true;
}

void display_flush()
{
	SDL_UpdateWindowSurface(G.window);
}

int display_w()
{
	int w, h;
	SDL_GetWindowSize(G.window, &w, &h);
	return w;
}

int display_h()
{
	int w, h;
	SDL_GetWindowSize(G.window, &w, &h);
	return h;
}

void display_image (const char* path,
		int x, int y, int w, int h)
{
#if 0
	SDL_Surface* original = IMG_Load(path);
	if (original != NULL) {
		SDL_Surface* zoom = zoomSurface(original,
				double(w)/original.w,
				double(h)/original.h,
				SMOOTHING_ON);
		if (zoom != NULL) {
			SDL_Blit
		}
	}
#else
	SDL_Surface* surf = IMG_Load(path);
	if (surf != NULL) {
		SDL_Rect r;  r.x=x;r.y=y;r.w=w;r.h=h;
		SDL_BlitScaled(surf, NULL, SDL_GetWindowSurface(G.window), &r);
		SDL_FreeSurface(surf); //TODO: cache
	}
#endif
}

// vim600:foldmethod=syntax:foldnestmax=1:

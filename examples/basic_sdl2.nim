# This example needs SDL2 to be installed:
# nimble install sdl2

import boxy, opengl, sdl2

let windowSize = ivec2(1280, 800)

discard init(INIT_EVERYTHING)

discard glSetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE)
discard glSetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4)
discard glSetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 1)

let window = createWindow(
  "Basic SDL2",
  100,
  100,
  windowSize.x,
  windowSize.y,
  SDL_WINDOW_OPENGL
)
discard window.glCreateContext()

loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("bg", readImage("examples/data/bg.png"))
bxy.addImage("ring1", readImage("examples/data/ring1.png"))
bxy.addImage("ring2", readImage("examples/data/ring2.png"))
bxy.addImage("ring3", readImage("examples/data/ring3.png"))

var frame: int

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(windowSize)

  # Draw the bg.
  bxy.drawImage("bg", rect = rect(vec2(0, 0), windowSize.vec2))

  # Draw the rings.
  let center = windowSize.vec2 / 2
  bxy.drawImage("ring1", center, angle = frame.float / 100)
  bxy.drawImage("ring2", center, angle = -frame.float / 190)
  bxy.drawImage("ring3", center, angle = frame.float / 170)

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.glSwapWindow()
  inc frame

var runGame = true
while runGame:
  var evt = defaultEvent
  while pollEvent(evt):
    if evt.kind == QuitEvent:
      runGame = false
      break
  display()

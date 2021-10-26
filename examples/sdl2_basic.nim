import sdl2, boxy, chroma, opengl

let windowSize = ivec2(1280, 800)

discard init(INIT_EVERYTHING)

discard glSetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE)
discard glSetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4)
discard glSetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 1)

let window = createWindow(
  "SDL2 + Boxy",
  100,
  100,
  windowSize.x,
  windowSize.y,
  SDL_WINDOW_OPENGL
)

discard window.glCreateContext()

loadExtensions()

echo "GL_VERSION: ", cast[cstring](glGetString(GL_VERSION))
echo "GL_VENDOR: ", cast[cstring](glGetString(GL_VENDOR))
echo "GL_RENDERER: ", cast[cstring](glGetString(GL_RENDERER))
echo "GL_SHADING_LANGUAGE_VERSION: ", cast[cstring](glGetString(GL_SHADING_LANGUAGE_VERSION))

let bxy = newBoxy()

let rhino = readImage("examples/data/rhino.png")
bxy.addImage("rhino", rhino)

var i: int

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(windowSize)
  # Draw the white background.
  bxy.drawRect(rect(vec2(0, 0), windowSize.vec2), chroma.color(1, 1, 1, 1))
  # Draw the rhino.
  bxy.drawImage("rhino", vec2((i mod windowSize.x).float32, 0))
  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.glSwapWindow()
  inc i

var runGame = true
while runGame:
  var evt = defaultEvent
  while pollEvent(evt):
    if evt.kind == QuitEvent:
      runGame = false
      break
  display()

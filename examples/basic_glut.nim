import boxy, opengl, opengl/glut

let windowSize = ivec2(1280, 800)

proc display() {.cdecl.} # Forward declaration

glutInit()
glutInitDisplayMode(GLUT_DOUBLE)
glutInitWindowSize(windowSize.x, windowSize.y)
discard glutCreateWindow("Basic Glut")
glutDisplayFunc(display)
loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("bg", readImage("examples/data/bg.png"))
bxy.addImage("ring1", readImage("examples/data/ring1.png"))
bxy.addImage("ring2", readImage("examples/data/ring2.png"))
bxy.addImage("ring3", readImage("examples/data/ring3.png"))

var frame: int

# Called when it is time to draw a new frame.
proc display() {.cdecl.} =
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
  glutSwapBuffers()
  inc frame

  # Ask glut to draw next frame
  glutPostRedisplay()

glutMainLoop()

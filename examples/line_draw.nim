import boxy, opengl, windy

let window = newWindow("Boxy Blur", ivec2(1280, 800), msaa=msaa8x)
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

var userLine: seq[Vec2]

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Draw the bg.
  bxy.drawLine(
    points = @[
      vec2(500, 500),
      vec2(600, 550),
      vec2(700, 520),
      vec2(800, 500),
      vec2(900, 550),
      vec2(500, 200)
    ],
    tints = @[
      color(1, 0, 0, 0.8),
      color(0, 1, 0, 0.8),
      color(0, 0, 1, 0.8),
      color(1, 1, 0, 0.8),
      color(1, 0, 0, 0.8),
      color(1, 0, 1, 0.8)
    ],
    lineWidth = 150
  )

  if window.buttonPressed[MouseLeft]:
    userLine = @[]
  if window.buttonDown[MouseLeft]:
    if userLine.len == 0 or userLine[^1].dist(window.mousePos.vec2) > 10:
      userLine.add(window.mousePos.vec2)

  glEnable(GL_MULTISAMPLE)

  bxy.drawLine(
    points = userLine,
    tint = color(1, 1, 1, 0.8),
    lineWidth = 10
  )

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()

while not window.closeRequested:
  pollEvents()

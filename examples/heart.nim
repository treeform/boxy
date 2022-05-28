import boxy, opengl, vmath, windy

let window = newWindow("Windy + Boxy", ivec2(1280, 800))
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

var path = parsePath("""
  M 20 60
  A 40 40 90 0 1 100 60
  A 40 40 90 0 1 180 60
  Q 180 120 100 180
  Q 20 120 20 60
  z
""")

var frame: int = 1

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(0, 0, 0, 1))

  bxy.saveTransform()

  let
    w = 200 + frame mod 300
    id = $(frame mod 30)
    image = newImage(w, w)
  image.fill(color(1, 1, 1, 0.1))
  image.fillPath(
    path,
    color(1, 0, 0, 1),
    scale(vec2(2, 2)) *
    translate(vec2(100, 100)) *
    rotate(frame.float32/100) *
    translate(vec2(-100, -100))
  )

  bxy.addImage("heart" & id, image)
  bxy.drawImage("heart" & id, center = window.size.vec2 / 2, angle = 0)

  bxy.restoreTransform()
  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  pollEvents()

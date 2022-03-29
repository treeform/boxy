import boxy, opengl, random, windy

let window = newWindow("Windy + Boxy", ivec2(1280, 800))
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("bg", readImage("examples/data/bg.png"))
bxy.addImage("star1", readImage("examples/data/star1.png"))

var frame: int = 1

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(0, 0, 0, 1))

  bxy.saveTransform()
  bxy.translate(window.size.vec2 / 2)
  bxy.scale(0.1)

  randomize(2022)
  for i in 0 .. 5000:
    let pos = vec2(gauss(), gauss()) * frame.float32 * 10
    bxy.drawImage("star1",
      center = pos,
      angle = rand(0.0 .. PI)
    )

  bxy.restoreTransform()
  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  pollEvents()

import boxy, opengl, windy

let window = newWindow("Blending", ivec2(1280, 800))
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("greece", readImage("examples/data/greece.png"))
bxy.addImage("test", readImage("examples/data/testTexture.png"))

var frame: int

var blendMode = ScreenBlend
echo "Use left or right key to switch blend modes."
window.onButtonPress = proc(button: Button) =
  if button == KeyLeft:
    blendMode = BlendMode(max(blendMode.ord - 1, 0))
    echo "blendMode :", blendMode, " #", blendMode.ord
  if button == KeyRight:
    blendMode = BlendMode(min(blendMode.ord + 1, BlendMode.high.ord))
    echo "blendMode :", blendMode, " #", blendMode.ord

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(0.1, 0.1, 0.1, 1))

  let c2 = color(1, 1, 1, 0.5)

  bxy.pushLayer()

  bxy.saveTransform()
  bxy.translate(window.size.vec2 / 2)
  bxy.scale(1.2 + 0.2 * sin(frame.float32/100))
  bxy.drawImage("greece", center = vec2(0, 0), angle = 0, color(1, 1, 1, 1))
  bxy.restoreTransform()

  bxy.pushLayer()
  bxy.saveTransform()
  bxy.translate(window.size.vec2 / 2)
  bxy.scale(1.8 + 0.2 * cos(frame.float32/100))
  bxy.drawImage("test", center = vec2(0, 0), angle = 0, color(1, 1, 1, 1))
  bxy.restoreTransform()
  bxy.popLayer(blendMode = blendMode)

  bxy.popLayer()

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  pollEvents()

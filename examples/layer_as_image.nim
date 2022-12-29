import boxy, opengl, windy

let window = newWindow("Boxy Blur", ivec2(1280, 800))
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Load the image.
let greeceImage = readImage("examples/data/greece.png")
echo greeceImage.width
echo greeceImage.height

bxy.addImage("greece", greeceImage)


# Draw into an image so that it can be resued.
# Blur operation are potentially costly, save to an atlas already blured
# and draw them much faster.
bxy.beginFrame(window.size)
bxy.pushLayer()

bxy.drawImage("greece", pos = vec2(50, 50))
bxy.blurLayer(50)

bxy.addLayerAsImage("greeceBlur", rect(0, 0, 512+50*2, 512+50*2))

bxy.popLayer()


bxy.endFrame()

var frame: int

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(0, 0, 0, 1))

  bxy.saveTransform()
  bxy.translate(window.size.vec2/2)
  bxy.drawImage("greeceBlur", center = vec2(0, 0), angle = 0)
  bxy.restoreTransform()

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  pollEvents()

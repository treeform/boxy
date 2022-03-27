import boxy, opengl, windy, times

let window = newWindow("Windy + Boxy", ivec2(1280, 800))
makeContextCurrent(window)

loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("bg", readImage("examples/data/bg.png"))

var frame: int

let typeface = readTypeface("examples/data/IBMPlexMono-Bold.ttf")

proc drawText(
  bxy: Boxy,
  imageKey: string,
  transform: Mat3,
  typeface: Typeface,
  text: string,
  size: float32,
  color: Color
) =
  var font = newFont(typeface)
  font.size = size
  font.paint = color
  let
    arrangement = typeset(@[newSpan(text, font)], bounds = vec2(1280, 800))
    globalBounds = arrangement.computeBounds(transform).snapToPixels()
    textImage = newImage(globalBounds.w.int, globalBounds.h.int)
    imageSpace = translate(-globalBounds.xy) * transform
  textImage.fillText(arrangement, imageSpace)

  bxy.addImage(imageKey, textImage)
  bxy.drawImage(imageKey, globalBounds.xy)

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Draw the bg.
  bxy.drawImage("bg", rect = rect(vec2(0, 0), window.size.vec2))

  bxy.drawText(
    "main-image",
    translate(vec2(100, 100)),
    typeface,
    "Current time:",
    80,
    color(1, 1, 1, 1)
  )

  bxy.drawText(
    "main-image2",
    translate(vec2(100, 200)),
    typeface,
    now().format("hh:mm:ss"),
    80,
    color(1, 1, 1, 1)
  )

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

window.onResize = proc() =
  display()

while not window.closeRequested:
  display()
  pollEvents()

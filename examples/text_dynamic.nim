import boxy, opengl, windy, times

let windowSize = ivec2(1280, 800)

let window = newWindow("Windy + Boxy", windowSize)
makeContextCurrent(window)

loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("bg", readImage("examples/data/bg.png"))

var frame: int

let typeface = readTypeface("examples/data/IBMPlexMono-Bold.ttf")

proc drawText(bxy: Boxy, pos: Vec2, typeface: Typeface, text: string, size: float32, color: Color) =
  var font = newFont(typeface)
  font.size = size
  font.paint = color
  let spans = @[newSpan(text, font)]
  let arrangement = typeset(spans, bounds = vec2(1280, 800))
  let snappedBounds = arrangement.computeBounds().snapToPixels()
  let textImage = newImage(snappedBounds.w.int, snappedBounds.h.int)
  textImage.fillText(arrangement, translate(-snappedBounds.xy))
  bxy.addImage("text", textImage)
  bxy.drawImage("text", snappedBounds.xy + pos)

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(windowSize)

  # Draw the bg.
  bxy.drawImage("bg", rect = rect(vec2(0, 0), windowSize.vec2))

  bxy.drawText(vec2(100, 100), typeface, now().format("hh:mm:ss"), 80, color(1, 1, 1, 1))

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  display()
  pollEvents()

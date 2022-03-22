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

var spot = 0
proc drawText(bxy: Boxy, globalSpace: Mat3, typeface: Typeface, text: string, size: float32, color: Color) =

  var font = newFont(typeface)
  font.size = size
  font.paint = color
  let spans = @[newSpan(text, font)]
  let arrangement = typeset(spans, bounds = vec2(1280, 800))

  let globalBounds = arrangement.computeBounds(globalSpace).snapToPixels()

  let textImage = newImage(globalBounds.w.int, globalBounds.h.int)
  let imageSpace = translate(-globalBounds.xy) * globalSpace
  textImage.fillText(arrangement, imageSpace)

  #textImage.writeFile("text.png")
  bxy.addImage("text" & $spot, textImage)
  bxy.drawImage("text" & $spot, globalBounds.xy)
  inc spot

# Called when it is time to draw a new frame.
proc display() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(windowSize)

  # Draw the bg.
  bxy.drawImage("bg", rect = rect(vec2(0, 0), windowSize.vec2))

  spot = 0

  bxy.drawText(translate(vec2(100, 100)), typeface, now().format("hh:mm:ss"), 80, color(1, 1, 1, 1))

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  display()
  pollEvents()

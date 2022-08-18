import boxy, opengl, windy, pixie, vmath

let windowSize = ivec2(1280, 800)

let window = newWindow("Broken Image", windowSize)
makeContextCurrent(window)

loadExtensions()

let bxy = newBoxy()

let testImage = newImage(400, 400)
testImage.fill(rgba(255, 255, 255, 255))
newContext(testImage).strokeSegment(segment(vec2(0), vec2(400)))

bxy.addImage("test", testImage)

# Called when it is time to draw a new frame.
proc display() =

  bxy.beginFrame(window.size)

  bxy.drawImage("test", pos = vec2(100.0, 0.0), tint = color(0, 1, 0, 1))
  bxy.drawImage("test", rect = rect(vec2(100.0, 0.0), vec2(300, 300)), tint = color(1, 0, 0, 1))
  bxy.drawImage("test", rect = rect(vec2(100.0, 0.0), vec2(280, 280)), tint = color(0.75, 0, 0, 1))
  bxy.drawImage("test", rect = rect(vec2(100.0, 0.0), vec2(168, 168)), tint = color(0.5, 0, 0, 1))

  bxy.endFrame()
  window.swapBuffers()

while not window.closeRequested:
  display()
  pollEvents()

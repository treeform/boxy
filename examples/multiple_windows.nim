import boxy, opengl, windy

let
  windowSize = ivec2(1280, 800)
  rhino = readImage("examples/data/rhino.png")

var i: int
proc display(window: Window, bxy: Boxy) =
  makeContextCurrent(window)
  bxy.beginFrame(windowSize)
  bxy.drawRect(rect(vec2(0, 0), windowSize.vec2), color(1, 1, 1, 1))
  bxy.drawImage("rhino", vec2((i mod windowSize.x).float32, 0))
  bxy.endFrame()
  window.swapBuffers()
  inc i

let
  window1 = newWindow("Windy1 + Boxy", windowSize)
  window2 = newWindow("Windy2 + Boxy", windowSize)

makeContextCurrent(window1)
loadExtensions()

let bxy1 = newBoxy()
bxy1.addImage("rhino", rhino)

makeContextCurrent(window2)
loadExtensions()

let bxy2 = newBoxy()
bxy2.addImage("rhino", rhino)

while not window1.closeRequested:
  pollEvents()
  display(window1, bxy1)
  display(window2, bxy2)

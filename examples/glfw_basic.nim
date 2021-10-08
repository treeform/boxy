import boxy, opengl, staticglfw

let windowSize = vec2(1280, 800)

if init() == 0:
  quit("Failed to Initialize GLFW.")

windowHint(RESIZABLE, false.cint)

let window = createWindow(
  windowSize.x.cint, windowSize.y.cint, "GLFW + Boxy", nil, nil
)

makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

let rhino = readImage("examples/rhino.png")
bxy.addImage("rhino", rhino)

var i: int

proc display() =
  bxy.beginFrame(windowSize)
  bxy.drawRect(rect(vec2(), windowSize), color(1, 1, 1, 1))
  bxy.drawImage("rhino", vec2((i mod windowSize.x.int).float32, 0))
  bxy.endFrame()
  window.swapBuffers()
  inc i

while windowShouldClose(window) != 1:
  pollEvents()
  display()

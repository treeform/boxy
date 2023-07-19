import boxy, opengl, windy, pixie, vmath

let windowSize = ivec2(1280, 800)

let window = newWindow("Broken Image", windowSize)
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

let testImage = readImage("examples/data/greece.png")
var count = 0
while true:
  bxy.addImage("test" & $count, testImage)
  inc count
  #echo count

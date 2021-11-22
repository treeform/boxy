import benchy, boxy, opengl, windy

let window = newWindow("Windy + Boxy", ivec2(1280, 800))
makeContextCurrent(window)
loadExtensions()

let
  bxy = newBoxy()
  image = readImage("docs/boxyBanner.png")

timeIt "add":
  bxy.addImage("boxyBanner", image)


#grow

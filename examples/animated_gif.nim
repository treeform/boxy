import boxy, opengl, pixie, pixie/fileformats/gif, std/times, windy

let window = newWindow("Animated Gif", ivec2(1280, 800))
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Decode the .gif file.
let animatedGif = decodeGif(readFile("examples/data/newtons_cradle.gif"))

# Add the gif's frames to boxy.
for i, frame in animatedGif.frames:
  bxy.addImage("frame" & $i, frame)

var
  prevFrameTime = epochTime()
  gifTimer: float32

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Draw the bg.
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(0.1, 0.1, 0.1, 1))

  # How much time passed from the last frame to this frame?
  let
    frameTime = epochTime()
    frameDeltaTime = frameTime - prevFrameTime
  prevFrameTime = frameTime

  gifTimer += frameDeltaTime

  # If we haven't reached the end of the gif, draw the gif's frames.
  if gifTimer < animatedGif.duration:
    var intervalSum: float32 # Keep track of how far we are into the gif.
    for i in 0 ..< animatedGif.frames.len:
      bxy.drawImage("frame" & $i, center = window.size.vec2 / 2, angle = 0)
      intervalSum += animatedGif.intervals[i]
      if intervalSum > gifTimer:
        break
  else:
    # Restart the gif
    gifTimer = 0
    bxy.drawImage("frame0", center = window.size.vec2 / 2, angle = 0)

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()

  # On F4 key, write the atlas to a file.
  if window.buttonPressed[KeyF4]:
    echo "Writing atlas to tmp/atlas.png"
    bxy.readAtlas().writeFile("tmp/atlas.png")

while not window.closeRequested:
  pollEvents()

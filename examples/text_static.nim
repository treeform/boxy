import boxy, opengl, windy

let window = newWindow("Windy + Boxy", ivec2(1280, 800))
makeContextCurrent(window)

loadExtensions()

let bxy = newBoxy()

# Load the images.
bxy.addImage("bg", readImage("examples/data/bg.png"))

var frame: int

let
  typeface1 = readTypeface("examples/data/PinyonScript.ttf")
  font1 = newFont(typeface1)
font1.size = 40
font1.paint = "#FFFFFF"

let poem = """
Once upon a midnight dreary, while I pondered, weak and weary,
Over many a quaint and curious volume of forgotten lore—
    While I nodded, nearly napping, suddenly there came a tapping,
As of some one gently rapping, rapping at my chamber door.
“’Tis some visitor,” I muttered, “tapping at my chamber door—
            Only this and nothing more.”

    Ah, distinctly I remember it was in the bleak December;
And each separate dying ember wrought its ghost upon the floor.
    Eagerly I wished the morrow;—vainly I had sought to borrow
    From my books surcease of sorrow—sorrow for the lost Lenore—
For the rare and radiant maiden whom the angels name Lenore—
            Nameless here for evermore.
"""

let
  arrangement = typeset(@[newSpan(poem, font1)], bounds = vec2(1280, 800))
  snappedBounds = arrangement.computeBounds().snapToPixels()
  textImage = newImage(snappedBounds.w.int, snappedBounds.h.int)

textImage.fillText(arrangement, translate(-snappedBounds.xy))

bxy.addImage("text", textImage)

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  # Draw the bg.
  bxy.drawImage("bg", rect = rect(vec2(0, 0), window.size.vec2))

  # Draw big static text:
  bxy.drawImage("text", snappedBounds.xy + vec2(100, 100))

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

  # On F4 key, write the atlas to a file.
  if window.buttonPressed[KeyF4]:
    echo "Writing atlas to tmp/atlas.png"
    bxy.readAtlas().writeFile("tmp/atlas.png")

while not window.closeRequested:
  pollEvents()

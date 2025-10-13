
import
  std/[strutils, random],
  boxy, opengl, pixie, windy

randomize()

const
  bgPath = "M17.1132 10.359C18.8996 7.26497 22.2008 5.35898 25.7735 5.35898L54.2265 5.35898C57.7992 5.35898 61.1004 7.26496 62.8867 10.359L77.1132 35C78.8996 38.094 78.8996 41.906 77.1132 45L62.8867 69.641C61.1004 72.735 57.7991 74.641 54.2265 74.641L25.7735 74.641C22.2008 74.641 18.8996 72.735 17.1132 69.641L2.88674 45C1.10042 41.906 1.10042 38.094 2.88674 35L17.1132 10.359Z"
  topPath = "M25.8996 9C23.0742 9.53881 20.5818 11.2795 19.1132 13.8231L13.8149 23H66.185L60.8867 13.8231C59.4182 11.2795 56.9257 9.53881 54.1004 9H25.8996Z"
  bottomPath = "M25.8996 71C23.0742 70.4612 20.5818 68.7205 19.1132 66.1769L13.8149 57H66.185L60.8867 66.1769C59.4182 68.7205 56.9258 70.4612 54.1004 71H25.8996Z"
  borderPath = "M27.7735 9.82309L52.2265 9.82309C55.4419 9.82309 58.413 11.5385 60.0207 14.3231L72.2472 35.5C73.8549 38.2846 73.8549 41.7154 72.2472 44.5L60.0207 65.6769C58.413 68.4615 55.4419 70.1769 52.2265 70.1769L27.7735 70.1769C24.5581 70.1769 21.587 68.4615 19.9793 65.6769L7.75278 44.5C6.14509 41.7154 6.14509 38.2846 7.75278 35.5L19.9793 14.3231C21.587 11.5385 24.5581 9.82309 27.7735 9.82309Z"

  topList = @["New", "", "", "", ""]
  bottomList = @["Review", "Issue", "Error", "", "", "", ""]

  colors = @["#F35624", "#00E9B1", "#B9B3B1"]

let words = """lorem ipsum dolor sit amet consectetur adipiscing elit nulla sit amet nisi ipsum nullam nisi erat cursus at nisi ac semper feugiat dolor morbi mattis nibh diam eget pretium nisi facilisis et nullam eget pellentesque eros nec pretium mauris sed ullamcorper turpis luctus magna porttitor, eget bibendum lacus commodo. Morbi pretium dapibus nisi ut dignissim. Sed blandit vulputate orci ac fermentum suspendisse""".split(" ")

proc genText(a, b: int): string =
  for i in 0 ..< rand(a .. b):
    if i != 0:
      result.add " "
    result.add words.sample()

var font = readFont("examples/data/Roboto-Regular_1.ttf")
font.paint = newPaint(SolidPaint)
font.paint.color = color(1, 1, 1, 1)
font.size = 10

var font2 = readFont("examples/data/Roboto-Regular_1.ttf")
font2.paint = newPaint(SolidPaint)
font2.paint.color = color(0, 0, 0, 1)
font2.size = 10

proc createHex(size: float32, middle, top, bottom, htmlColor: string): Image =
  let color = parseHtmlColor(htmlColor)
  let image = newImage(int(80.0 * size), int(80.0 * size))
  #image.fill(rgba(200, 200, 200, 255))

  font.paint.color = color(1, 1, 1, 1)
  font.size = 10

  font2.paint.color = color
  font2.size = 10

  let mat = scale(vec2(size))
  image.fillPath(
    bgPath,
    parseHtmlColor("#FFFFFF").rgba,
    mat
  )

  if top != "":
    image.fillPath(
      topPath,
      color,
      mat
    )

  if bottom != "":
    image.fillPath(
      bottomPath,
      color,
      mat,
    )

  image.strokePath(
    borderPath,
    color,
    mat,
    strokeWidth = 3.0
  )

  image.fillText(
    font.typeset(top, vec2(39, 12), CenterAlign),
    mat * translate(vec2(21, 10))
  )

  image.fillText(
    font.typeset(bottom, vec2(39, 12), CenterAlign),
    mat * translate(vec2(21, 58))
  )

  var arrangement: Arrangement
  font2.size = 30
  font2.lineHeight = 28
  while font2.size > 1:
    arrangement = font2.typeset(middle, vec2(53, 34), CenterAlign, MiddleAlign)
    let bounds = arrangement.computeBounds()
    if bounds.w < 53 and bounds.h < 34:
      break
    font2.size -= 1
    font2.lineHeight -= 1

  image.fillText(arrangement, mat * translate(vec2(13, 23)))
  return image

let window = newWindow("Hexmap", ivec2(1280, 800))
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

var frame: int

type Hex = ref object
  id: int
  size: float32
  middle, top, bottom: string
  hexColor: string

var
  gridSize = 50
  pos: Vec2 # vec2(gridSize.float32, gridSize.float32) * 160 / 2
  vel: Vec2
  zoom: float32 = 0.5
  zoomVel: float32
  grid: seq[seq[Hex]]
  idC = 1

for x in 0 ..< gridSize:
  grid.add(newSeq[Hex](gridSize))

# grow clusters
block:
  echo "Generating hexes..."
  proc addCluster(x, y, more: int) =
    if x < 0 or y < 0 or x >= gridSize or y >= gridSize:
      return

    let thisSize = 1.8 + more.float32 / 4

    if grid[x][y] != nil and grid[x][y].size > thisSize:
      return

    let hex = Hex(
      id: idC,
      size: thisSize,
      middle: genText(3, 20),
      top: topList.sample(),
      bottom: bottomList.sample(),
      hexColor: colors.sample(),
    )
    grid[x][y] = hex
    inc idC

    if more > 0:
      addCluster(x, y+1, more - 1)
      addCluster(x, y-1, more - 1)
      if x mod 2 == 0:
        addCluster(x-1, y+1, more - 1)
        addCluster(x+1, y+1, more - 1)
      else:
        addCluster(x-1, y-1, more - 1)
        addCluster(x+1, y-1, more - 1)
      addCluster(x-1, y, more - 1)
      addCluster(x+1, y, more - 1)

  for c in 0 ..< 17:
    let
      x = rand(0 ..< gridSize)
      y = rand(0 ..< gridSize)
    addCluster(x, y, 3)

  #addCluster(0, 0, 0)

  echo "Done generating hexes"

proc vec3(v: IVec2): Vec3 =
  vec3(v.x.float32, v.y.float32, 1)

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  glClearColor(0.9, 0.9, 0.9, 0.9)
  glClear(GL_COLOR_BUFFER_BIT)

  bxy.saveTransform()

  if window.buttonDown[MouseLeft]:
    vel = window.mouseDelta.vec2
  else:
    vel *= 0.9

  pos += vel

  if window.scrollDelta.y != 0:
    zoomVel = window.scrollDelta.y * 0.03
  else:
    zoomVel *= 0.9

  let oldMat = translate(vec2(pos.x, pos.y)) * scale(vec2(zoom*zoom, zoom*zoom))
  zoom += zoomVel
  zoom = clamp(zoom, 0.3, 1.3)
  let newMat = translate(vec2(pos.x, pos.y)) * scale(vec2(zoom*zoom, zoom*zoom))
  let newAt = newMat.inverse() * window.mousePos.vec2
  let oldAt = oldMat.inverse() * window.mousePos.vec2
  pos -= (oldAt - newAt).xy * (zoom*zoom)

  bxy.translate(pos)
  bxy.scale(vec2(zoom*zoom, zoom*zoom))

  for x, row in grid:
    for y, hex in row:
      if hex != nil:
        let shift =
          if x mod 2 == 0:
            0.5
          else:
            0.0
        let key = "hex" & $hex.id
        if key notin bxy:
          var image = createHex(hex.size, hex.middle, hex.top, hex.bottom, hex.hexColor)
          bxy.addImage(key, image)
        bxy.drawImage(
          key,
          center = vec2((x.float32)*160, (y.float32 + shift)*160),
          angle = 0,
          color(1, 1, 1, 1)
        )

  # End this frame, flushing the draw commands.
  bxy.endFrame()
  bxy.restoreTransform()
  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

  # On F4 key, write the atlas to a file.
  if window.buttonPressed[KeyF4]:
    echo "Writing atlas to tmp/atlas.png"
    bxy.readAtlas().writeFile("tmp/atlas.png")

while not window.closeRequested:
  pollEvents()

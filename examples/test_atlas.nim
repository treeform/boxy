import boxy, boxy/textures, opengl, windy, os, random, math, pixie

# Test the skyline allocator with randomly generated images

randomize()

proc randomColor(): Color =
  ## Generate a random color
  color(rand(1.0), rand(1.0), rand(1.0), 1.0)

proc drawStar(image: Image, center: Vec2, radius: float32, points: int, color: Color) =
  ## Draw a star with N points
  let
    outerRadius = radius
    innerRadius = radius * 0.4
    angleStep = TAU / float32(points * 2)

  var path = newPath()
  for i in 0 ..< points * 2:
    let
      angle = float32(i) * angleStep - PI / 2
      r = if i mod 2 == 0: outerRadius else: innerRadius
      x = center.x + cos(angle) * r
      y = center.y + sin(angle) * r

    if i == 0:
      path.moveTo(x, y)
    else:
      path.lineTo(x, y)

  path.closePath()
  image.fillPath(path, color)

proc generateRandomImage(minSize, maxSize: int): Image =
  ## Generate a random image with random content
  let
    width = rand(minSize..maxSize)
    height = rand(minSize..maxSize)
    image = newImage(width, height)
    bgColor = randomColor()

  image.fill(bgColor)

  # For larger images, draw a random shape
  if width > 16 and height > 16:
    let
      shapeColor = randomColor()
      centerX = width.float32 / 2
      centerY = height.float32 / 2
      maxRadius = min(width, height).float32 * 0.3

    case rand(0..3):
    of 0:  # Rectangle
      let
        w = rand(width.float32 * 0.2..width.float32 * 0.7)
        h = rand(height.float32 * 0.2..height.float32 * 0.7)
        x = (width.float32 - w) / 2
        y = (height.float32 - h) / 2
      var path = newPath()
      path.rect(x, y, w, h)
      image.fillPath(path, shapeColor)

    of 1:  # Circle
      let radius = rand(maxRadius * 0.5..maxRadius)
      var path = newPath()
      path.circle(centerX, centerY, radius)
      image.fillPath(path, shapeColor)

    of 2:  # Triangle
      var path = newPath()
      let size = rand(maxRadius * 0.5..maxRadius)
      path.moveTo(centerX, centerY - size)
      path.lineTo(centerX - size * 0.866, centerY + size * 0.5)
      path.lineTo(centerX + size * 0.866, centerY + size * 0.5)
      path.closePath()
      image.fillPath(path, shapeColor)

    of 3:  # Star with random points
      let
        points = rand(3..8)
        radius = rand(maxRadius * 0.5..maxRadius)
      image.drawStar(vec2(centerX, centerY), radius, points, shapeColor)

    else:
      discard

  return image

# Initialize
let window = newWindow("Atlas Packing Test", ivec2(800, 600))
makeContextCurrent(window)
loadExtensions()

let ctx = newBoxy(atlasSize = 512, margin = 2)  # Add 2 pixel margin around each image

# Create tmp directory
if not dirExists("tmp"):
  createDir("tmp")

echo "Generating random images and packing them..."
echo "Atlas will be saved every 10 images to tmp/atlas_N.png"
echo ""

var
  imageCount = 0
  totalImages = 100  # Total number of images to generate
  saveInterval = 10  # Save atlas every N images

# Generate and add random images
for i in 1..totalImages:
  let
    # Mix of small and large images
    sizeCategory = rand(0..2)
    (minSize, maxSize) = case sizeCategory:
      of 0: (4, 16)      # Small images
      of 1: (16, 64)     # Medium images
      else: (64, 256)    # Large images

    img = generateRandomImage(minSize, maxSize)
    key = "img_" & $i

  ctx.addImage(key, img)
  inc imageCount

  echo "Added image ", i, " (", img.width, "x", img.height, ")"

  # Save atlas periodically
  if i mod saveInterval == 0 or i == totalImages:
    # Force packing by drawing something
    ctx.beginFrame(ivec2(800, 600))
    ctx.drawImage(key, vec2(0, 0))
    ctx.endFrame()

    let filename = "tmp/atlas_" & $i & ".png"
    ctx.atlasTexture.writeFile(filename)
    echo "  -> Saved ", filename
    echo ""

echo "\nFinal statistics:"
echo "  Total images packed: ", imageCount
echo "  Atlas size: 512x512 (initial)"
echo "  Atlas files saved in tmp/ directory"
echo ""
echo "You can view the progression of the packing algorithm by looking at:"
for i in countup(saveInterval, totalImages, saveInterval):
  echo "  - tmp/atlas_", i, ".png"

# Quick render loop to display the final result
var frameCount = 0
window.onCloseRequest = proc() =
  quit()

echo "\nShowing packed images in window (close window to exit)..."

while not window.closeRequested:
  pollEvents()

  ctx.beginFrame(window.size)

  # Draw a grid of images
  var
    x = 10.0
    y = 10.0
    maxHeight = 0.0
    cols = 0

  for i in 1..min(50, totalImages):  # Show first 50 images
    let key = "img_" & $i
    if ctx.contains(key):
      let size = ctx.getImageSize(key)

      # Wrap to next row if needed
      if x + size.x.float32 > 780:
        x = 10
        y += maxHeight + 10
        maxHeight = 0
        cols = 0

      ctx.drawImage(key, vec2(x, y))

      x += size.x.float32 + 10
      maxHeight = max(maxHeight, size.y.float32)
      inc cols

      # Stop if we're getting too far down
      if y > 550:
        break

  ctx.endFrame()

  window.swapBuffers()
  inc frameCount

echo "Test completed!"


# Tilemap Example - Renders a huge tilemap using OpenGL 4.1 shaders
#
# Features:
# - 1024x1024 tilemap (over 1 million tiles!)
# - Uses a 16x16 tile atlas (256 unique tiles)
# - Custom OpenGL 4.1 shaders for efficient rendering
# - Pan with left mouse button, zoom with mouse wheel
# - Generates random pattern with interesting tile variations
#
# The whole tilemap is rendered as a single quad using:
# - Index texture: 1024x1024 R8 texture where each pixel is a tile index (0-255)
# - Atlas texture: The tile atlas loaded from testTexture.png
# - Custom OpenGL 4.1 fragment shader that samples the index, calculates atlas coordinates, and renders

import boxy, opengl, pixie, windy, random, boxy/shaders

let window = newWindow("Tilemap", ivec2(1280, 800))
makeContextCurrent(window)
loadExtensions()

let bxy = newBoxy()

# Load tile atlas (16x16 = 256 tiles)
let tileAtlas = readImage("examples/data/testTexture.png")
bxy.addImage("tileAtlas", tileAtlas)

var vel: Vec2
var pos: Vec2
var zoom: float32 = 0.5
var zoomVel: float32
var frame: int

# Generate a 1024x1024 texture where each pixel is a byte index into the 16x16 tile map
const MAP_SIZE = 1024*16
echo "map size: ", MAP_SIZE * MAP_SIZE, " bytes"
var tileIndexData: seq[uint8] = newSeq[uint8](MAP_SIZE * MAP_SIZE)

# Fill with random tile indices (0-255 for 16x16 atlas) or load from file
randomize()

# Generate random tilemap if file doesn't exist or is invalid
echo "Generating random tilemap... this will take a few seconds..."
for i in 0 ..< tileIndexData.len:
  # Create some patterns for more interesting visuals
  let x = i mod MAP_SIZE
  let y = i div MAP_SIZE

  if x >= MAP_SIZE div 2 and y >= MAP_SIZE div 2:
    tileIndexData[i] = rand(192..255).uint8
  elif x < MAP_SIZE div 2 and y >= MAP_SIZE div 2:
    tileIndexData[i] = rand(128..192).uint8
  elif x >= MAP_SIZE div 2 and y < MAP_SIZE div 2:
    tileIndexData[i] = rand(64..128).uint8
  elif x < MAP_SIZE div 2 and y < MAP_SIZE div 2:
    tileIndexData[i] = rand(0..64).uint8

  # Border tiles
  let borderSize = 8
  if x < borderSize or y < borderSize or x > MAP_SIZE - borderSize or y > MAP_SIZE - borderSize:
    tileIndexData[i] = 0

echo "Done generating tilemap"

# Create OpenGL texture for tile indices
var indexTexture: GLuint
glGenTextures(1, indexTexture.addr)
glBindTexture(GL_TEXTURE_2D, indexTexture)
glTexImage2D(GL_TEXTURE_2D, 0, GL_R8.GLint, MAP_SIZE, MAP_SIZE, 0, GL_RED, GL_UNSIGNED_BYTE, tileIndexData[0].addr)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE.GLint)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE.GLint)

# Create tile atlas texture, mipmapped.
var atlasTexture: GLuint
glGenTextures(1, atlasTexture.addr)
glBindTexture(GL_TEXTURE_2D, atlasTexture)
glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA.GLint, tileAtlas.width.GLint, tileAtlas.height.GLint, 0, GL_RGBA, GL_UNSIGNED_BYTE, tileAtlas.data[0].addr)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR.GLint)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE.GLint)
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE.GLint)
glGenerateMipmap(GL_TEXTURE_2D)

# Vertex shader source (OpenGL 4.1)
const vertexShaderSource = """
#version 410 core

layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;

out vec2 TexCoord;

uniform mat4 uMVP;

void main() {
    gl_Position = uMVP * vec4(aPos, 0.0, 1.0);
    TexCoord = aTexCoord;
}
"""

# Fragment shader source (OpenGL 4.1)
const fragmentShaderSource = """
#version 410 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D uIndexTexture;
uniform sampler2D uTileAtlas;
uniform vec2 uMapSize;
uniform vec2 uAtlasSize;
uniform float uTileSize;

void main() {
    // Sample the tile index from the index texture
    float tileIndex = texture(uIndexTexture, TexCoord).r * 255.0;

    // Convert tile index to atlas coordinates
    float tilesPerRow = uAtlasSize.x / uTileSize;
    float tileX = mod(tileIndex, tilesPerRow);
    float tileY = floor(tileIndex / tilesPerRow);

    // Get position within the current tile (0-1 range)
    vec2 tilePos = fract(TexCoord * uMapSize);

    // Calculate final texture coordinates in the atlas
    vec2 atlasCoord = (vec2(tileX, tileY) + tilePos) * uTileSize / uAtlasSize;

    FragColor = texture(uTileAtlas, vec2(atlasCoord.x, 1.0 - atlasCoord.y));
}
"""

# Compile shader
let shader = newShader(
  ("vertex", vertexShaderSource),
  ("fragment", fragmentShaderSource)
)

# Quad vertices (position + texture coordinates)
var quadVertices: seq[float32] = @[
  # positions    # texture coords
  -1.0f,  1.0f,   0.0f, 0.0f,  # top left
  -1.0f, -1.0f,   0.0f, 1.0f,  # bottom left
   1.0f, -1.0f,   1.0f, 1.0f,  # bottom right
   1.0f,  1.0f,   1.0f, 0.0f   # top right
]

var quadIndices: seq[uint32] = @[
  0u32, 1u32, 2u32,  # first triangle
  0u32, 2u32, 3u32   # second triangle
]

# Create VAO, VBO, EBO
var VAO, VBO, EBO: GLuint
glGenVertexArrays(1, VAO.addr)
glGenBuffers(1, VBO.addr)
glGenBuffers(1, EBO.addr)

glBindVertexArray(VAO)

glBindBuffer(GL_ARRAY_BUFFER, VBO)
glBufferData(GL_ARRAY_BUFFER, quadVertices.len * sizeof(float32), quadVertices[0].addr, GL_STATIC_DRAW)

glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO)
glBufferData(GL_ELEMENT_ARRAY_BUFFER, quadIndices.len * sizeof(uint32), quadIndices[0].addr, GL_STATIC_DRAW)

# Position attribute
glVertexAttribPointer(0, 2, cGL_FLOAT, GL_FALSE, 4 * sizeof(float32), cast[pointer](0))
glEnableVertexAttribArray(0)

# Texture coordinate attribute
glVertexAttribPointer(1, 2, cGL_FLOAT, GL_FALSE, 4 * sizeof(float32), cast[pointer](2 * sizeof(float32)))
glEnableVertexAttribArray(1)

glBindVertexArray(0)

# Called when it is time to draw a new frame.
window.onFrame = proc() =
  # Clear the screen and begin a new frame.
  bxy.beginFrame(window.size)

  glClearColor(0.0, 0.0, 0.0, 1.0)
  glClear(GL_COLOR_BUFFER_BIT)

  # Handle input for panning and zooming like hex example
  # Left mouse button: drag to pan
  # Mouse wheel: zoom in/out
  if window.buttonDown[MouseLeft]:
    vel = window.mouseDelta.vec2
  else:
    vel *= 0.9

  pos += vel

  if window.scrollDelta.y != 0:
    zoomVel = window.scrollDelta.y * 0.01
  else:
    zoomVel *= 0.9

  let oldMat = translate(vec2(pos.x, pos.y)) * scale(vec2(zoom, zoom))
  zoom += zoomVel
  zoom = clamp(zoom, 0.01, 50.0)
  let newMat = translate(vec2(pos.x, pos.y)) * scale(vec2(zoom, zoom))
  let newAt = newMat.inverse() * window.mousePos.vec2
  let oldAt = oldMat.inverse() * window.mousePos.vec2
  pos -= (oldAt - newAt).xy * (zoom)

  # Create MVP matrix
  let projection = ortho(0.0f, window.size.x.float32, window.size.y.float32, 0.0f, -1.0f, 1.0f)
  let view = translate(vec3(pos.x, pos.y, 0.0f)) *
             scale(vec3(zoom * MAP_SIZE.float32/2, zoom * MAP_SIZE.float32/2, 1.0f))
  let mvp = projection * view

  # Use our custom shader
  glUseProgram(shader.programId)

  # Set uniforms
  shader.setUniform("uMVP", mvp)
  shader.setUniform("uMapSize", vec2(MAP_SIZE.float32, MAP_SIZE.float32))
  shader.setUniform("uAtlasSize", vec2(tileAtlas.width.float32, tileAtlas.height.float32))
  shader.setUniform("uTileSize", 16.0f)  # Each tile is 16x16 pixels

  shader.bindUniforms()

  # Bind textures
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, indexTexture)
  shader.setUniform("uIndexTexture", 0)

  glActiveTexture(GL_TEXTURE1)
  glBindTexture(GL_TEXTURE_2D, atlasTexture)
  shader.setUniform("uTileAtlas", 1)

  shader.bindUniforms()

  # Draw the quad
  glBindVertexArray(VAO)
  glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, nil)
  glBindVertexArray(0)

  # End this frame, flushing the draw commands.
  bxy.endFrame()

  # Swap buffers displaying the new Boxy frame.
  window.swapBuffers()
  inc frame

while not window.closeRequested:
  pollEvents()

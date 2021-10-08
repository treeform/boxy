import bitty, boxy/buffers, boxy/shaders, boxy/textures, bumpy, chroma, hashes,
    opengl, os, pixie, strutils, tables, vmath

export pixie

const quadLimit = 10_921 # 6 indices per quad, ensure indices stay in uint16 range

type
  BoxyError* = object of ValueError

  TileKind = enum
    tkIndex, tkColor

  TileInfo = object
    case kind: TileKind
    of tkIndex:
      index: int
    of tkColor:
      color: Color

  ImageInfo = object
    width: int           ## Width of the image in pixels.
    height: int          ## Height of the image in pixels.
    tiles: seq[TileInfo] ## The tile info for this image.
    oneColor: Color      ## If tiles = [] then this is the image's color.

  Boxy* = ref object
    atlasShader, maskShader, activeShader: Shader
    atlasTexture: Texture
    maskTextureWrite: int      ## Index into mask textures for writing.
    maskTextureRead: int       ## Index into mask textures for rendering.
    maskTextures: seq[Texture] ## Masks array for pushing and popping.
    atlasSize: int             ## Size x size dimensions of the atlas.
    quadCount: int             ## Number of quads drawn so far in this batch.
    quadsPerBatch: int         ## Max quads in a batch before issuing an OpenGL call.
    mat: Mat4                  ## The current matrix.
    mats: seq[Mat4]            ## The matrix stack.
    entries: Table[string, ImageInfo]
    tileSize: int
    maxTiles: int
    tileRun: int
    takenTiles: BitArray       ## Flag for if the tile is taken or not.
    proj: Mat4
    frameSize: Vec2            ## Dimensions of the window frame.
    vertexArrayId, maskFramebufferId: GLuint
    frameBegun, maskBegun: bool
    pixelate: bool             ## Makes texture look pixelated, like a pixel game.

    # Buffer data for OpenGL
    positions: tuple[buffer: Buffer, data: seq[float32]]
    colors: tuple[buffer: Buffer, data: seq[uint8]]
    uvs: tuple[buffer: Buffer, data: seq[float32]]
    indices: tuple[buffer: Buffer, data: seq[uint16]]

proc vec2(x, y: SomeNumber): Vec2 {.inline.} =
  ## Integer short cut for creating vectors.
  vec2(x.float32, y.float32)

func `*`(m: Mat4, v: Vec2): Vec2 =
  (m * vec3(v.x, v.y, 0.0)).xy

proc `*`(a, b: Color): Color {.inline.} =
  result.r = a.r * b.r
  result.g = a.g * b.g
  result.b = a.b * b.b
  result.a = a.a * b.a

proc tileWidth(boxy: Boxy, imageInfo: ImageInfo): int {.inline.} =
  ## Number of tiles wide.
  ceil(imageInfo.width / boxy.tileSize).int

proc tileHeight(boxy: Boxy, imageInfo: ImageInfo): int {.inline.} =
  ## Number of tiles high.
  ceil(imageInfo.height / boxy.tileSize).int

proc readAtlas*(boxy: Boxy): Image =
  ## Read the current atlas content.
  result = newImage(boxy.atlasTexture.width, boxy.atlasTexture.height)
  glBindTexture(GL_TEXTURE_2D, boxy.atlasTexture.textureId)
  when not defined(emscripten):
    glGetTexImage(
      GL_TEXTURE_2D,
      0,
      GL_RGBA,
      GL_UNSIGNED_BYTE,
      result.data[0].addr
    )

proc upload(boxy: Boxy) =
  ## When buffers change, uploads them to GPU.
  boxy.positions.buffer.count = boxy.quadCount * 4
  boxy.colors.buffer.count = boxy.quadCount * 4
  boxy.uvs.buffer.count = boxy.quadCount * 4
  boxy.indices.buffer.count = boxy.quadCount * 6
  bindBufferData(boxy.positions.buffer, boxy.positions.data[0].addr)
  bindBufferData(boxy.colors.buffer, boxy.colors.data[0].addr)
  bindBufferData(boxy.uvs.buffer, boxy.uvs.data[0].addr)

proc contains*(boxy: Boxy, key: string): bool {.inline.} =
  key in boxy.entries

proc draw(boxy: Boxy) =
  ## Flips - draws current buffer and starts a new one.
  if boxy.quadCount == 0:
    return

  boxy.upload()

  glUseProgram(boxy.activeShader.programId)
  glBindVertexArray(boxy.vertexArrayId)

  if boxy.activeShader.hasUniform("windowFrame"):
    boxy.activeShader.setUniform(
      "windowFrame", boxy.frameSize.x, boxy.frameSize.y
    )
  boxy.activeShader.setUniform("proj", boxy.proj)

  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, boxy.atlasTexture.textureId)
  boxy.activeShader.setUniform("atlasTex", 0)

  if boxy.activeShader.hasUniform("maskTex"):
    glActiveTexture(GL_TEXTURE1)
    glBindTexture(
      GL_TEXTURE_2D,
      boxy.maskTextures[boxy.maskTextureRead].textureId
    )
    boxy.activeShader.setUniform("maskTex", 1)

  boxy.activeShader.bindUniforms()

  glBindBuffer(
    GL_ELEMENT_ARRAY_BUFFER,
    boxy.indices.buffer.bufferId
  )
  glDrawElements(
    GL_TRIANGLES,
    boxy.indices.buffer.count.GLint,
    boxy.indices.buffer.componentType,
    nil
  )

  boxy.quadCount = 0

proc setUpMaskFramebuffer(boxy: Boxy) =
  glBindFramebuffer(GL_FRAMEBUFFER, boxy.maskFramebufferId)
  glFramebufferTexture2D(
    GL_FRAMEBUFFER,
    GL_COLOR_ATTACHMENT0,
    GL_TEXTURE_2D,
    boxy.maskTextures[boxy.maskTextureWrite].textureId,
    0
  )

proc createAtlasTexture(boxy: Boxy, size: int): Texture =
  result = Texture()
  result.width = size.int32
  result.height = size.int32
  result.componentType = GL_UNSIGNED_BYTE
  result.format = GL_RGBA
  result.internalFormat = GL_RGBA8
  result.genMipmap = true
  result.minFilter = minLinearMipmapLinear
  if boxy.pixelate:
    result.magFilter = magNearest
  else:
    result.magFilter = magLinear
  bindTextureData(result, nil)

proc addMaskTexture(boxy: Boxy, frameSize = vec2(1, 1)) =
  # Must be >0 for framebuffer creation below
  # Set to real value in beginFrame
  let maskTexture = Texture()
  maskTexture.width = frameSize.x.int32
  maskTexture.height = frameSize.y.int32
  maskTexture.componentType = GL_UNSIGNED_BYTE
  maskTexture.format = GL_RGBA
  when defined(emscripten):
    maskTexture.internalFormat = GL_RGBA8
  else:
    maskTexture.internalFormat = GL_R8
  maskTexture.minFilter = minLinear
  if boxy.pixelate:
    maskTexture.magFilter = magNearest
  else:
    maskTexture.magFilter = magLinear
  bindTextureData(maskTexture, nil)
  boxy.maskTextures.add(maskTexture)

proc addWhiteTile(boxy: Boxy) =
  # Insert a solid white tile used for all one color draws.
  let whiteTile = newImage(boxy.tileSize, boxy.tileSize)
  whiteTile.fill(color(1, 1, 1, 1))
  updateSubImage(
    boxy.atlasTexture,
    0,
    0,
    whiteTile
  )
  boxy.takenTiles[0] = true

proc clearAtlas*(boxy: Boxy) =
  boxy.entries.clear()
  boxy.takenTiles.clear()
  boxy.addWhiteTile()

proc newBoxy*(
  atlasSize = 512,
  tileSize = 32,
  quadsPerBatch = 1024,
  pixelate = false
): Boxy =
  ## Creates a new Boxy.
  if atlasSize mod tileSize != 0:
    raise newException(BoxyError, "Atlas size must be a multiple of tile size")
  if quadsPerBatch > quadLimit:
    raise newException(BoxyError, "Quads per batch cannot exceed " & $quadLimit)

  result = Boxy()
  result.atlasSize = atlasSize
  result.tileSize = tileSize
  result.quadsPerBatch = quadsPerBatch
  result.mat = mat4()
  result.mats = newSeq[Mat4]()
  result.pixelate = pixelate

  result.tileRun = atlasSize div tileSize
  result.maxTiles = result.tileRun * result.tileRun
  result.takenTiles = newBitArray(result.maxTiles)
  result.atlasTexture = result.createAtlasTexture(atlasSize)

  result.addMaskTexture()

  when defined(emscripten):
    result.atlasShader = newShaderStatic(
      "glsl/emscripten/atlas.vert",
      "glsl/emscripten/atlas.frag"
    )
    result.maskShader = newShaderStatic(
      "glsl/emscripten/atlas.vert",
      "glsl/emscripten/mask.frag"
    )
  else:
    result.atlasShader = newShaderStatic(
      "glsl/410/atlas.vert",
      "glsl/410/atlas.frag"
    )
    result.maskShader = newShaderStatic(
      "glsl/410/atlas.vert",
      "glsl/410/mask.frag"
    )

  result.positions.buffer = Buffer()
  result.positions.buffer.componentType = cGL_FLOAT
  result.positions.buffer.kind = bkVEC2
  result.positions.buffer.target = GL_ARRAY_BUFFER
  result.positions.data = newSeq[float32](
    result.positions.buffer.kind.componentCount() * quadsPerBatch * 4
  )

  result.colors.buffer = Buffer()
  result.colors.buffer.componentType = GL_UNSIGNED_BYTE
  result.colors.buffer.kind = bkVEC4
  result.colors.buffer.target = GL_ARRAY_BUFFER
  result.colors.buffer.normalized = true
  result.colors.data = newSeq[uint8](
    result.colors.buffer.kind.componentCount() * quadsPerBatch * 4
  )

  result.uvs.buffer = Buffer()
  result.uvs.buffer.componentType = cGL_FLOAT
  result.uvs.buffer.kind = bkVEC2
  result.uvs.buffer.target = GL_ARRAY_BUFFER
  result.uvs.data = newSeq[float32](
    result.uvs.buffer.kind.componentCount() * quadsPerBatch * 4
  )

  result.indices.buffer = Buffer()
  result.indices.buffer.componentType = GL_UNSIGNED_SHORT
  result.indices.buffer.kind = bkSCALAR
  result.indices.buffer.target = GL_ELEMENT_ARRAY_BUFFER
  result.indices.buffer.count = quadsPerBatch * 6

  for i in 0 ..< quadsPerBatch:
    let offset = i * 4
    result.indices.data.add([
      (offset + 3).uint16,
      (offset + 0).uint16,
      (offset + 1).uint16,
      (offset + 2).uint16,
      (offset + 3).uint16,
      (offset + 1).uint16,
    ])

  # Indices are only uploaded once
  bindBufferData(result.indices.buffer, result.indices.data[0].addr)

  result.upload()

  result.activeShader = result.atlasShader

  glGenVertexArrays(1, result.vertexArrayId.addr)
  glBindVertexArray(result.vertexArrayId)

  result.activeShader.bindAttrib("vertexPos", result.positions.buffer)
  result.activeShader.bindAttrib("vertexColor", result.colors.buffer)
  result.activeShader.bindAttrib("vertexUv", result.uvs.buffer)

  # Create mask framebuffer
  glGenFramebuffers(1, result.maskFramebufferId.addr)
  result.setUpMaskFramebuffer()

  let status = glCheckFramebufferStatus(GL_FRAMEBUFFER)
  if status != GL_FRAMEBUFFER_COMPLETE:
    raise newException(
      BoxyError,
      "Something wrong with mask framebuffer: " & $toHex(status.int32, 4)
    )

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

  # Enable premultiplied alpha blending
  glEnable(GL_BLEND)
  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)

  result.addWhiteTile()

proc grow(boxy: Boxy) =
  ## Grows the atlas size by 2 (growing area by 4).

  boxy.draw()

  # read old atlas content
  let
    oldAtlas = boxy.readAtlas()
    oldTileRun = boxy.tileRun

  boxy.atlasSize *= 2

  boxy.tileRun = boxy.atlasSize div boxy.tileSize
  boxy.maxTiles = boxy.tileRun * boxy.tileRun
  boxy.takenTiles.setLen(boxy.maxTiles)
  boxy.atlasTexture = boxy.createAtlasTexture(boxy.atlasSize)

  boxy.addWhiteTile()

  for y in 0 ..< oldTileRun:
    for x in 0 ..< oldTileRun:
      let
        imageTile = oldAtlas.superImage(
          x * boxy.tileSize,
          y * boxy.tileSize,
          boxy.tileSize,
          boxy.tileSize
        )
        index = x + y * oldTileRun
      updateSubImage(
        boxy.atlasTexture,
        (index mod boxy.tileRun) * boxy.tileSize,
        (index div boxy.tileRun) * boxy.tileSize,
        imageTile
      )

proc takeFreeTile(boxy: Boxy): int =
  for index in 0 ..< boxy.maxTiles:
    if not boxy.takenTiles[index]:
      boxy.takenTiles[index] = true
      return index

  boxy.grow()
  boxy.takeFreeTile()

proc removeImage*(boxy: Boxy, key: string) =
  ## Removes an image, does nothing if the image has not been added.
  if key in boxy.entries:
    for tile in boxy.entries[key].tiles:
      if tile.kind == tkIndex:
        boxy.takenTiles[tile.index] = false
    boxy.entries.del(key)

proc addImage*(boxy: Boxy, key: string, image: Image) =
  boxy.removeImage(key)

  var imageInfo: ImageInfo
  imageInfo.width = image.width
  imageInfo.height = image.height

  if image.isOneColor():
    imageInfo.oneColor = image[0, 0].color
  else:
    # Split the image into tiles.
    for y in 0 ..< boxy.tileHeight(imageInfo):
      for x in 0 ..< boxy.tileWidth(imageInfo):
        let tileImage = image.superImage(
          x * boxy.tileSize, y * boxy.tileSize, boxy.tileSize, boxy.tileSize
        )
        if tileImage.isOneColor():
          let tileColor = tileImage[0, 0].color
          imageInfo.tiles.add(TileInfo(kind: tkColor, color: tileColor))
        else:
          let index = boxy.takeFreeTile()
          imageInfo.tiles.add(TileInfo(kind: tkIndex, index: index))
          updateSubImage(
            boxy.atlasTexture,
            (index mod boxy.tileRun) * boxy.tileSize,
            (index div boxy.tileRun) * boxy.tileSize,
            tileImage
          )
          # Reminder: This does not set mipmaps (used for text, should it?)

  boxy.entries[key] = imageInfo

proc checkBatch(boxy: Boxy) {.inline.} =
  if boxy.quadCount == boxy.quadsPerBatch:
    # This batch is full, draw and start a new batch.
    boxy.draw()

proc setVert(buf: var seq[float32], i: int, v: Vec2) =
  buf[i * 2 + 0] = v.x
  buf[i * 2 + 1] = v.y

proc setVertColor(buf: var seq[uint8], i: int, rgbx: ColorRGBX) =
  buf[i * 4 + 0] = rgbx.r
  buf[i * 4 + 1] = rgbx.g
  buf[i * 4 + 2] = rgbx.b
  buf[i * 4 + 3] = rgbx.a

proc drawQuad(
  boxy: Boxy,
  verts: array[4, Vec2],
  uvs: array[4, Vec2],
  colors: array[4, Color]
) =
  boxy.checkBatch()

  let offset = boxy.quadCount * 4
  boxy.positions.data.setVert(offset + 0, verts[0])
  boxy.positions.data.setVert(offset + 1, verts[1])
  boxy.positions.data.setVert(offset + 2, verts[2])
  boxy.positions.data.setVert(offset + 3, verts[3])

  boxy.uvs.data.setVert(offset + 0, uvs[0])
  boxy.uvs.data.setVert(offset + 1, uvs[1])
  boxy.uvs.data.setVert(offset + 2, uvs[2])
  boxy.uvs.data.setVert(offset + 3, uvs[3])

  boxy.colors.data.setVertColor(offset + 0, colors[0].asRgbx())
  boxy.colors.data.setVertColor(offset + 1, colors[1].asRgbx())
  boxy.colors.data.setVertColor(offset + 2, colors[2].asRgbx())
  boxy.colors.data.setVertColor(offset + 3, colors[3].asRgbx())

  inc boxy.quadCount

proc drawUvRect(boxy: Boxy, at, to, uvAt, uvTo: Vec2, color: Color) =
  ## Adds an image rect with a path to an ctx
  ## at, to, uvAt, uvTo are all in pixels
  let
    at = boxy.mat * at
    to = boxy.mat * to
    posQuad = [
      vec2(at.x, to.y),
      vec2(to.x, to.y),
      vec2(to.x, at.y),
      vec2(at.x, at.y),
    ]
    uvAt = uvAt / boxy.atlasSize.float32
    uvTo = uvTo / boxy.atlasSize.float32
    uvQuad = [
      vec2(uvAt.x, uvTo.y),
      vec2(uvTo.x, uvTo.y),
      vec2(uvTo.x, uvAt.y),
      vec2(uvAt.x, uvAt.y),
    ]
    colorQuad = [color, color, color, color]

  boxy.drawQuad(posQuad, uvQuad, colorQuad)

proc drawImage*(
  boxy: Boxy,
  key: string,
  pos: Vec2,
  tintColor = color(1, 1, 1, 1)
) =
  ## Draws image at pos from top-left. The image should have already been added.
  let imageInfo = boxy.entries[key]
  if imageInfo.tiles.len == 0:
    if imageInfo.oneColor == color(0, 0, 0, 0):
      return # Don't draw anything if the image is transparent.
    # Draw the color rect
    boxy.drawUvRect(
      pos,
      pos + vec2(imageInfo.width, imageInfo.height),
      vec2(boxy.tileSize / 2, boxy.tileSize / 2),
      vec2(boxy.tileSize / 2, boxy.tileSize / 2),
      (imageInfo.oneColor * tintColor)
    )
  else:
    var i = 0
    for y in 0 ..< boxy.tileHeight(imageInfo):
      for x in 0 ..< boxy.tileWidth(imageInfo):
        let
          tile = imageInfo.tiles[i]
          posAt = pos + vec2(x * boxy.tileSize, y * boxy.tileSize)
        case tile.kind:
        of tkIndex:
          let
            uvAt = vec2(
              (tile.index mod boxy.tileRun) * boxy.tileSize,
              (tile.index div boxy.tileRun) * boxy.tileSize
            )
          boxy.drawUvRect(
            posAt,
            posAt + vec2(boxy.tileSize, boxy.tileSize),
            uvAt,
            uvAt + vec2(boxy.tileSize, boxy.tileSize),
            tintColor
          )
        of tkColor:
          if tile.color != color(0, 0, 0, 0):
            var to = posAt
            # The image may not be a full tile wide
            to.x += min(boxy.tileSize.float32, imageInfo.width.float32)
            to.y += min(boxy.tileSize.float32, imageInfo.height.float32)
            boxy.drawUvRect(
              posAt,
              to,
              vec2(boxy.tileSize / 2, boxy.tileSize / 2),
              vec2(boxy.tileSize / 2, boxy.tileSize / 2),
              (tile.color * tintColor)
            )
        inc i
    assert i == imageInfo.tiles.len

proc clearMask*(boxy: Boxy) =
  ## Sets mask off (actually fills the mask with white).
  if not boxy.frameBegun:
    raise newException(BoxyError, "beginFrame has not been called")

  boxy.draw()

  boxy.setUpMaskFramebuffer()

  glClearColor(1, 1, 1, 1)
  glClear(GL_COLOR_BUFFER_BIT)

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

proc beginMask*(boxy: Boxy) =
  ## Starts drawing into a mask.
  if not boxy.frameBegun:
    raise newException(BoxyError, "beginFrame has not been called")
  if boxy.maskBegun:
    raise newException(BoxyError, "beginMask has already been called")

  boxy.maskBegun = true

  boxy.draw()

  inc boxy.maskTextureWrite
  boxy.maskTextureRead = boxy.maskTextureWrite - 1
  if boxy.maskTextureWrite >= boxy.maskTextures.len:
    boxy.addMaskTexture(boxy.frameSize)

  boxy.setUpMaskFramebuffer()
  glViewport(0, 0, boxy.frameSize.x.GLint, boxy.frameSize.y.GLint)

  glClearColor(0, 0, 0, 0)
  glClear(GL_COLOR_BUFFER_BIT)

  boxy.activeShader = boxy.maskShader

proc endMask*(boxy: Boxy) =
  ## Stops drawing into the mask.
  if boxy.maskBegun:
    raise newException(BoxyError, "beginMask has already been called")

  boxy.maskBegun = false

  boxy.draw()

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

  boxy.maskTextureRead = boxy.maskTextureWrite
  boxy.activeShader = boxy.atlasShader

proc popMask*(boxy: Boxy) =
  boxy.draw()

  dec boxy.maskTextureWrite
  boxy.maskTextureRead = boxy.maskTextureWrite

proc beginFrame*(boxy: Boxy, frameSize: Vec2, proj: Mat4) =
  ## Starts a new frame.
  if boxy.frameBegun:
    raise newException(BoxyError, "beginFrame has already been called")

  boxy.frameBegun = true
  boxy.proj = proj

  if boxy.maskTextures[0].width != frameSize.x.int32 or
    boxy.maskTextures[0].height != frameSize.y.int32:
    # Resize all of the masks.
    boxy.frameSize = frameSize
    for i in 0 ..< boxy.maskTextures.len:
      boxy.maskTextures[i].width = frameSize.x.int32
      boxy.maskTextures[i].height = frameSize.y.int32
      if i > 0:
        # Never resize the 0th mask because its just white.
        bindTextureData(boxy.maskTextures[i], nil)

  glViewport(0, 0, boxy.frameSize.x.GLint, boxy.frameSize.y.GLint)

  glClearColor(0, 0, 0, 0)
  glClear(GL_COLOR_BUFFER_BIT)

  boxy.clearMask()

proc beginFrame*(boxy: Boxy, frameSize: Vec2) {.inline.} =
  beginFrame(
    boxy,
    frameSize,
    ortho(0.float32, frameSize.x, frameSize.y, 0, -1000, 1000)
  )

proc endFrame*(boxy: Boxy) =
  ## Ends a frame.
  if not boxy.frameBegun:
    raise newException(BoxyError, "beginFrame has not been called")
  if boxy.maskTextureRead != 0:
    raise newException(BoxyError, "Not all masks have been popped")
  if boxy.maskTextureWrite != 0:
    raise newException(BoxyError, "Not all masks have been popped")

  boxy.frameBegun = false
  boxy.draw()

proc translate*(boxy: Boxy, v: Vec2) =
  ## Translate the internal transform.
  boxy.mat = boxy.mat * translate(vec3(v))

proc rotate*(boxy: Boxy, angle: float32) =
  ## Rotates the internal transform.
  boxy.mat = boxy.mat * rotateZ(angle)

proc scale*(boxy: Boxy, scale: float32) =
  ## Scales the internal transform.
  boxy.mat = boxy.mat * scale(vec3(scale))

proc scale*(boxy: Boxy, scale: Vec2) =
  ## Scales the internal transform.
  boxy.mat = boxy.mat * scale(vec3(scale.x, scale.y, 1))

proc saveTransform*(boxy: Boxy) =
  ## Pushes a transform onto the stack.
  boxy.mats.add boxy.mat

proc restoreTransform*(boxy: Boxy) =
  ## Pops a transform off the stack.
  boxy.mat = boxy.mats.pop()

proc clearTransform*(boxy: Boxy) =
  ## Clears transform and transform stack.
  boxy.mat = mat4()
  boxy.mats.setLen(0)

proc fromScreen*(boxy: Boxy, windowFrame: Vec2, v: Vec2): Vec2 =
  ## Takes a point from screen and translates it to point inside the current transform.
  (boxy.mat.inverse() * vec3(v.x, windowFrame.y - v.y, 0)).xy

proc toScreen*(boxy: Boxy, windowFrame: Vec2, v: Vec2): Vec2 =
  ## Takes a point from current transform and translates it to screen.
  result = (boxy.mat * vec3(v.x, v.y, 1)).xy
  result.y = -result.y + windowFrame.y

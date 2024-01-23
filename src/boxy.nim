import bitty, boxy/blends, boxy/blurs, boxy/buffers, boxy/shaders,
    boxy/spreads, boxy/textures, bumpy, chroma, hashes, opengl, os, pixie, sets,
    shady, strutils, tables, vmath

export pixie

const
  quadLimit = 10_921 # 6 indices per quad, ensure indices stay in uint16 range
  tileMargin = 2     # 1 pixel on both sides of the tile.

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
    size: IVec2               ## Size of the image in pixels.
    tiles: seq[seq[TileInfo]] ## The tile info for this image.
    oneColor: Color           ## If tiles = [] then this is the image's color.

  Boxy* = ref object
    atlasShader, maskShader, blendShader, activeShader: Shader
    blurXShader, blurYShader: Shader
    spreadXShader, spreadYShader: Shader
    atlasTexture, tmpTexture: Texture
    layerNum: int                    ## Index into layer textures for writing.
    layerTextures: seq[Texture]      ## Layers array for pushing and popping.
    atlasSize: int                   ## Size x size dimensions of the atlas.
    quadCount: int                   ## Number of quads drawn so far in this batch.
    quadsPerBatch: int               ## Max quads in a batch before issuing an OpenGL call.
    mat: Mat3                        ## The current matrix.
    mats: seq[Mat3]                  ## The matrix stack.
    entries: Table[string, ImageInfo]
    entriesBuffered: HashSet[string] ## Entires used by not flushed yet.
    tileSize: int
    maxTiles: int
    tileRun: int
    takenTiles: BitArray             ## Flag for if the tile is taken or not.
    proj: Mat4
    frameSize: IVec2                 ## Dimensions of the window frame.
    vertexArrayId, layerFramebufferId: GLuint
    frameBegun: bool
    maxAtlasSize: int

    # Buffer data for OpenGL
    positions: tuple[buffer: Buffer, data: seq[float32]]
    colors: tuple[buffer: Buffer, data: seq[uint8]]
    uvs: tuple[buffer: Buffer, data: seq[float32]]
    indices: tuple[buffer: Buffer, data: seq[uint16]]

proc vec2(x, y: SomeNumber): Vec2 {.inline.} =
  ## Integer short cut for creating vectors.
  vec2(x.float32, y.float32)

proc `*`(a, b: Color): Color {.inline.} =
  result.r = a.r * b.r
  result.g = a.g * b.g
  result.b = a.b * b.b
  result.a = a.a * b.a

proc tileWidth(boxy: Boxy, width: int): int {.inline.} =
  ## Number of tiles wide.
  ceil(width / boxy.tileSize).int

proc tileHeight(boxy: Boxy, height: int): int {.inline.} =
  ## Number of tiles high.
  ceil(height / boxy.tileSize).int

proc readAtlas*(boxy: Boxy): Image =
  ## Read the current atlas content.
  boxy.atlasTexture.readImage()

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

proc drawVertexArray(boxy: Boxy) =
  glBindVertexArray(boxy.vertexArrayId)
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

proc flush*(boxy: Boxy) =
  ## Flips - draws current buffer and starts a new one.
  if boxy.quadCount == 0:
    return

  boxy.entriesBuffered.clear()
  boxy.upload()

  glUseProgram(boxy.activeShader.programId)

  boxy.activeShader.setUniform("proj", boxy.proj)

  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, boxy.atlasTexture.textureId)
  boxy.activeShader.setUniform("atlasTex", 0)

  boxy.activeShader.bindUniforms()

  boxy.drawVertexArray()

proc drawToTexture(boxy: Boxy, texture: Texture) =
  glBindFramebuffer(GL_FRAMEBUFFER, boxy.layerFramebufferId)
  glFramebufferTexture2D(
    GL_FRAMEBUFFER,
    GL_COLOR_ATTACHMENT0,
    GL_TEXTURE_2D,
    texture.textureId,
    0
  )

proc createAtlasTexture(boxy: Boxy, size: int): Texture =
  result = Texture()
  result.width = size.int32
  result.height = size.int32
  result.componentType = GL_UNSIGNED_BYTE
  result.format = GL_RGBA
  result.internalFormat = GL_RGBA8
  result.minFilter = minLinear
  result.magFilter = magLinear
  bindTextureData(result, nil)

proc addLayerTexture(boxy: Boxy, frameSize = ivec2(1, 1)) =
  # Must be >0 for framebuffer creation below
  # Set to real value in beginFrame
  let layerTexture = Texture()
  layerTexture.width = frameSize.x.int32
  layerTexture.height = frameSize.y.int32
  layerTexture.componentType = GL_UNSIGNED_BYTE
  layerTexture.format = GL_RGBA
  layerTexture.internalFormat = GL_RGBA8
  layerTexture.minFilter = minLinear
  layerTexture.magFilter = magLinear
  bindTextureData(layerTexture, nil)
  boxy.layerTextures.add(layerTexture)

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
  tileSize = 32 - tileMargin,
  quadsPerBatch = 1024
): Boxy =
  ## Creates a new Boxy.
  if atlasSize mod (tileSize + tileMargin) != 0:
    raise newException(BoxyError, "Atlas size must be a multiple of (tile size + 2)")
  if quadsPerBatch > quadLimit:
    raise newException(BoxyError, "Quads per batch cannot exceed " & $quadLimit)

  result = Boxy()
  result.atlasSize = atlasSize
  result.tileSize = tileSize
  result.quadsPerBatch = quadsPerBatch
  result.mat = mat3()
  result.mats = newSeq[Mat3]()

  result.tileRun = result.atlasSize div (result.tileSize + tileMargin)
  result.maxTiles = result.tileRun * result.tileRun
  result.takenTiles = newBitArray(result.maxTiles)
  result.atlasTexture = result.createAtlasTexture(atlasSize)

  result.layerNum = -1

  when defined(emscripten):
    result.atlasShader = newShaderStatic(
      "glsl/100/atlas.vert",
      "glsl/100/atlas.frag"
    )
    result.maskShader = newShaderStatic(
      "glsl/100/atlas.vert",
      "glsl/100/mask.frag"
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
    result.blendShader = newShader(
      ("atlasVert", toGLSL(atlasVert)),
      ("blendingMain", toGLSL(blendingMain))
    )
    result.blurXShader = newShader(
      ("atlasVert", toGLSL(atlasVert)),
      ("blendingMain", toGLSL(blurXMain))
    )
    result.blurYShader = newShader(
      ("atlasVert", toGLSL(atlasVert)),
      ("blendingMain", toGLSL(blurYMain))
    )

    result.spreadXShader = newShader(
      ("atlasVert", toGLSL(atlasVert)),
      ("spreadXMain", toGLSL(spreadXMain))
    )
    result.spreadYShader = newShader(
      ("atlasVert", toGLSL(atlasVert)),
      ("spreadYMain", toGLSL(spreadYMain))
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

  let status = glCheckFramebufferStatus(GL_FRAMEBUFFER)
  if status != GL_FRAMEBUFFER_COMPLETE:
    raise newException(
      BoxyError,
      "Something wrong with layer framebuffer: " & $toHex(status.int32, 4)
    )

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

  # Enable premultiplied alpha blending
  glEnable(GL_BLEND)
  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)

  result.addWhiteTile()

  var maxAtlasSize: int32
  glGetIntegerv(GL_MAX_TEXTURE_SIZE, maxAtlasSize.addr)
  result.maxAtlasSize = maxAtlasSize

  if result.maxAtlasSize < result.atlasSize:
    raise newException(
      BoxyError,
      "Requested atlas texture is larger then max supported size: " &
      $result.maxAtlasSize
    )

proc grow(boxy: Boxy) =
  ## Grows the atlas size by 2 (growing area by 4).

  if boxy.atlasSize == boxy.maxAtlasSize:
    raise newException(
      BoxyError,
      "Can't grow boxy atlas texture, max supported size reached: " &
      $boxy.maxAtlasSize
    )

  boxy.flush()

  # Read old atlas content
  let
    oldAtlas = boxy.readAtlas()
    oldTileRun = boxy.tileRun

  boxy.atlasSize *= 2
  if boxy.atlasSize > boxy.maxAtlasSize:
    boxy.atlasSize = boxy.maxAtlasSize

  boxy.tileRun = boxy.atlasSize div (boxy.tileSize + tileMargin)
  boxy.maxTiles = boxy.tileRun * boxy.tileRun
  boxy.takenTiles.setLen(boxy.maxTiles)
  boxy.atlasTexture = boxy.createAtlasTexture(boxy.atlasSize)

  boxy.addWhiteTile()

  for y in 0 ..< oldTileRun:
    for x in 0 ..< oldTileRun:
      let
        imageTile = oldAtlas.superImage(
          x * (boxy.tileSize + tileMargin),
          y * (boxy.tileSize + tileMargin),
          boxy.tileSize + tileMargin,
          boxy.tileSize + tileMargin
        )
        index = x + y * oldTileRun
      updateSubImage(
        boxy.atlasTexture,
        (index mod boxy.tileRun) * (boxy.tileSize + tileMargin),
        (index div boxy.tileRun) * (boxy.tileSize + tileMargin),
        imageTile
      )

proc takeFreeTile(boxy: Boxy): int =
  let (found, index) = boxy.takenTiles.firstFalse
  if found:
    boxy.takenTiles.unsafeSetTrue(index)
    return index

  boxy.grow()
  boxy.takeFreeTile()

proc removeImage*(boxy: Boxy, key: string) =
  ## Removes an image, does nothing if the image has not been added.
  if key in boxy.entriesBuffered:
    raise newException(
      BoxyError,
      "Attempting to remove an image that is set to be drawn"
    )

  if key in boxy.entries:
    for tileLevel in boxy.entries[key].tiles:
      for tile in tileLevel:
        if tile.kind == tkIndex:
          boxy.takenTiles.unsafeSetFalse(tile.index)
    boxy.entries.del(key)

proc addImage*(boxy: Boxy, key: string, image: Image, genMipmaps = true) =
  if key in boxy.entriesBuffered:
    raise newException(
      BoxyError,
      "Attempting to modify an image that is already set to be drawn " &
      "(try using a unique key?)"
    )

  boxy.removeImage(key)

  boxy.entriesBuffered.incl(key)

  var imageInfo: ImageInfo
  imageInfo.size = ivec2(image.width.int32, image.height.int32)

  if image.isOneColor():
    imageInfo.oneColor = image[0, 0].color
  else:
    var
      image = image
      level = 0
    while true:
      imageInfo.tiles.add(@[])

      # Split the image into tiles.
      for y in 0 ..< boxy.tileHeight(image.height):
        for x in 0 ..< boxy.tileWidth(image.width):
          let tileImage = image.superImage(
            x * boxy.tileSize - tileMargin div 2,
            y * boxy.tileSize - tileMargin div 2,
            boxy.tileSize + tileMargin,
            boxy.tileSize + tileMargin
          )
          if tileImage.isOneColor():
            let tileColor = tileImage[0, 0].color
            imageInfo.tiles[level].add(
              TileInfo(kind: tkColor, color: tileColor)
            )
          else:
            let index = boxy.takeFreeTile()
            imageInfo.tiles[level].add(TileInfo(kind: tkIndex, index: index))
            updateSubImage(
              boxy.atlasTexture,
              (index mod boxy.tileRun) * (boxy.tileSize + tileMargin),
              (index div boxy.tileRun) * (boxy.tileSize + tileMargin),
              tileImage
            )

      if image.width <= 1 or image.height <= 1:
        break

      if not genMipmaps:
        break

      image = image.minifyBy2()
      inc level

  boxy.entries[key] = imageInfo

proc getImageSize*(boxy: Boxy, key: string): IVec2 =
  ## Return the size of an inserted image.
  boxy.entries[key].size

proc checkBatch(boxy: Boxy) {.inline.} =
  if boxy.quadCount == boxy.quadsPerBatch:
    # This batch is full, draw and start a new batch.
    boxy.flush()

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
  tints: array[4, Color]
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

  boxy.colors.data.setVertColor(offset + 0, tints[0].asRgbx())
  boxy.colors.data.setVertColor(offset + 1, tints[1].asRgbx())
  boxy.colors.data.setVertColor(offset + 2, tints[2].asRgbx())
  boxy.colors.data.setVertColor(offset + 3, tints[3].asRgbx())

  inc boxy.quadCount

proc drawUvRect(boxy: Boxy, at, to, uvAt, uvTo: Vec2, tint: Color) =
  ## Adds an image rect with a path to an ctx
  ## at, to, uvAt, uvTo are all in pixels
  let
    posQuad = [
      boxy.mat * vec2(at.x, to.y),
      boxy.mat * vec2(to.x, to.y),
      boxy.mat * vec2(to.x, at.y),
      boxy.mat * vec2(at.x, at.y),
    ]
    uvAt = uvAt / boxy.atlasSize.float32
    uvTo = uvTo / boxy.atlasSize.float32
    uvQuad = [
      vec2(uvAt.x, uvTo.y),
      vec2(uvTo.x, uvTo.y),
      vec2(uvTo.x, uvAt.y),
      vec2(uvAt.x, uvAt.y),
    ]
    tints = [tint, tint, tint, tint]

  boxy.drawQuad(posQuad, uvQuad, tints)

proc drawRect*(
  boxy: Boxy,
  rect: Rect,
  color: Color
) =
  if color != color(0, 0, 0, 0):
    boxy.drawUvRect(
      rect.xy,
      rect.xy + rect.wh,
      vec2(boxy.tileSize / 2, boxy.tileSize / 2),
      vec2(boxy.tileSize / 2, boxy.tileSize / 2),
      color
    )

proc readyTmpTexture(boxy: Boxy) =
  ## Makes sure boxy.tmpTexture is ready to be used.
  # Create extra tmp texture if needed
  if boxy.tmpTexture == nil:
    boxy.tmpTexture = Texture()
    boxy.tmpTexture.width = 1
    boxy.tmpTexture.height = 1
    boxy.tmpTexture.componentType = GL_UNSIGNED_BYTE
    boxy.tmpTexture.format = GL_RGBA
    boxy.tmpTexture.internalFormat = GL_RGBA8
    boxy.tmpTexture.minFilter = minLinear
    boxy.tmpTexture.magFilter = magLinear
  # Resize extra blend texture if needed
  if boxy.tmpTexture.width != boxy.frameSize.x.int32 or
    boxy.tmpTexture.height != boxy.frameSize.y.int32:
    boxy.tmpTexture.width = boxy.frameSize.x.int32
    boxy.tmpTexture.height = boxy.frameSize.y.int32
    bindTextureData(boxy.tmpTexture, nil)

proc clearColor(boxy: Boxy) =
  glViewport(0, 0, boxy.frameSize.x.GLint, boxy.frameSize.y.GLint)
  glClearColor(0, 0, 0, 0)
  glClear(GL_COLOR_BUFFER_BIT)

proc pushLayer*(boxy: Boxy) =
  ## Starts drawing into a new layer.
  if not boxy.frameBegun:
    raise newException(BoxyError, "beginFrame has not been called")

  if boxy.layerFramebufferId.int == 0:
    # Create layer framebuffer
    glGenFramebuffers(1, boxy.layerFramebufferId.addr)

  boxy.flush()
  inc boxy.layerNum

  if boxy.layerNum >= boxy.layerTextures.len:
    boxy.addLayerTexture(boxy.frameSize)

  boxy.drawToTexture(boxy.layerTextures[boxy.layerNum])
  glViewport(0, 0, boxy.frameSize.x.GLint, boxy.frameSize.y.GLint)

  glClearColor(0, 0, 0, 0)
  glClear(GL_COLOR_BUFFER_BIT)

proc popLayer*(
  boxy: Boxy,
  tint = color(1, 1, 1, 1),
  blendMode: BlendMode = NormalBlend
) =
  ## Pops the layer and draws with tint and blend.
  if boxy.layerNum == -1:
    raise newException(BoxyError, "popLayer called without pushLayer")

  boxy.flush()

  let layerTexture = boxy.layerTextures[boxy.layerNum]
  dec boxy.layerNum

  glViewport(0, 0, boxy.frameSize.x.GLint, boxy.frameSize.y.GLint)
  let savedAtlasTexture = boxy.atlasTexture

  if boxy.layerNum == -1:
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
  else:
    boxy.drawToTexture(boxy.layerTextures[boxy.layerNum])

  if blendMode in {NormalBlend, MaskBlend, ScreenBlend}:
    # Can use OpenGL blending mode,
    if blendMode == NormalBlend:
      boxy.atlasTexture = layerTexture
      glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
      boxy.activeShader = boxy.atlasShader
    elif blendMode == MaskBlend:
      boxy.atlasTexture = layerTexture
      glBlendFunc(GL_ZERO, GL_SRC_COLOR)
      boxy.activeShader = boxy.maskShader
    elif blendMode == ScreenBlend:
      boxy.atlasTexture = layerTexture
      glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR)
      boxy.activeShader = boxy.atlasShader

    boxy.drawUvRect(
      at = vec2(0, 0),
      to = boxy.frameSize.vec2,
      uvAt = vec2(0, boxy.atlasSize.float32),
      uvTo = vec2(boxy.atlasSize.float32, 0),
      tint = tint
    )
    boxy.flush()

  else:
    boxy.readyTmpTexture()
    boxy.drawToTexture(boxy.tmpTexture)
    boxy.clearColor()

    let
      srcTexture = layerTexture
      dstTexture = boxy.layerTextures[boxy.layerNum]

    # Can use OpenGL blending mode
    boxy.drawUvRect(
      at = vec2(0, 0),
      to = boxy.frameSize.vec2,
      uvAt = vec2(0, boxy.atlasSize.float32),
      uvTo = vec2(boxy.atlasSize.float32, 0),
      tint = tint
    )

    boxy.upload()

    glUseProgram(boxy.blendShader.programId)

    boxy.blendShader.setUniform("proj", boxy.proj)

    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, srcTexture.textureId)
    boxy.blendShader.setUniform("srcTexture", 0)

    glActiveTexture(GL_TEXTURE1)
    glBindTexture(GL_TEXTURE_2D, dstTexture.textureId)
    boxy.blendShader.setUniform("dstTexture", 1)

    boxy.blendShader.setUniform("blendMode", blendMode.ord.int32)

    boxy.blendShader.bindUniforms()

    boxy.drawVertexArray()

    # For debugging:
    # boxy.tmpTexture.writeFile("resTexture.png")
    # boxy.srcTexture.writeFile("srcTexture.png")
    # boxy.dstTexture.writeFile("dstTexture.png")

    swap boxy.layerTextures[boxy.layerNum], boxy.tmpTexture

  # Reset everything back.
  boxy.atlasTexture = savedAtlasTexture
  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
  boxy.activeShader = boxy.atlasShader

proc blurEffect(
  boxy: Boxy,
  radius: float32,
  tint: Color,
  offset: Vec2,
  readTexture: Texture,
  writeTexture: Texture
) =
  ## Blurs the current layer
  if boxy.layerNum == -1:
    raise newException(BoxyError, "blurEffect called without pushLayer")

  boxy.flush()

  # blurX
  boxy.readyTmpTexture()
  boxy.drawToTexture(boxy.tmpTexture)
  boxy.clearColor()

  glUseProgram(boxy.blurXShader.programId)
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, readTexture.textureId)
  boxy.blurXShader.setUniform("srcTexture", 0)
  boxy.blurXShader.setUniform("proj", boxy.proj)
  boxy.blurXShader.setUniform("pixelScale", 1 / boxy.frameSize.x.float32)
  boxy.blurXShader.setUniform("blurRadius", radius)
  boxy.blurXShader.bindUniforms()

  boxy.drawUvRect(
    at = vec2(0, 0),
    to = boxy.frameSize.vec2,
    uvAt = vec2(0, boxy.atlasSize.float32),
    uvTo = vec2(boxy.atlasSize.float32, 0),
    tint = color(1, 1, 1, 1)
  )
  boxy.upload()
  boxy.drawVertexArray()

  # blurY
  boxy.drawToTexture(writeTexture)
  boxy.clearColor()

  glUseProgram(boxy.blurYShader.programId)
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, boxy.tmpTexture.textureId)
  boxy.blurYShader.setUniform("srcTexture", 0)
  boxy.blurYShader.setUniform("proj", boxy.proj)
  boxy.blurYShader.setUniform("pixelScale", 1 / boxy.frameSize.y.float32)
  boxy.blurYShader.setUniform("blurRadius", radius)
  boxy.blurYShader.bindUniforms()

  boxy.drawUvRect(
    at = offset,
    to = offset + boxy.frameSize.vec2,
    uvAt = vec2(0, boxy.atlasSize.float32),
    uvTo = vec2(boxy.atlasSize.float32, 0),
    tint = tint
  )
  boxy.upload()
  boxy.drawVertexArray()

  # For debugging:
  # boxy.tmpTexture.writeFile("blurX.png")
  # texture.writeFile("blurY.png")

proc blurEffect*(boxy: Boxy, radius: float32) =
  ## Blurs the current layer
  let layerTexture = boxy.layerTextures[boxy.layerNum]
  boxy.blurEffect(
    radius,
    color(1, 1, 1, 1),
    vec2(0, 0),
    layerTexture,
    layerTexture
  )

proc dropShadowEffect*(boxy: Boxy, tint: Color, offset: Vec2, radius, spread: float32) =
  ## Drop shadows the current layer
  if boxy.layerNum == -1:
    raise newException(BoxyError, "shadowLayer called without pushLayer")

  boxy.flush()

  boxy.pushLayer()

  let
    shadowLayer = boxy.layerTextures[boxy.layerNum]
    mainLayer = boxy.layerTextures[boxy.layerNum - 1]

  # spreadX
  boxy.readyTmpTexture()
  boxy.drawToTexture(boxy.tmpTexture)
  boxy.clearColor()

  glUseProgram(boxy.spreadXShader.programId)
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, mainLayer.textureId)
  boxy.spreadXShader.setUniform("srcTexture", 0)
  boxy.spreadXShader.setUniform("proj", boxy.proj)
  boxy.spreadXShader.setUniform("pixelScale", 1 / boxy.frameSize.x.float32)
  boxy.spreadXShader.setUniform("radius", spread)
  boxy.spreadXShader.bindUniforms()

  boxy.drawUvRect(
    at = vec2(0, 0),
    to = boxy.frameSize.vec2,
    uvAt = vec2(0, boxy.atlasSize.float32),
    uvTo = vec2(boxy.atlasSize.float32, 0),
    tint = color(1, 1, 1, 1)
  )
  boxy.upload()
  boxy.drawVertexArray()

  # spreadY
  boxy.drawToTexture(shadowLayer)
  boxy.clearColor()

  glUseProgram(boxy.spreadYShader.programId)
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, boxy.tmpTexture.textureId)
  boxy.spreadYShader.setUniform("srcTexture", 0)
  boxy.spreadYShader.setUniform("proj", boxy.proj)
  boxy.spreadYShader.setUniform("pixelScale", 1 / boxy.frameSize.y.float32)
  boxy.spreadYShader.setUniform("radius", spread)
  boxy.spreadYShader.bindUniforms()

  boxy.drawUvRect(
    at = vec2(0, 0) + offset,
    to = boxy.frameSize.vec2 + offset,
    uvAt = vec2(0, boxy.atlasSize.float32),
    uvTo = vec2(boxy.atlasSize.float32, 0),
    tint = color(1, 1, 1, 1)
  )
  boxy.upload()
  boxy.drawVertexArray()

  boxy.blurEffect(radius, tint, offset, shadowLayer, shadowLayer)

  swap(boxy.layerTextures[boxy.layerNum], boxy.layerTextures[boxy.layerNum - 1])
  boxy.popLayer()

  # For debugging:
  # boxy.tmpTexture.writeFile("spreadX.png")
  # mainLayer.writeFile("spreadY.png")

proc beginFrame*(boxy: Boxy, frameSize: IVec2, proj: Mat4, clearFrame = true) =
  ## Starts a new frame.
  if boxy.frameBegun:
    raise newException(BoxyError, "beginFrame has already been called")

  boxy.frameBegun = true
  boxy.proj = proj
  boxy.frameSize = frameSize

  # Resize all of the layers.
  for texture in boxy.layerTextures:
    if texture.width != frameSize.x or texture.height != frameSize.y:
      texture.width = frameSize.x
      texture.height = frameSize.y
      bindTextureData(texture, nil)

  glViewport(0, 0, boxy.frameSize.x, boxy.frameSize.y)

  if clearFrame:
    glClearColor(0, 0, 0, 0)
    glClear(GL_COLOR_BUFFER_BIT)

proc beginFrame*(boxy: Boxy, frameSize: IVec2, clearFrame = true) {.inline.} =
  beginFrame(
    boxy,
    frameSize,
    ortho(0.float32, frameSize.x.float32, frameSize.y.float32, 0, -1000, 1000),
    clearFrame
  )

proc endFrame*(boxy: Boxy) =
  ## Ends a frame.
  if not boxy.frameBegun:
    raise newException(BoxyError, "beginFrame has not been called")
  if boxy.layerNum != -1:
    raise newException(BoxyError, "Not all layers have been popped")

  boxy.frameBegun = false
  boxy.flush()

proc applyTransform*(boxy: Boxy, m: Mat3) =
  ## Applies transform to the internal transform.
  boxy.mat = boxy.mat * m

proc setTransform*(boxy: Boxy, m: Mat3) =
  ## Sets the internal transform.
  boxy.mat = m

proc getTransform*(boxy: Boxy): Mat3 =
  ## Gets the internal transform.
  boxy.mat

proc translate*(boxy: Boxy, v: Vec2) =
  ## Translate the internal transform.
  boxy.mat = boxy.mat * translate(v)

proc rotate*(boxy: Boxy, angle: float32) =
  ## Rotates the internal transform.
  boxy.mat = boxy.mat * rotate(angle)

proc scale*(boxy: Boxy, scale: Vec2) =
  ## Scales the internal transform.
  boxy.mat = boxy.mat * scale(scale)

proc scale*(boxy: Boxy, scale: float32) {.inline.} =
  ## Scales the internal transform.
  boxy.scale(vec2(scale))

proc saveTransform*(boxy: Boxy) =
  ## Pushes a transform onto the stack.
  boxy.mats.add boxy.mat

proc restoreTransform*(boxy: Boxy) =
  ## Pops a transform off the stack.
  boxy.mat = boxy.mats.pop()

proc clearTransform*(boxy: Boxy) =
  ## Clears transform and transform stack.
  boxy.mat = mat3()
  boxy.mats.setLen(0)

proc fromScreen*(boxy: Boxy, windowFrame: Vec2, v: Vec2): Vec2 =
  ## Takes a point from screen and translates it to point inside the current transform.
  (boxy.mat.inverse() * vec3(v.x, windowFrame.y - v.y, 0)).xy

proc toScreen*(boxy: Boxy, windowFrame: Vec2, v: Vec2): Vec2 =
  ## Takes a point from current transform and translates it to screen.
  result = (boxy.mat * vec3(v.x, v.y, 1)).xy
  result.y = -result.y + windowFrame.y

proc drawImage*(
  boxy: Boxy,
  key: string,
  pos: Vec2,
  tint = color(1, 1, 1, 1)
) =
  ## Draws image at pos from top-left.
  ## The image should have already been added.
  let imageInfo = boxy.entries[key]
  if imageInfo.tiles.len == 0:
    boxy.drawRect(
      rect(pos, imageInfo.size.vec2),
      imageInfo.oneColor * tint
    )
  else:
    var i = 0
    let
      xVec = vec2(boxy.mat[0, 0], boxy.mat[0, 1])
      yVec = vec2(boxy.mat[0, 1], boxy.mat[1, 1])
      vecMag = max(xVec.length, yVec.length)
      wantLevel = int((-log2(vecMag) + 0.5).floor)
      level = clamp(wantLevel, 0, imageInfo.tiles.len - 1)
      levelPow2 = 2 ^ level
      scale = vec2(levelPow2, levelPow2)
      pos = pos / scale

    boxy.saveTransform()
    boxy.scale(scale)

    var
      width = imageInfo.size.x
      height = imageInfo.size.y
    for _ in 0 ..< level:
      if width mod 2 != 0:
        width = width div 2 + 1
      else:
        width = width div 2
      if height mod 2 != 0:
        height = height div 2 + 1
      else:
        height = height div 2

    for y in 0 ..< boxy.tileHeight(height):
      for x in 0 ..< boxy.tileWidth(width):
        let
          tile = imageInfo.tiles[level][i]
          posAt = pos + vec2(x * boxy.tileSize, y * boxy.tileSize)
        case tile.kind:
        of tkIndex:
          var uvAt = vec2(
            (tile.index mod boxy.tileRun) * (boxy.tileSize + tileMargin),
            (tile.index div boxy.tileRun) * (boxy.tileSize + tileMargin)
          )
          uvAt += tileMargin div 2
          boxy.drawUvRect(
            posAt,
            posAt + vec2(boxy.tileSize, boxy.tileSize),
            uvAt,
            uvAt + vec2(boxy.tileSize, boxy.tileSize),
            tint
          )
        of tkColor:
          if tile.color != color(0, 0, 0, 0):
            # The image may not be a full tile wide
            let wh = vec2(
              min(boxy.tileSize.float32, imageInfo.size.x.float32),
              min(boxy.tileSize.float32, imageInfo.size.y.float32)
            )
            boxy.drawRect(
              rect(posAt, wh),
              tile.color * tint
            )
        inc i

    boxy.restoreTransform()
    assert i == imageInfo.tiles[level].len

proc drawImage*(
  boxy: Boxy,
  key: string,
  rect: Rect,
  tint = color(1, 1, 1, 1)
) =
  ## Draws image at filling the ract.
  ## The image should have already been added.
  let imageInfo = boxy.entries[key]
  boxy.saveTransform()
  let
    scale = rect.wh / imageInfo.size.vec2
    pos = vec2(
      rect.x / scale.x,
      rect.y / scale.y
    )
  boxy.scale(scale)
  boxy.drawImage(key, pos, tint)
  boxy.restoreTransform()

proc drawImage*(
  boxy: Boxy,
  key: string,
  center: Vec2,
  angle: float32,
  tint = color(1, 1, 1, 1),
  scale: float32 = 1
) =
  ## Draws image at center and rotated by angle.
  ## The image should have already been added.
  let imageInfo = boxy.entries[key]
  boxy.saveTransform()
  boxy.translate(center)
  boxy.rotate(angle)
  boxy.scale(vec2(scale, scale))
  boxy.translate(-imageInfo.size.vec2 / 2)
  boxy.drawImage(key, pos = vec2(0, 0), tint)
  boxy.restoreTransform()

proc enterRawOpenGLMode*(boxy: Boxy) =
  # Enter raw OpenGL mode.
  # Used for using boxy with other OpenGL code.
  glEnable(GL_DEPTH_TEST)
  glDepthMask(GL_TRUE)
  glEnable(GL_MULTISAMPLE)
  glEnable(GL_CULL_FACE)
  glCullFace(GL_BACK)
  glFrontFace(GL_CCW)

proc exitRawOpenGLMode*(boxy: Boxy) =
  # Exit raw OpenGL mode.
  # Used for using boxy with other OpenGL code.
  glDisable(GL_DEPTH_TEST)
  glDisable(GL_MULTISAMPLE)
  glDisable(GL_CULL_FACE)
  glUseProgram(boxy.activeShader.programId)

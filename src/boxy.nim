import boxy/allocator, boxy/blends, boxy/blurs, boxy/buffers, boxy/shaders,
    boxy/spreads, boxy/textures, bumpy, chroma, hashes, opengl, pixie, sets,
    shady, strutils, tables, vmath

export atlasVert, atlasMain, maskMain

export pixie

const
  QuadLimit = 10_921 # 6 indices per quad, ensure indices stay in uint16 range
  TileMargin = 16    ## Margin to add around each tile in the atlas.
  WhiteTileKey = "_white_tile_"

type
  BoxyError* = object of ValueError

  ImageInfo = object
    size: IVec2        ## Size of the image in pixels.
    cap: IVec2         ## Capacity of the image in pixels (for growing)
    atlasPos: IVec2    ## Position in the atlas (for non-solid colors)
    isOneColor: bool   ## True if image is a single solid color
    oneColor: Color    ## If isOneColor = true, this is the image's color.

  Boxy* = ref object
    atlasShader, maskShader, blendShader, activeShader: Shader
    blurXShader, blurYShader: Shader
    spreadXShader, spreadYShader: Shader
    atlasTexture*, tmpTexture: Texture
    pendingImages: seq[Image]
    pendingLocations: seq[IVec2]
    tmpFramebuffer: GLuint
    layerNum: int                    ## Index into layer textures for writing.
    layerTextures: seq[Texture]      ## Layers array for pushing and popping.
    layerFramebuffers: seq[GLuint]   ## Attachment targets for layer textures.
    atlasSize: int                   ## Size x size dimensions of the atlas.
    quadCount: int                   ## Number of quads drawn so far in this batch.
    quadsPerBatch: int               ## Max quads in a batch before issuing an OpenGL call.
    mat: Mat3                        ## The current matrix.
    mats: seq[Mat3]                  ## The matrix stack.
    entries: Table[string, ImageInfo]
    entriesBuffered: HashSet[string] ## Entries used but not flushed yet.
    allocator*: SkylineAllocator            ## Texture atlas allocator.
    proj: Mat4
    frameSize: IVec2                 ## Dimensions of the window frame.
    vertexArrayId: GLuint
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
  glDrawElements(
    GL_TRIANGLES,
    boxy.indices.buffer.count.GLint,
    boxy.indices.buffer.componentType,
    nil
  )
  boxy.quadCount = 0

proc uploadImages(boxy: Boxy, uploadImagesGenMips = boxy.atlasTexture.useMipmap) =
  if boxy.pendingLocations.len == 0:
    return

  for i in 0 ..< boxy.pendingLocations.len:
    let pos = boxy.pendingLocations[i]
    updateSubImage(boxy.atlasTexture, pos.x, pos.y, boxy.pendingImages[i], false)

  if uploadImagesGenMips:
    # Aggressive mipmap generation, but faster than CPU scaling, batching makes it worthwhile
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, boxy.atlasTexture.textureId)
    glGenerateMipmap(GL_TEXTURE_2D)

  boxy.pendingLocations.setLen(0)
  boxy.pendingImages.setLen(0)

proc flush*(boxy: Boxy, useAtlas: bool = true, uploadImagesGenMips: bool = true) =
  ## Flips - draws current buffer and starts a new one.
  if boxy.quadCount == 0:
    return

  boxy.entriesBuffered.clear()
  boxy.upload()
  boxy.uploadImages()

  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, boxy.atlasTexture.textureId)

  glUseProgram(boxy.activeShader.programId)
  boxy.activeShader.setUniform("proj", boxy.proj)
  if useAtlas:
    boxy.activeShader.setUniform("atlasTex", 0)
  boxy.activeShader.bindUniforms()

  boxy.drawVertexArray()

proc checkFramebuffer() =
  let status = glCheckFramebufferStatus(GL_FRAMEBUFFER)
  if status != GL_FRAMEBUFFER_COMPLETE:
    raise newException(
      BoxyError,
      "Something wrong with layer framebuffer: " & $toHex(status.int32, 4)
    )

proc drawToTexture(boxy: Boxy, texture: Texture, framebufferId: GLuint) =
  glBindFramebuffer(GL_FRAMEBUFFER, framebufferId)
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
  result.magFilter = filterLinear
  result.minFilter = filterLinear
  result.mipFilter = filterLinear
  result.useMipmap = true
  bindTextureData(result, nil, false)

proc addLayerTexture(boxy: Boxy) =
  # Must be >0 for framebuffer creation below
  # Set to real value in beginFrame
  let layerTexture = Texture()
  layerTexture.width = boxy.frameSize.x.int32
  layerTexture.height = boxy.frameSize.y.int32
  layerTexture.componentType = GL_UNSIGNED_BYTE
  layerTexture.format = GL_RGBA
  layerTexture.internalFormat = GL_RGBA8
  layerTexture.magFilter = filterLinear
  layerTexture.minFilter = filterLinear
  bindTextureData(layerTexture, nil)
  boxy.layerTextures.add(layerTexture)

  var layerFramebufferId: GLuint
  glGenFramebuffers(1, layerFramebufferId.addr)
  boxy.drawToTexture(layerTexture, layerFramebufferId)
  boxy.layerFramebuffers.add(layerFramebufferId)

proc addWhiteTile(boxy: Boxy)
proc clearAtlas*(boxy: Boxy) =
  boxy.entries.clear()
  boxy.allocator.reset()
  boxy.addWhiteTile()

proc newBoxy*(
  atlasSize = 512,
  quadsPerBatch = 1024
): Boxy =
  ## Creates a new Boxy with a specified atlas size and quads per batch.
  if quadsPerBatch > QuadLimit:
    raise newException(BoxyError, "Quads per batch cannot exceed " & $QuadLimit)

  result = Boxy()
  result.atlasSize = atlasSize
  result.quadsPerBatch = quadsPerBatch
  result.mat = mat3()
  result.mats = newSeq[Mat3]()

  result.atlasTexture = result.createAtlasTexture(atlasSize)
  result.allocator = newSkylineAllocator(atlasSize, TileMargin)

  result.layerNum = -1

  when defined(emscripten):
    result.atlasShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "300 es", "precision highp float;\n")),
      ("atlasMain", toGLSL(atlasMain, "300 es", "precision highp float;\n"))
    )
    result.maskShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "300 es", "precision highp float;\n")),
      ("maskMain", toGLSL(maskMain, "300 es", "precision highp float;\n"))
    )
    result.blendShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "300 es", "precision highp float;\n")),
      ("blendingMain", toGLSL(blendingMain, "300 es", "precision highp float;\n"))
    )
    result.blurXShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "300 es", "precision highp float;\n")),
      ("blendingMain", toGLSL(blurXMain, "300 es", "precision highp float;\n"))
    )
    result.blurYShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "300 es", "precision highp float;\n")),
      ("blendingMain", toGLSL(blurYMain, "300 es", "precision highp float;\n"))
    )
    result.spreadXShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "300 es", "precision highp float;\n")),
      ("spreadXMain", toGLSL(spreadXMain, "300 es", "precision highp float;\n"))
    )
    result.spreadYShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "300 es", "precision highp float;\n")),
      ("spreadYMain", toGLSL(spreadYMain, "300 es", "precision highp float;\n"))
    )

  else:
    result.atlasShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "410", "")),
      ("atlasMain", toGLSL(atlasMain, "410", ""))
    )
    result.maskShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "410", "")),
      ("maskMain", toGLSL(maskMain, "410", ""))
    )
    result.blendShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "410", "")),
      ("blendingMain", toGLSL(blendingMain, "410", ""))
    )
    result.blurXShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "410", "")),
      ("blendingMain", toGLSL(blurXMain, "410", ""))
    )
    result.blurYShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "410", "")),
      ("blendingMain", toGLSL(blurYMain, "410", ""))
    )
    result.spreadXShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "410", "")),
      ("spreadXMain", toGLSL(spreadXMain, "410", ""))
    )
    result.spreadYShader = newShader(
      ("atlasVert", toGLSL(atlasVert, "410", "")),
      ("spreadYMain", toGLSL(spreadYMain, "410", ""))
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
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, result.indices.buffer.bufferId)

  result.activeShader.bindAttrib("vertexPos", result.positions.buffer)
  result.activeShader.bindAttrib("vertexColor", result.colors.buffer)
  result.activeShader.bindAttrib("vertexUv", result.uvs.buffer)

  glBindFramebuffer(GL_FRAMEBUFFER, 0)

  # Enable premultiplied alpha blending
  glEnable(GL_BLEND)
  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)

  var maxAtlasSize: int32
  glGetIntegerv(GL_MAX_TEXTURE_SIZE, maxAtlasSize.addr)
  result.maxAtlasSize = maxAtlasSize

  if result.maxAtlasSize < result.atlasSize:
    raise newException(
      BoxyError,
      "Requested atlas texture is larger than max supported size: " &
      $result.maxAtlasSize
    )

  result.addWhiteTile()

# Forward declaration
proc drawUvRect(boxy: Boxy, at, to, uvAt, uvTo: Vec2, tint: Color)

proc removeImage*(boxy: Boxy, key: string) =
  ## Removes an image, does nothing if the image has not been added.
  if key in boxy.entriesBuffered:
    raise newException(
      BoxyError,
      "Attempting to remove an image that is set to be drawn"
    )

  if key in boxy.entries:
    # Clear the image from the atlas
    boxy.atlasTexture.clearSubImage(
      boxy.entries[key].atlasPos.x,
      boxy.entries[key].atlasPos.y,
      boxy.entries[key].cap
    )
    boxy.entries.del(key)

proc clearColor(boxy: Boxy) =
  glClearColor(0, 0, 0, 0)
  glClear(GL_COLOR_BUFFER_BIT)

proc grow(boxy: Boxy) =
  ## Grows the atlas size by 2 (growing area by 4) using GPU-based copying.
  if boxy.atlasSize == boxy.maxAtlasSize:
    raise newException(
      BoxyError,
      "Can't grow boxy atlas texture, max supported size reached: " &
      $boxy.maxAtlasSize
    )

  boxy.flush()
  boxy.uploadImages(false)

  let oldAtlasTexture = boxy.atlasTexture
  let oldEntries = boxy.entries
  let oldAllocator = boxy.allocator

  # Calculate new size
  var newAtlasSize = boxy.atlasSize * 2
  if newAtlasSize > boxy.maxAtlasSize:
    newAtlasSize = boxy.maxAtlasSize

  # Create new atlas texture and allocator
  let newAtlasTexture = boxy.createAtlasTexture(newAtlasSize)
  let newAllocator = newSkylineAllocator(newAtlasSize, oldAllocator.margin)

  # Create a framebuffer for the new atlas
  var growFramebufferId: GLuint
  glGenFramebuffers(1, growFramebufferId.addr)
  glBindFramebuffer(GL_FRAMEBUFFER, growFramebufferId)
  glFramebufferTexture2D(
    GL_FRAMEBUFFER,
    GL_COLOR_ATTACHMENT0,
    GL_TEXTURE_2D,
    newAtlasTexture.textureId,
    0
  )

  # Clear the new atlas
  glViewport(0, 0, newAtlasSize.GLint, newAtlasSize.GLint)
  boxy.clearColor()

  # Set up for drawing to the new atlas
  let savedProj = boxy.proj
  let savedMat = boxy.mat
  let savedMats = boxy.mats
  boxy.proj = ortho(0.float32, newAtlasSize.float32, 0, newAtlasSize.float32, -1000, 1000)
  boxy.mat = mat3()
  boxy.mats = @[]

  # Create new entries table and re-allocate all images
  var newEntries: Table[string, ImageInfo]
  for key, oldInfo in oldEntries:
    if oldInfo.isOneColor:
      # Solid color images don't need atlas space
      newEntries[key] = oldInfo
    else:
      # Allocate space in the new atlas
      let allocation = newAllocator.allocate(oldInfo.size.x, oldInfo.size.y)
      if not allocation.success:
        raise newException(BoxyError, "Failed to re-allocate image during grow: " & key)

      var newInfo = oldInfo
      newInfo.atlasPos = ivec2(allocation.x.int32, allocation.y.int32)
      newEntries[key] = newInfo

      # Draw the image from old position to new position using GPU
      let
        srcX = oldInfo.atlasPos.x.float32
        srcY = oldInfo.atlasPos.y.float32
        srcW = oldInfo.size.x.float32
        srcH = oldInfo.size.y.float32
        dstX = allocation.x.float32
        dstY = allocation.y.float32

      # Use drawUvRect to copy the image data
      boxy.drawUvRect(
        at = vec2(dstX, dstY),
        to = vec2(dstX + srcW, dstY + srcH),
        uvAt = vec2(srcX, srcY),
        uvTo = vec2(srcX + srcW, srcY + srcH),
        tint = color(1, 1, 1, 1)
      )

  # Flush the draw calls to copy all images
  boxy.flush()

  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, newAtlasTexture.textureId)
  glGenerateMipmap(GL_TEXTURE_2D)

  # Restore framebuffer binding
  glBindFramebuffer(
    GL_FRAMEBUFFER,
    if boxy.layerNum >= 0:
      boxy.layerFramebuffers[boxy.layerNum]
    else:
      0
  )

  # Clean up the temporary framebuffer
  glDeleteFramebuffers(1, growFramebufferId.addr)

  # Swap to the new atlas and entries
  boxy.atlasTexture = newAtlasTexture
  boxy.atlasSize = newAtlasSize
  boxy.allocator = newAllocator
  boxy.entries = newEntries

  # Restore matrices
  boxy.proj = savedProj
  boxy.mat = savedMat
  boxy.mats = savedMats

  # Delete the old atlas texture
  glDeleteTextures(1, oldAtlasTexture.textureId.addr)

  # Restore the viewport
  glViewport(0, 0, boxy.frameSize.x.GLint, boxy.frameSize.y.GLint)

proc addImage*(boxy: Boxy, key: string, image: Image) =
  if key in boxy.entriesBuffered:
    raise newException(
      BoxyError,
      "Attempting to modify an image that is already set to be drawn " &
      "(try using a unique key?)"
    )

  # If image is one color:
  if image.isOneColor():
    var imageInfo = ImageInfo()
    imageInfo.size = ivec2(image.width.int32, image.height.int32)
    imageInfo.isOneColor = true
    imageInfo.oneColor = image[0, 0].color
    imageInfo.atlasPos = ivec2(0, 0)
    boxy.entries[key] = imageInfo
    return

  # Check if the image is already in the atlas
  var imageInfo: ImageInfo
  var reusing = false
  if key in boxy.entries:
    imageInfo = boxy.entries[key]
    if imageInfo.cap.x >= image.width and imageInfo.cap.y >= image.height:
      reusing = true

  if not reusing:
    # New image can't fit in the existing image info.
    # Remove the existing image info and create a new one.
    boxy.removeImage(key)
    imageInfo = ImageInfo()
    boxy.entriesBuffered.incl(key)
    imageInfo.size = ivec2(image.width.int32, image.height.int32)
    imageInfo.cap = imageInfo.size
    imageInfo.isOneColor = false

    # Try to pack the image using the allocator
    var packed = false
    var x, y: int
    while not packed:
      let allocation = boxy.allocator.allocate(image.width, image.height)
      if allocation.success:
        x = allocation.x
        y = allocation.y
        packed = true
      else:
        # Need to grow the atlas
        boxy.grow()
    imageInfo.atlasPos = ivec2(x.int32, y.int32)
  elif imageInfo.cap != imageInfo.size:
    # Got to clear the margin around the image.
    boxy.atlasTexture.clearSubImage(
      imageInfo.atlasPos.x,
      imageInfo.atlasPos.y,
      imageInfo.cap
    )

  # Update the image info
  imageInfo.size = ivec2(image.width.int32, image.height.int32)
  boxy.entries[key] = imageInfo

  # Schedule mipmap generation for the image, batched to flush boundaries
  boxy.pendingLocations.add(imageInfo.atlasPos)
  boxy.pendingImages.add(image)

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
  ## Adds an image rect with a path to a ctx
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

proc addWhiteTile(boxy: Boxy) =
  # Add a 16x16 white pixel to the atlas
  let white = newImage(16, 16)
  white.fill(color(1, 1, 1, 1))
  let allocation = boxy.allocator.allocate(1, 1)
  if allocation.success:
    # We need to use the old updateSubImage to avoid one color by pass.
    boxy.entries[WhiteTileKey] = ImageInfo(
      size: ivec2(16, 16),
      cap: ivec2(16, 16),
      atlasPos: ivec2(allocation.x.int32, allocation.y.int32),
      isOneColor: false
    )
    boxy.pendingLocations.add(ivec2(allocation.x.int32, allocation.y.int32))
    boxy.pendingImages.add(white)

proc drawRect*(
  boxy: Boxy,
  rect: Rect,
  color: Color
) =
  if color != color(0, 0, 0, 0):
    # Draw a solid color rectangle
    let whitePixel = boxy.entries[WhiteTileKey]
    if whitePixel.size.x > 0:
      boxy.drawUvRect(
        rect.xy,
        rect.xy + rect.wh,
        vec2(whitePixel.atlasPos.x.float32 + 0.5, whitePixel.atlasPos.y.float32 + 0.5),
        vec2(whitePixel.atlasPos.x.float32 + 0.5, whitePixel.atlasPos.y.float32 + 0.5),
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
    boxy.tmpTexture.magFilter = filterLinear
    boxy.tmpTexture.minFilter = filterLinear
  # Resize extra blend texture if needed
  if boxy.tmpTexture.width != boxy.frameSize.x.int32 or
    boxy.tmpTexture.height != boxy.frameSize.y.int32:
    boxy.tmpTexture.width = boxy.frameSize.x.int32
    boxy.tmpTexture.height = boxy.frameSize.y.int32
    bindTextureData(boxy.tmpTexture, nil)
  if boxy.tmpFramebuffer == 0:
    glGenFramebuffers(1, boxy.tmpFramebuffer.addr)
    boxy.drawToTexture(boxy.tmpTexture, boxy.tmpFramebuffer)
    checkFramebuffer()
  else:
    glBindFramebuffer(GL_FRAMEBUFFER, boxy.tmpFramebuffer)

proc pushLayer*(boxy: Boxy) =
  ## Starts drawing into a new layer.
  if not boxy.frameBegun:
    raise newException(BoxyError, "beginFrame has not been called")

  boxy.flush()

  inc boxy.layerNum
  if boxy.layerNum >= boxy.layerTextures.len:
    boxy.addLayerTexture()
  else:
    glBindFramebuffer(GL_FRAMEBUFFER, boxy.layerFramebuffers[boxy.layerNum])

  boxy.clearColor()

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
  let savedAtlasTexture = boxy.atlasTexture
  dec boxy.layerNum

  if blendMode in {NormalBlend, MaskBlend, ScreenBlend}:
    glBindFramebuffer(GL_FRAMEBUFFER, if boxy.layerNum == -1: 0.GLuint else: boxy.layerFramebuffers[boxy.layerNum])

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
    boxy.flush(blendMode != MaskBlend)

  else:
    let
      srcTexture = layerTexture
      dstTexture = boxy.layerTextures[boxy.layerNum]

    # Can use OpenGL blending mode
    boxy.readyTmpTexture()
    boxy.clearColor()

    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, srcTexture.textureId)

    glActiveTexture(GL_TEXTURE1)
    glBindTexture(GL_TEXTURE_2D, dstTexture.textureId)

    glUseProgram(boxy.blendShader.programId)
    boxy.blendShader.setUniform("proj", boxy.proj)
    boxy.blendShader.setUniform("srcTexture", 0)
    boxy.blendShader.setUniform("dstTexture", 1)
    boxy.blendShader.setUniform("blendMode", blendMode.ord.int32)
    boxy.blendShader.bindUniforms()

    boxy.drawUvRect(
      at = vec2(0, 0),
      to = boxy.frameSize.vec2,
      uvAt = vec2(0, boxy.atlasSize.float32),
      uvTo = vec2(boxy.atlasSize.float32, 0),
      tint = tint
    )
    boxy.upload()
    boxy.drawVertexArray()

    # For debugging:
    # boxy.tmpTexture.writeFile("resTexture.png")
    # boxy.srcTexture.writeFile("srcTexture.png")
    # boxy.dstTexture.writeFile("dstTexture.png")

    swap boxy.layerTextures[boxy.layerNum], boxy.tmpTexture
    swap boxy.layerFramebuffers[boxy.layerNum], boxy.tmpFramebuffer

  # Reset everything back.
  boxy.atlasTexture = savedAtlasTexture
  glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
  boxy.activeShader = boxy.atlasShader

proc copyLowerToCurrent*(boxy: Boxy) =
  ## Copies the immediately lower layer texture into the current layer.
  ## Requires that at least one lower layer exists and a current layer is active.
  if boxy.layerNum <= 0:
    raise newException(BoxyError, "copyLowerToCurrent requires an active layer above a lower layer")

  boxy.flush()

  let srcTexture = boxy.layerTextures[boxy.layerNum - 1]
  let savedAtlasTexture = boxy.atlasTexture
  let savedShader = boxy.activeShader

  boxy.atlasTexture = srcTexture
  boxy.activeShader = boxy.atlasShader

  boxy.drawUvRect(
    at = vec2(0, 0),
    to = boxy.frameSize.vec2,
    uvAt = vec2(0, boxy.atlasSize.float32),
    uvTo = vec2(boxy.atlasSize.float32, 0),
    tint = color(1, 1, 1, 1)
  )

  boxy.flush()

  boxy.atlasTexture = savedAtlasTexture
  boxy.activeShader = savedShader

proc blurEffect(
  boxy: Boxy,
  radius: float32,
  tint: Color,
  offset: Vec2,
  readLayer: int,
  writeLayer: int
) =
  ## Blurs the current layer
  if boxy.layerNum == -1:
    raise newException(BoxyError, "blurEffect called without pushLayer")

  boxy.flush()

  # blurX
  boxy.readyTmpTexture()
  boxy.clearColor()

  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, boxy.layerTextures[readLayer].textureId)

  glUseProgram(boxy.blurXShader.programId)
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
  glBindFramebuffer(GL_FRAMEBUFFER, boxy.layerFramebuffers[writeLayer])
  boxy.clearColor()

  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, boxy.tmpTexture.textureId)

  glUseProgram(boxy.blurYShader.programId)
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
  if boxy.layerNum == -1:
    raise newException(BoxyError, "blurEffect called without pushLayer")
  boxy.blurEffect(
    radius,
    color(1, 1, 1, 1),
    vec2(0, 0),
    boxy.layerNum,
    boxy.layerNum
  )

proc dropShadowEffect*(boxy: Boxy, tint: Color, offset: Vec2, radius, spread: float32) =
  ## Drop shadows the current layer
  if boxy.layerNum == -1:
    raise newException(BoxyError, "shadowLayer called without pushLayer")

  boxy.pushLayer()

  let
    shadowLayerId = boxy.layerNum
    mainLayerId = boxy.layerNum - 1
    mainLayer = boxy.layerTextures[mainLayerId]

  # spreadX
  boxy.readyTmpTexture()
  boxy.clearColor()

  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, mainLayer.textureId)

  glUseProgram(boxy.spreadXShader.programId)
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
  glBindFramebuffer(GL_FRAMEBUFFER, boxy.layerFramebuffers[shadowLayerId])
  boxy.clearColor()

  glBindTexture(GL_TEXTURE_2D, boxy.tmpTexture.textureId)

  glUseProgram(boxy.spreadYShader.programId)
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

  boxy.blurEffect(radius, tint, offset, shadowLayerId, shadowLayerId)

  swap(boxy.layerTextures[shadowLayerId], boxy.layerTextures[mainLayerId])
  swap(boxy.layerFramebuffers[shadowLayerId], boxy.layerFramebuffers[mainLayerId])
  boxy.popLayer()

  # For debugging:
  # boxy.tmpTexture.writeFile("spreadX.png")
  # mainLayer.writeFile("spreadY.png")

proc beginFrame*(boxy: Boxy, frameSize: IVec2, proj: Mat4, clearFrame = true) =
  ## Starts a new frame.
  if boxy.frameBegun:
    raise newException(BoxyError, "beginFrame has already been called")

  # Resize all of the layers if needed.
  if boxy.frameSize != frameSize:
    boxy.frameSize = frameSize
    for texture in boxy.layerTextures:
      texture.width = frameSize.x
      texture.height = frameSize.y
      bindTextureData(texture, nil)
      #glBindFramebuffer(GL_FRAMEBUFFER, boxy.layerFramebuffers[boxy.layerNum])
      #checkFramebuffer()

  boxy.frameBegun = true
  boxy.proj = proj

  glViewport(0, 0, boxy.frameSize.x, boxy.frameSize.y)

  if clearFrame:
    boxy.clearColor()

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
  if imageInfo.isOneColor:
    boxy.drawRect(
      rect(pos, imageInfo.size.vec2),
      imageInfo.oneColor * tint
    )
  else:
    # Draw the image from its contiguous region in the atlas
    let
      uvAt = imageInfo.atlasPos.vec2
      uvTo = uvAt + imageInfo.size.vec2

    boxy.drawUvRect(
      pos,
      pos + imageInfo.size.vec2,
      uvAt,
      uvTo,
      tint
    )

proc drawImage*(
  boxy: Boxy,
  key: string,
  rect: Rect,
  tint = color(1, 1, 1, 1)
) =
  ## Draws image filling the rect.
  ## The image should have already been added.
  let imageInfo = boxy.entries[key]
  if imageInfo.isOneColor:
    boxy.drawRect(rect, imageInfo.oneColor * tint)
  else:
    # Draw the image scaled to fit the rect
    let
      uvAt = imageInfo.atlasPos.vec2
      uvTo = uvAt + imageInfo.size.vec2

    boxy.drawUvRect(
      rect.xy,
      rect.xy + rect.wh,
      uvAt,
      uvTo,
      tint
    )

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
  if imageInfo.isOneColor:
    boxy.saveTransform()
    boxy.translate(center)
    boxy.rotate(angle)
    boxy.scale(vec2(scale, scale))
    boxy.drawRect(
      rect(-imageInfo.size.vec2 / 2, imageInfo.size.vec2),
      imageInfo.oneColor * tint
    )
    boxy.restoreTransform()
  else:
    boxy.saveTransform()
    boxy.translate(center)
    boxy.rotate(angle)
    boxy.scale(vec2(scale, scale))
    boxy.translate(-imageInfo.size.vec2 / 2)
    boxy.drawImage(key, pos = vec2(0, 0), tint)
    boxy.restoreTransform()

proc getImage*(boxy: Boxy, bounds: Rect): Image =
  ## Gets an Image rectangle from the current layer.
  ## Note: This is very costly because it transfers GPU data to CPU.
  ## It's not recommended to use this in a game loop.
  if boxy.layerNum == -1:
    raise newException(BoxyError, "getImage called without pushLayer")
  let layerTexture = boxy.layerTextures[boxy.layerNum]
  let fullLayer = layerTexture.readImage()
  fullLayer.flipVertical()
  return fullLayer.subImage(
    bounds.x.int,
    bounds.y.int,
    bounds.w.int,
    bounds.h.int
  )

import buffers, opengl, pixie

type
  MinFilter* = enum
    minDefault,
    minNearest = GL_NEAREST,
    minLinear = GL_LINEAR,
    minNearestMipmapNearest = GL_NEAREST_MIPMAP_NEAREST,
    minLinearMipmapNearest = GL_LINEAR_MIPMAP_NEAREST,
    minNearestMipmapLinear = GL_NEAREST_MIPMAP_LINEAR,
    minLinearMipmapLinear = GL_LINEAR_MIPMAP_LINEAR

  MagFilter* = enum
    magDefault,
    magNearest = GL_NEAREST,
    magLinear = GL_LINEAR

  Wrap* = enum
    wDefault,
    wRepeat = GL_REPEAT,
    wClampToEdge = GL_CLAMP_TO_EDGE,
    wMirroredRepeat = GL_MIRRORED_REPEAT

  Texture* = ref object
    width*, height*: int32
    componentType*, format*, internalFormat*: GLenum
    minFilter*: MinFilter
    magFilter*: MagFilter
    wrapS*, wrapT*: Wrap
    genMipmap*: bool
    textureId*: GLuint

proc bindTextureBufferData*(texture: Texture, buffer: Buffer, data: pointer) =
  ## Binds data to a texture buffer.
  bindBufferData(buffer, data)

  if texture.textureId == 0:
    glGenTextures(1, texture.textureId.addr)

  glBindTexture(GL_TEXTURE_BUFFER, texture.textureId)
  glTexBuffer(
    GL_TEXTURE_BUFFER,
    texture.internalFormat,
    buffer.bufferId
  )

proc bindTextureData*(texture: Texture, data: pointer) =
  ## Binds the data to a texture.
  if texture.textureId == 0:
    glGenTextures(1, texture.textureId.addr)

  glBindTexture(GL_TEXTURE_2D, texture.textureId)
  glTexImage2D(
    target = GL_TEXTURE_2D,
    level = 0,
    internalFormat = texture.internalFormat.GLint,
    width = texture.width,
    height = texture.height,
    border = 0,
    format = texture.format,
    `type` = texture.componentType,
    pixels = data
  )

  if texture.magFilter != magDefault:
    glTexParameteri(
      GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, texture.magFilter.GLint
    )
  if texture.minFilter != minDefault:
    glTexParameteri(
      GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, texture.minFilter.GLint
    )
  if texture.wrapS != wDefault:
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, texture.wrapS.GLint)
  if texture.wrapT != wDefault:
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, texture.wrapT.GLint)

  if texture.genMipmap:
    glGenerateMipmap(GL_TEXTURE_2D)

func getFormat(image: Image): GLenum =
  ## Gets the format of the image.
  result = GL_RGBA

proc newTexture*(image: Image): Texture =
  ## Creates a new format.
  result = Texture()
  result.width = image.width.GLint
  result.height = image.height.GLint
  result.componentType = GL_UNSIGNED_BYTE
  result.format = image.getFormat()
  result.internalFormat = GL_RGBA8
  result.genMipmap = true
  result.minFilter = minLinearMipmapLinear
  result.magFilter = magLinear
  bindTextureData(result, image.data[0].addr)

proc updateSubImage*(texture: Texture, x, y: int, image: Image, level: int) =
  ## Update a small part of a texture image.
  glBindTexture(GL_TEXTURE_2D, texture.textureId)
  glTexSubImage2D(
    GL_TEXTURE_2D,
    level = level.GLint,
    xoffset = x.GLint,
    yoffset = y.GLint,
    width = image.width.GLint,
    height = image.height.GLint,
    format = image.getFormat(),
    `type` = GL_UNSIGNED_BYTE,
    pixels = image.data[0].addr
  )

proc updateSubImage*(texture: Texture, x, y: int, image: Image) =
  ## Update a small part of texture with a new image.
  var
    x = x
    y = y
    image = image
    level = 0
  while true:
    texture.updateSubImage(x, y, image, level)
    if image.width <= 1 or image.height <= 1:
      break
    if not texture.genMipmap:
      break
    image = image.minifyBy2()
    x = x div 2
    y = y div 2
    inc level

proc readImage*(texture: Texture): Image =
  ## Reads the data of the texture back.
  ## Note: Can be quite slow, used mostly for debugging.
  result = newImage(texture.width, texture.height)
  when not defined(emscripten):
    glBindTexture(GL_TEXTURE_2D, texture.textureId)
    glGetTexImage(
      GL_TEXTURE_2D,
      0,
      GL_RGBA,
      GL_UNSIGNED_BYTE,
      result.data[0].addr
    )

proc writeFile*(texture: Texture, path: string) =
  ## Reads the data of the texture and writes it to file.
  var image = texture.readImage()
  image.flipVertical()
  image.writeFile(path)

import shady, vmath

var
  srcTexture: Uniform[Sampler2d]
  dstTexture: Uniform[Sampler2d]
  blendMode: Uniform[int32]

proc min3(c: Vec3): float =
  min(min(c.r, c.g), c.b)

proc max3(c: Vec3): float =
  max(max(c.r, c.g), c.b)

proc sat3(c: Vec3): float =
  max3(c) - min3(c)

proc lumv3(c: Vec3): float =
  dot(c, vec3(0.3, 0.59, 0.11))

proc lum(cBase, cLum: Vec3): Vec3 =
  var
    lBase = lumv3(cBase)
    lLum = lumv3(cLum)
    lDiff = lLum - lBase
    color = cBase + vec3(lDiff)
    minColor = min3(color)
    maxColor = max3(color)
  if minColor < 0.0:
    color = mix(vec3(lLum), color, lLum / (lLum - minColor))
  elif maxColor > 1.0:
    color = mix(vec3(lLum), color, (1.0 - lLum) / (maxColor - lLum))
  return color

proc lumSat(cBase, cSat, cLum: Vec3): Vec3 =
  var
    sBase = sat3(cBase)
    color = vec3(0.0)
  if sBase > 0.0:
    var
      minBase = min3(cBase)
      sSat = sat3(cSat)
    color = (cBase - minBase) * sSat / sBase
  return lum(color, cLum)

proc blender(blendMode: int32, dst, src: Vec4): Vec4 =

  if blendMode == 0:
    # NormalBlend (usually done though fixed function)
    return src

  if src.a == 0.0:
    # early return with no alpha
    return dst

  var
    alphaFinal = src.a + (1.0 - src.a) * dst.a
    res = src.rgb * (1.0 - dst.a)

  res += dst.rgb * (1.0 - src.a)

  if blendMode == 1:
    # DarkenBlend
    res += min(src.rgb * dst.a, dst.rgb * src.a)
  elif blendMode == 2:
    # MultiplyBlend
    res += src.rgb * dst.rgb
  elif blendMode == 3:
    # ColorBurnBlend
    res += src.a * dst.a * (vec3(1.0) - min(
      vec3(1.0),
      (dst.a - dst.rgb) * src.a / (src.rgb * dst.a + 1e-6))
    )
  elif blendMode == 4:
    # LightenBlend
    res += max(src.rgb * dst.a, dst.rgb * src.a)
  elif blendMode == 5:
    # ScreenBlend (usually done though fixed function)
    res = vec3(1.0) - (vec3(1.0) - dst.rgb) * (vec3(1.0) - src.rgb)
  elif blendMode == 6:
    # ColorDodgeBlend
    res += src.a * dst.a * min(
      vec3(1.0),
      dst.rgb * src.a / (dst.a * (src.a - src.rgb) + 1e-6)
    )
  elif blendMode == 7:
    # OverlayBlend
    var
      Dca2 = 2.0f * dst.rgb
      c0 = src.rgb * Dca2
      c1 = vec3(src.a * dst.a) - 2.0f *
        (vec3(dst.a) - dst.rgb) *
        (vec3(src.a) - src.rgb)
    res += mix(c1, c0, vec3(lessThanEqual(Dca2, vec3(dst.a))))
  elif blendMode == 8:
    # SoftLightBlend
    var Dc = dst.rgb
    if dst.a > 0.0:
      Dc /= dst.a

    var Sc = src.rgb
    if src.a > 0.0:
      Sc /= src.a

    var
      c0 = vec3(1.0f) - Dc
      c1 = (16.0f * Dc - 12.0f) * Dc + 3.0f
      c2 = inversesqrt(Dc) - 1.0f
      c = mix(c1, c2, vec3(greaterThan(Dc, vec3(0.25))))
    c = mix(c, c0, vec3(greaterThan(Sc, vec3(0.5))))
    var cmid = 2.0f * Sc - 1.0f
    c = src.a * dst.rgb * (vec3(1.0) + cmid * c)
    res += c
  elif blendMode == 9:
    # HardLightBlend
    var
      Sca2 = 2.0f * src.rgb
      c0 = Sca2 * dst.rgb
      c1 = vec3(src.a * dst.a) - 2.0f *
        (vec3(dst.a) - dst.rgb) *
        (vec3(src.a) - src.rgb)
    res += mix(c0, c1, vec3(greaterThan(Sca2, vec3(src.a))))
  elif blendMode == 10:
    # DifferenceBlend
    res += abs(dst.rgb * src.a - src.rgb * dst.a)
  elif blendMode == 11:
    # ExclusionBlend
    res += src.rgb * dst.a + dst.rgb * src.a - 2.0f * src.rgb * dst.rgb
  elif blendMode == 12 or blendMode == 13 or blendMode == 14 or blendMode == 15:
    var
      dstColor = dst.rgb
      srcColor = src.rgb

    if src.a > 0f:
      srcColor = src.rgb / src.a

    if dst.a > 0f:
      dstColor = dst.rgb / dst.a

    var c: Vec3
    if blendMode == 12:
      # HueBlend
      c = lumSat(srcColor.rgb, dstColor.rgb, dstColor.rgb)
    elif blendMode == 13:
      # SaturationBlend
      c = lumSat(dstColor.rgb, srcColor.rgb, dstColor.rgb)
    elif blendMode == 14:
      # ColorBlend
      c = lum(srcColor.rgb, dstColor.rgb)
    else:
      # LuminosityBlend
      c = lum(dstColor.rgb, srcColor.rgb)

    res += c * src.a * dst.a

  return vec4(res, alphaFinal)

proc blendingMain*(
  pos: Vec2,
  uv: Vec2,
  color: Vec2,
  fragColor: var Vec4
) =
  fragColor = blender(
    blendMode,
    texture(dstTexture, uv),
    texture(srcTexture, uv)
  )

var proj: Uniform[Mat4]

proc atlasVert*(
  vertexPos: Vec2,
  vertexUv: Vec2,
  vertexColor: Vec4,
  pos: var Vec2,
  uv: var Vec2,
  color: var Vec4
) =
  pos = vertexPos
  uv = vertexUv
  color = vertexColor
  gl_Position = proj * vec4(vertexPos.x, vertexPos.y, 0.0, 1.0)

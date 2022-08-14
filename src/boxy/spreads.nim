import shady, vmath

var
  srcTexture: Uniform[Sampler2d]
  radius: Uniform[float32]
  pixelScale: Uniform[float32]

proc spreadXMain*(
  pos: Vec2,
  uv: Vec2,
  color: Vec4,
  fragColor: var Vec4
) =
  var alpha: float32
  if radius >= 0:
    let r = radius
    alpha = 0f
    for x in floor(-r).int .. ceil(r).int:
      alpha = max(alpha, texture(
        srcTexture,
        uv + vec2(x.float32 * pixelScale, 0)
      ).a)
  else:
    let r = -radius
    alpha = 1f
    for x in floor(-r).int .. ceil(r).int:
      alpha = min(alpha, texture(
        srcTexture,
        uv + vec2(x.float32 * pixelScale, 0)
      ).a)
  fragColor.rgba = vec4(alpha)

proc spreadYMain*(
  pos: Vec2,
  uv: Vec2,
  color: Vec4,
  fragColor: var Vec4
) =
  var alpha: float32
  if radius >= 0:
    let r = radius
    alpha = 0f
    for y in floor(-r).int .. ceil(r).int:
      alpha = max(alpha, texture(
        srcTexture,
        uv + vec2(0, y.float32 * pixelScale)
      ).a)
  else:
    let r = -radius
    alpha = 1f
    for y in floor(-r).int .. ceil(r).int:
      alpha = min(alpha, texture(
        srcTexture,
        uv + vec2(0, y.float32 * pixelScale)
      ).a)
  fragColor.rgba = vec4(alpha)

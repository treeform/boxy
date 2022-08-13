import shady, vmath

var
  srcTexture: Uniform[Sampler2d]
  shadowSpread: Uniform[float32]
  pixelScale: Uniform[float32]

proc shadowXMain*(
  pos: Vec2,
  uv: Vec2,
  color: Vec4,
  fragColor: var Vec4
) =
  # spread
  var
    alpha = 0f
  let r = shadowSpread
  for x in floor(-r).int .. ceil(r).int:
    alpha = max(alpha, texture(
      srcTexture,
      uv + vec2(x.float32 * pixelScale, 0)
    ).a)
  fragColor.rgba = vec4(alpha)

proc shadowYMain*(
  pos: Vec2,
  uv: Vec2,
  color: Vec4,
  fragColor: var Vec4
) =
  # spread
  var
    alpha = 0f
  let r = shadowSpread
  for y in floor(-r).int .. ceil(r).int:
    alpha = max(alpha, texture(
      srcTexture,
      uv + vec2(0, y.float32 * pixelScale)
    ).a)
  fragColor.rgba = vec4(alpha)

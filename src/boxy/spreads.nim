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
  var
    alpha = 0f
  let r = radius
  for x in floor(-r).int .. ceil(r).int:
    alpha = max(alpha, texture(
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
  var
    alpha = 0f
  let r = radius
  for y in floor(-r).int .. ceil(r).int:
    alpha = max(alpha, texture(
      srcTexture,
      uv + vec2(0, y.float32 * pixelScale)
    ).a)
  fragColor.rgba = vec4(alpha)

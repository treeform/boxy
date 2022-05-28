import shady, vmath

var
  srcTexture: Uniform[Sampler2d]
  blurRadius: Uniform[float32]
  pixelScale: Uniform[float32]

proc blurXMain*(
  pos: Vec2,
  uv: Vec2,
  color: Vec2,
  fragColor: var Vec4
) =
  # gaussian blur
  var accumulation = 0f
  let r = blurRadius
  let rr = r * r
  for x in floor(-r).int .. ceil(r).int:
    let a = exp(-(x*x).float32/(rr)*2)
    fragColor += texture(srcTexture, uv + vec2(x.float32 / pixelScale, 0)) * a
    accumulation += a
  fragColor = fragColor / accumulation

proc blurYMain*(
  pos: Vec2,
  uv: Vec2,
  color: Vec2,
  fragColor: var Vec4
) =
  # gaussian blur
  var accumulation = 0f
  let r = blurRadius
  let rr = r * r
  for y in floor(-r).int .. ceil(r).int:
    let a = exp(-(y*y).float32/(rr)*2)
    fragColor += texture(srcTexture, uv + vec2(0, y.float32 / pixelScale)) * a
    accumulation += a
  fragColor = fragColor / accumulation

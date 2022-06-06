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
  fragColor = vec4(0, 0, 0, 0)
  # gaussian blur
  var accumulation = 0f
  let r = max(round(blurRadius), 1)
  for x in floor(-r).int .. ceil(r).int:
    let a = exp(-(x*x).float32/(r * r)*2)
    fragColor += texture(srcTexture, uv + vec2(x.float32 * pixelScale, 0)) * a
    accumulation += a
  fragColor = fragColor / accumulation

proc blurYMain*(
  pos: Vec2,
  uv: Vec2,
  color: Vec2,
  fragColor: var Vec4
) =
  fragColor = vec4(0, 0, 0, 0)
  # gaussian blur
  var accumulation = 0f
  let r = max(round(blurRadius), 1)
  for y in floor(-r).int .. ceil(r).int:
    let a = exp(-(y*y).float32/(r * r)*2)
    fragColor += texture(srcTexture, uv + vec2(0, y.float32 * pixelScale)) * a
    accumulation += a
  fragColor = fragColor / accumulation

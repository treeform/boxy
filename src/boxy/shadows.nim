import shady, vmath

var
  srcTexture: Uniform[Sampler2d]
  shadowRadius: Uniform[float32]
  shadowSpread: Uniform[float32]
  pixelScale: Uniform[float32]

proc shadowXMain*(
  pos: Vec2,
  uv: Vec2,
  color: Vec2,
  fragColor: var Vec4
) =
  fragColor = vec4(0, 0, 0, 0)
  # gaussian blur
  var accumulation = 0f
  let r = max(round(shadowRadius), 1)
  for x in floor(-r).int .. ceil(r).int:
    let a = exp(-(x*x).float32/(r * r)*2)
    fragColor += texture(
      srcTexture,
      uv + vec2(x.float32 * pixelScale, 0) #+ shadowOffset / pixelScale
    ) * a
    accumulation += a
  fragColor = fragColor / accumulation

  # # spread
  # var
  #   alpha = 0f
  # let r = shadowSpread

  # for x in floor(-r).int .. ceil(r).int:
  #   alpha = max(alpha, texture(
  #     srcTexture,
  #     uv + vec2(x.float32 / pixelScale, 0) + shadowOffset / pixelScale
  #   ).a)
  # fragColor.rgba = vec4(alpha)

proc shadowYMain*(
  pos: Vec2,
  uv: Vec2,
  color: Vec4,
  fragColor: var Vec4
) =
  fragColor = vec4(0, 0, 0, 0)
  # gaussian blur
  var accumulation = 0f
  let r = max(round(shadowRadius), 1)
  for y in floor(-r).int .. ceil(r).int:
    let a = exp(-(y*y).float32/(r * r)*2)
    fragColor += texture(
      srcTexture,
      uv + vec2(0, y.float32 * pixelScale) #+ shadowOffset / pixelScale
    ) * a
    accumulation += a
  fragColor = fragColor / accumulation

  # # spread
  # var
  #   alpha = 0f
  # let r = shadowSpread

  # for y in floor(-r).int .. ceil(r).int:
  #   alpha = max(alpha, texture(
  #     srcTexture,
  #     uv + vec2(0, y.float32 / pixelScale)
  #   ).a)
  # fragColor.rgba = vec4(alpha)

  # tint the final output

  fragColor *= color

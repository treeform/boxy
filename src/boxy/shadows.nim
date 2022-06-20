import shady, vmath

var
  srcTexture: Uniform[Sampler2d]
  shadowOffset: Uniform[Vec2]
  shadowRadius: Uniform[float32]
  shadowSpread: Uniform[float32]
  pixelScale: Uniform[float32]

proc shadowXMain*(
  pos: Vec2,
  uv: Vec2,
  color: Vec2,
  fragColor: var Vec4
) =
  # # gaussian blur
  # var
  #   alpha = 0f
  #   accumulation = 0f
  # let r = shadowRadius
  # let rr = r * r
  # for x in floor(-r).int .. ceil(r).int:
  #   let a = exp(-(x*x).float32/(rr)*2)
  #   alpha += texture(
  #     srcTexture,
  #     uv + vec2(x.float32 / pixelScale, 0) + shadowOffset / pixelScale
  #   ).a * a
  #   accumulation += a
  # fragColor.rgba = vec4(alpha / accumulation)

  # spread
  var
    alpha = 0f
  let r = shadowSpread

  for x in floor(-r).int .. ceil(r).int:
    alpha = max(alpha, texture(
      srcTexture,
      uv + vec2(x.float32 / pixelScale, 0) + shadowOffset / pixelScale
    ).a)
  fragColor.rgba = vec4(alpha)

proc shadowYMain*(
  pos: Vec2,
  uv: Vec2,
  color: Vec4,
  fragColor: var Vec4
) =
  # # gaussian blur
  # var
  #   alpha = 0f
  #   accumulation = 0f
  # let r = shadowRadius
  # let rr = r * r
  # for y in floor(-r).int .. ceil(r).int:
  #   let a = exp(-(y*y).float32/(rr)*2)
  #   alpha += texture(srcTexture, uv + vec2(0, y.float32 / pixelScale)).a * a
  #   accumulation += a
  # fragColor.rgba = vec4(alpha / accumulation)

  # spread
  var
    alpha = 0f
  let r = shadowSpread

  for y in floor(-r).int .. ceil(r).int:
    alpha = max(alpha, texture(
      srcTexture,
      uv + vec2(0, y.float32 / pixelScale)
    ).a)
  fragColor.rgba = vec4(alpha)


  # tint the final output
  fragColor *= color

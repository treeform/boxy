#version 410 // Highest version on Mac.

in vec2 pos;
in vec2 uv;
in vec4 color;

uniform ivec2 windowFrame;
uniform ivec2 atlasConfig;
uniform sampler2D atlasTex;
uniform sampler2D maskTex;

out vec4 fragColor;

vec4 getTexel(vec2 uv, float tileSize, float atlasSize) {

  vec2 uvAt = uv / tileSize;

  if (mod(floor(uvAt.x), 2) == 1) {
    // In the margin odd region slide to a side.
    if (uvAt.x - floor(uvAt.x) < 0.5) {
      uvAt.x = floor(uvAt.x) + 0.5 - 1/tileSize;
    } else {
      uvAt.x = floor(uvAt.x) + 0.5 + 1/tileSize;
    }
    //return vec4(1, 0, 0, 1);
    //return vec4(0, 0, 0, 0);
  }
  uvAt.x = floor(uvAt.x) / 2 + uvAt.x - floor(uvAt.x);

  if (mod(floor(uvAt.y), 2) == 1) {
    // In the margin odd region slide to a side.
    if (uvAt.y - floor(uvAt.y) < 0.5) {
      uvAt.y = floor(uvAt.y) + 0.5 - 1/tileSize;
    } else {
      uvAt.y = floor(uvAt.y) + 0.5 + 1/tileSize;
    }
    //return vec4(1, 0, 0, 1);
    //return vec4(0, 0, 0, 0);
  }
  uvAt.y = floor(uvAt.y) / 2 + uvAt.y - floor(uvAt.y);

  return textureLod(atlasTex, (uvAt * tileSize + vec2(0.5, 0.5))/atlasSize, 0);
}

void main() {
  float atlasSize = atlasConfig.x;
  float tileSize = atlasConfig.y;

  vec2 uvAt = uv;

  float x = uvAt.x;
  float y = uvAt.y;
  float x0 = floor(x);
  float y0 = floor(y);
  float x1 = x0 + 1;
  float y1 = y0 + 1;
  float xFractional = x - x0;
  float yFractional = y - y0;

  vec4 x0y0 = getTexel(vec2(x0, y0), tileSize, atlasSize);
  vec4 x1y0 = getTexel(vec2(x1, y0), tileSize, atlasSize);
  vec4 x0y1 = getTexel(vec2(x0, y1), tileSize, atlasSize);
  vec4 x1y1 = getTexel(vec2(x1, y1), tileSize, atlasSize);

  vec4 topMix = mix(x0y0, x1y0, xFractional);
  vec4 bottomMix = mix(x0y1, x1y1, xFractional);
  vec4 finalMix = mix(topMix, bottomMix, yFractional);
  fragColor = finalMix * color;

  //fragColor = vec4((texture(atlasTex, uv).rgba * color).a);
  vec2 normalizedPos = vec2(pos.x / windowFrame.x, 1 - pos.y / windowFrame.y);
  fragColor *= texture(maskTex, normalizedPos).r;
}

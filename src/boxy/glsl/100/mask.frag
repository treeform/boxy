#version 100 // used for emscripten
#extension GL_EXT_texture_array : enable

precision highp float;

varying vec2 pos;
varying vec3 uv;
varying vec4 color;

uniform vec2 windowFrame;
uniform sampler2DArray atlasTex;
uniform sampler2D maskTex;

void main() {
  gl_FragColor  = vec4((texture2DArray(atlasTex, uv).rgba * color).a);
  vec2 normalizedPos = vec2(pos.x / windowFrame.x, 1.0 - pos.y / windowFrame.y);
  gl_FragColor *= texture2D(maskTex, normalizedPos).r;
}

#version 300 es

precision highp float;

in vec2 pos;
in vec2 uv;
in vec4 color;

uniform sampler2D maskTex;

out vec4 fragColor;

void main() {
  fragColor = vec4(texture(maskTex, uv).r);
}

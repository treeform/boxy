#version 410 // both win and mac support

in vec2 pos;
in vec3 uv;
in vec4 color;

uniform vec2 windowFrame;
uniform sampler2DArray atlasTex;
uniform sampler2D maskTex;

out vec4 fragColor;

void main() {
  fragColor = vec4((texture(atlasTex, uv).rgba * color).a);
  vec2 normalizedPos = vec2(pos.x / windowFrame.x, 1 - pos.y / windowFrame.y);
  fragColor.a *= texture(maskTex, normalizedPos).r;
}

#version 410 // Highest version on Mac.

in vec2 pos;
in vec2 uv;
in vec4 color;

uniform ivec2 windowFrame;
uniform sampler2D atlasTex;

out vec4 fragColor;

void main() {
  float a = texture(atlasTex, uv).a * color.a;
  fragColor = vec4(a, a, a, a);
}

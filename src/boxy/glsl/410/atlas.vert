#version 410 // both win and mac support

in vec2 vertexPos;
in vec3 vertexUv;
in vec4 vertexColor;

uniform mat4 proj;

out vec2 pos;
out vec3 uv;
out vec4 color;

void main() {
  pos = vertexPos;
  uv = vertexUv;
  color = vertexColor;
  gl_Position = proj * vec4(vertexPos, 0.0, 1.0);
}

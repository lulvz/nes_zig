#version 330

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D screenTexture;

void main() {
    float pixel = texture(screenTexture, TexCoord).r;
    FragColor = vec4(pixel, pixel, pixel, 1.0);
}

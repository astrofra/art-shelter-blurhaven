#define VHSRES vec2(320.0,240.0)

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
  vec2 uv = fragCoord.xy / iResolution.xy / iResolution.xy * VHSRES;
  fragColor = texture( iChannel0, uv );
}
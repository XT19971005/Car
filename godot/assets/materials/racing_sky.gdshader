shader_type sky;
uniform float cloud_cover : hint_range(0, 1) = 0.3;
uniform float storm : hint_range(0, 1) = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky() {
 float height=max(EYEDIR.y,0.0);
 vec3 horizon=mix(vec3(.62,.76,.86),vec3(.26,.31,.36),storm);
 vec3 zenith=mix(vec3(.09,.32,.66),vec3(.12,.17,.23),storm);
 vec3 color=mix(horizon,zenith,pow(height,.45));
 vec2 uv=EYEDIR.xz/max(.15,EYEDIR.y+.12)*2.1+vec2(TIME*.002,0);
 float n=noise(uv)*.55+noise(uv*2.1)*.27+noise(uv*4.3)*.12+noise(uv*8.7)*.06;
 float cloud=smoothstep(.70-cloud_cover*.46,.89-cloud_cover*.47,n)*smoothstep(0.0,.17,height);
 vec3 clouds=mix(vec3(.96,.96,.91),vec3(.39,.44,.49),storm);
 color=mix(color,clouds,cloud);
 if(LIGHT0_ENABLED){
  float sun=max(dot(EYEDIR,LIGHT0_DIRECTION),0.0);
  color+=vec3(1.0,.74,.42)*pow(sun,128.0)*.4*(1.0-storm)*(1.0-cloud);
  color+=vec3(3.0,2.5,1.9)*smoothstep(.9997,.99994,sun)*(1.0-storm)*(1.0-cloud);
 }
 COLOR=color;
}

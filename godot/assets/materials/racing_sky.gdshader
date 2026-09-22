shader_type sky;
// Static cloud field: weather changes rebuild radiance incrementally, not every frame.
uniform float cloud_cover : hint_range(0, 1) = 0.3;
uniform float horizon_warmth : hint_range(0, 1) = 0.0;
uniform float storm : hint_range(0, 1) = 0.0;
float hash(vec2 p) {
 vec3 q = fract(vec3(p.xyx) * .1031);
 q += dot(q, q.yzx + 33.33);
 return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*f*(f*(f*6.0-15.0)+10.0);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float cloud_field(vec2 p) {
 float value=0.0, amplitude=.55;
 for(int i=0;i<5;i++) {
  value+=noise(p)*amplitude;
  p=mat2(vec2(.8,.6),vec2(-.6,.8))*p*2.03+vec2(13.2,7.1);
  amplitude*=.48;
 }
 return value;
}
void sky() {
 float height=max(EYEDIR.y,0.0);
 vec3 horizon=mix(vec3(.47,.64,.77),vec3(.23,.29,.35),storm);
 vec3 zenith=mix(vec3(.035,.13,.32),vec3(.075,.105,.15),storm);
 horizon=mix(horizon,vec3(.67,.34,.16),horizon_warmth);
 zenith=mix(zenith,vec3(.06,.11,.24),horizon_warmth);
 vec3 color=mix(horizon,zenith,pow(height,.48));
 vec2 uv=EYEDIR.xz/max(.08,EYEDIR.y+.13)*1.75+vec2(4.2,8.5);
 float density=cloud_field(uv);
 float cloud=smoothstep(.64-cloud_cover*.24,.82-cloud_cover*.29,density);
 cloud*=smoothstep(.015,.16,height);
 float depth=smoothstep(.42,.75,density);
 vec3 lit_cloud=mix(vec3(.68,.76,.83),vec3(1.15,1.09,.96),1.0-depth*.65);
 lit_cloud=mix(lit_cloud,lit_cloud*vec3(1.1,.76,.52),horizon_warmth*.65);
 vec3 clouds=mix(lit_cloud,mix(vec3(.34,.39,.44),vec3(.17,.22,.28),depth),storm);
 color=mix(color,clouds,cloud);
 if(LIGHT0_ENABLED){
  float sun=max(dot(EYEDIR,LIGHT0_DIRECTION),0.0);
  color+=vec3(.65,.38,.15)*pow(sun,12.0)*.20*(1.0-storm)*(1.0-cloud*.8);
  color+=vec3(1.0,.75,.44)*pow(sun,256.0)*.35*(1.0-storm)*(1.0-cloud);
  color+=vec3(5.0,3.8,2.4)*smoothstep(.99972,.99996,sun)*(1.0-storm)*(1.0-cloud);
 }
 COLOR=color;
}

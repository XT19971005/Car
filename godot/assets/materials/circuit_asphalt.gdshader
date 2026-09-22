shader_type spatial;
varying vec3 world_position;
float hash(vec2 p) {return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float grain=hash(floor(world_position.xz*50.0));
 float fade=1.0-clamp(length(fwidth(world_position.xz))*8.0,0.0,1.0);
 ALBEDO=mix(vec3(.052,.059,.061),vec3(.064,.071,.073),grain*fade+.5*(1.0-fade));
 ROUGHNESS=.87;
 SPECULAR=.25;
}

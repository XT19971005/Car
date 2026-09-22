shader_type spatial;
global uniform float weather_wetness;
varying vec3 world_position;
float hash(vec2 p) {vec3 q=fract(vec3(p.xyx)*.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float grain=noise(world_position.xz*36.0);
 float fade=1.0-clamp(length(fwidth(world_position.xz))*8.0,0.0,1.0);
 ALBEDO=mix(vec3(.052,.059,.061),vec3(.064,.071,.073),grain*fade+.5*(1.0-fade));
 float puddle=smoothstep(.44,.65,noise(world_position.xz*.15));
 ALBEDO*=mix(.90,1.05,noise(world_position.xz*.09));
 ALBEDO*=mix(1.0,.52,weather_wetness);
 ROUGHNESS=mix(.87,mix(.26,.09,puddle),weather_wetness);
 SPECULAR=.25;
}

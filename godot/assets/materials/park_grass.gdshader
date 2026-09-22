shader_type spatial;
render_mode cull_disabled;
global uniform float weather_wetness;
uniform vec3 low_color : source_color = vec3(.085,.14,.045);
uniform vec3 high_color : source_color = vec3(.22,.28,.10);
varying vec3 world_position;
float hash(vec2 p) { vec3 q=fract(vec3(p.xyx)*.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {world_position=(MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;}
void fragment() {
 float patches=noise(world_position.xz*.045)*.75+noise(world_position.xz*.18)*.25;
 vec3 grass=mix(low_color,high_color,patches);
 float fine=noise(world_position.xz*9.0);
 float mowing=.5+.5*sin((world_position.x*.18+world_position.z*.12));
 float distant=1.0-clamp(length(fwidth(world_position.xz))*2.0,0.0,1.0);
 ALBEDO=grass*(.95+(fine-.5)*.10*distant+mowing*.035)*mix(1.0,.78,weather_wetness);
 ROUGHNESS=mix(.98,.82,weather_wetness);
}

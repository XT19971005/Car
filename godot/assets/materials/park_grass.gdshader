shader_type spatial;
render_mode cull_disabled;
uniform vec3 low_color : source_color = vec3(.095,.16,.04);
uniform vec3 high_color : source_color = vec3(.24,.30,.095);
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {world_position=(MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;}
void fragment() {
 float patches=noise(world_position.xz*.045)*.75+noise(world_position.xz*.18)*.25;
 vec3 grass=mix(low_color,high_color,patches);
 float fine=noise(world_position.xz*9.0);
 ALBEDO=grass*(.94+fine*.12);
 ROUGHNESS=1.0;
}

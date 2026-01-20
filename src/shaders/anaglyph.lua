-- src/shaders/anaglyph.lua
return [[
    extern vec2 inputRes;
    
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        float offset = 1.0 / inputRes.x;
        
        vec4 r_channel = Texel(texture, texture_coords + vec2(offset, 0.0));
        vec4 gb_channel = Texel(texture, texture_coords - vec2(offset, 0.0));
        
        return vec4(r_channel.r, gb_channel.g, gb_channel.b, (r_channel.a + gb_channel.a) * 0.5) * color;
    }
]]

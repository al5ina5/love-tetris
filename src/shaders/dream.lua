-- src/shaders/dream.lua
return [[
    extern vec2 inputRes;
    extern float time;
    
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 texel = Texel(texture, texture_coords);
        
        // More pronounced bloom/dreamy effect
        vec4 bloom = vec4(0.0);
        // Vary distance more for a "hazy" breathing look
        float dist = (2.0 + 1.0 * sin(time * 0.5)) / inputRes.x;
        
        bloom += Texel(texture, texture_coords + vec2(-dist, -dist)) * 0.15;
        bloom += Texel(texture, texture_coords + vec2(dist, -dist)) * 0.15;
        bloom += Texel(texture, texture_coords + vec2(-dist, dist)) * 0.15;
        bloom += Texel(texture, texture_coords + vec2(dist, dist)) * 0.15;
        bloom += Texel(texture, texture_coords + vec2(0.0, -dist)) * 0.25;
        bloom += Texel(texture, texture_coords + vec2(0.0, dist)) * 0.25;
        bloom += Texel(texture, texture_coords + vec2(-dist, 0.0)) * 0.25;
        bloom += Texel(texture, texture_coords + vec2(dist, 0.0)) * 0.25;
        
        // Increase bloom weight and add a slight glow to highlights
        vec3 glow = max(vec3(0.0), bloom.rgb - 0.2) * 0.5;
        return (texel + bloom * 0.8 + vec4(glow, 0.0)) * color;
    }
]]

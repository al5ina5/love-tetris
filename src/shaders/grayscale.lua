-- src/shaders/grayscale.lua
return [[
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 texel = Texel(texture, texture_coords);
        float gray = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
        return vec4(gray, gray, gray, texel.a) * color;
    }
]]

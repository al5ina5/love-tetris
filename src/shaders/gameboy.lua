-- src/shaders/gameboy.lua
return [[
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec4 texel = Texel(texture, texture_coords);
        
        // Calculate luminance
        float gray = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
        
        // Gameboy Palette
        vec3 c1 = vec3(0.058, 0.219, 0.058); // #0f380f
        vec3 c2 = vec3(0.188, 0.384, 0.188); // #306230
        vec3 c3 = vec3(0.545, 0.674, 0.058); // #8bac0f
        vec3 c4 = vec3(0.607, 0.737, 0.058); // #9bbc0f
        
        vec3 outColor;
        if (gray < 0.25) outColor = c1;
        else if (gray < 0.5) outColor = c2;
        else if (gray < 0.75) outColor = c3;
        else outColor = c4;
        
        return vec4(outColor, texel.a) * color;
    }
]]

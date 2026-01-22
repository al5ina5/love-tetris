-- src/fx.lua
-- Visual effects system (particles, screen shake, flashes)

local FX = {
    particles = {},
    shakeAmount = 0,
    shakeDuration = 0,
    flashTimer = 0,
    flashDuration = 0.2,
}

function FX:update(dt)
    -- Update particles
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 500 * dt -- gravity
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end

    -- Update screen shake
    if self.shakeDuration > 0 then
        self.shakeDuration = self.shakeDuration - dt
        if self.shakeDuration <= 0 then
            self.shakeAmount = 0
        end
    end

    -- Update flash
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
    end
end

function FX:spawnParticles(x, y, color, count)
    if type(color) ~= "table" then return end
    count = count or 8
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = math.random(50, 200)
        table.insert(self.particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            color = color,
            life = math.random(0.3, 0.6),
            size = math.random(2, 4)
        })
    end
end

function FX:shake(amount, duration)
    self.shakeAmount = amount
    self.shakeDuration = duration
end

function FX:flash()
    self.flashTimer = self.flashDuration
end

function FX:drawParticles()
    for _, p in ipairs(self.particles) do
        local alpha = math.min(1, p.life * 2)
        if type(p.color) == "table" then
            local r, g, b = unpack(p.color)
            love.graphics.setColor(r, g, b, alpha)
            love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
        end
    end
end

function FX:getShake()
    if self.shakeDuration > 0 then
        return (math.random() - 0.5) * self.shakeAmount, (math.random() - 0.5) * self.shakeAmount
    end
    return 0, 0
end

function FX:drawFlash(sw, sh)
    if self.flashTimer > 0 then
        local alpha = (self.flashTimer / self.flashDuration) * 0.5
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end
end

return FX

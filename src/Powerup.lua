Powerup = Class{}

POWERUP_DIMENSION = 16

function Powerup:init(spawnX, spawnY, skin, altSkin)
    -- should be spawned at X,Y coordinates where brick was broken
    self.x = spawnX
    self.y = spawnY
    self.activeSkin = skin
    self.skin = skin
    self.altSkin = altSkin or skin
    self.toggled = false
    -- start us off with no velocity
    self.dy = 0

    -- starting dimensions
    self.width = POWERUP_DIMENSION
    self.height = POWERUP_DIMENSION
end

function Powerup:update(count)
  self.dy = self.dy + .1
  self.y = self.y + self.dy
  if count % 3 == 0 then
    self:toggleSkin()
  end
end

function Powerup:render()
  love.graphics.draw(gTextures['main'], gFrames['powerups'][self.activeSkin], self.x, self.y)
end

function Powerup:collides(target)
    -- first, check to see if the left edge of either is farther to the right
    -- than the right edge of the other
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    -- then check to see if the bottom edge of either is higher than the top
    -- edge of the other
    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end 

    -- if the above aren't true, they're overlapping
    return true
end

function Powerup:toggleSkin()
  if self.toggled then
    self.toggled = false
    self.activeSkin = self.skin
  else
    self.toggled = true
    self.activeSkin = self.altSkin
  end
end

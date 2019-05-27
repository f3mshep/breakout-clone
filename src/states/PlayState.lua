--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = params.balls
    self.level = params.level
    self.powerup = nil
    self.count = 0

    self.recoverPoints = 5000

    -- give ball random starting velocity
    local firstBall = self.balls[1]
    self:addRandomBallVelocity(firstBall)
end

function PlayState:update(dt)

    --  mini binary state machine
    self:handlePause()

    -- update positions based on velocity
    self.paddle:update(dt)

    -- make powerup fall
    self:updatePowerup()

    -- handle your balls
    self:updateBalls(dt)

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
    self.count = self.count + 1
end

function PlayState:updateBalls(dt)
  inPlayBalls = self:getInPlayBalls()
  for k, ball in pairs(inPlayBalls) do
      -- move the ball
      ball:update(dt)

      -- handle ball collisions
      self:updatePaddleCollision(ball)

      -- handle brick collisions
      self:updateBrickCollision(ball)

      -- check if we won
      self:checkWinState(ball)

      -- check if ball left play, and act accordingly
      self:checkFailState(ball)
  end
end

function PlayState:addRandomBallVelocity(ball)
  ball.dx = math.random(-200, 200)
  ball.dy = math.random(-50, -60)
end

function PlayState:checkFailState(ball)
  -- if ball goes below bounds, revert to serve state and decrease health
  if ball.y >= VIRTUAL_HEIGHT then
    if #self:getInPlayBalls() > 1 then
      -- remove ball from play
      ball.inPlay = false
    else
      self.health = self.health - 1
      self.paddle:shrinkPaddle()
      gSounds['hurt']:play()

    if self.health == 0 then
        gStateMachine:change('game-over', {
            score = self.score,
            highScores = self.highScores
        })
    else
        gStateMachine:change('serve', {
            paddle = self.paddle,
            bricks = self.bricks,
            health = self.health,
            score = self.score,
            highScores = self.highScores,
            level = self.level,
            recoverPoints = self.recoverPoints
        })
    end
    end
  end
end

function PlayState:checkWinState(ball)
  -- go to our victory screen if there are no more bricks left
  if self:checkVictory() then
      gSounds['victory']:play()

      gStateMachine:change('victory', {
          level = self.level,
          paddle = self.paddle,
          health = self.health,
          score = self.score,
          highScores = self.highScores,
          ball = ball,
          recoverPoints = self.recoverPoints
      })
  end
end

function PlayState:updatePaddleCollision(ball)
  if ball:collides(self.paddle) then
    -- raise ball above paddle in case it goes below it, then reverse dy
    ball.y = self.paddle.y - 8
    ball.dy = -ball.dy

    --
    -- tweak angle of bounce based on where it hits the paddle
    --

    -- if we hit the paddle on its left side while moving left...
    if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
        ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))

    -- else if we hit the paddle on its right side while moving right...
    elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
        ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
    end

    gSounds['paddle-hit']:play()
  end
end

function PlayState:updatePowerup()
  -- if powerup falls off screen, destroy it
  if self.powerup and self.powerup.y > VIRTUAL_HEIGHT then
    self.powerup = nil
  end
  -- otherwise, continue updating it
  if self.powerup then
    self.powerup:update(self.count)
    -- finally, check if powerup should be activated
    if self:shouldActivatePowerup() then
      self:activePowerup()
    end
  end
end

function PlayState:handlePause()
  if self.paused then
      if love.keyboard.wasPressed('space') then
          self.paused = false
          gSounds['pause']:play()
      else
          return
      end
  elseif love.keyboard.wasPressed('space') then
      self.paused = true
      gSounds['pause']:play()
      return
  end
end

function PlayState:shouldActivatePowerup()
  return self.powerup:collides(self.paddle) and self:isBallPowerupActive()
end

function PlayState:isBallPowerupActive()
  return #self:getInPlayBalls() < 2
end

function PlayState:activePowerup()
  gSounds['confirm']:play()

  for k, ball in pairs(self.balls) do
    ball.inPlay = true
    ball.x = self.paddle.x + (self.paddle.width / 2) - 4
    ball.y = self.paddle.y - 8
    self:addRandomBallVelocity(ball)
  end

end

function PlayState:getInPlayBalls()
  inPlayBalls = {}

  for k, ball in pairs(self.balls) do
    if ball.inPlay then
      table.insert(inPlayBalls, ball)
    end
  end

  return inPlayBalls
end

function PlayState:updateBrickCollision(ball)
  -- detect collision across all bricks with the ball
  for k, brick in pairs(self.bricks) do

      -- only check collision if we're in play
      if brick.inPlay and ball:collides(brick) then

          -- add to score
          self.score = self.score + (brick.tier * 200 + brick.color * 25)

          -- trigger the brick's hit function, which removes it from play
          brick:hit()

          -- if brick gets removed from play, roll die to check if multiple ball powerup happens
          if not brick.inPlay then
            self:rollPowerupChance(brick)
          end

          -- if we have enough points, recover a point of health
          if self.score > self.recoverPoints then
            -- can't go above 3 health
            self.health = math.min(3, self.health + 1)

            -- multiply recover points by 2
            self.recoverPoints = math.min(100000, self.recoverPoints * 2)

            -- grow paddle
            self.paddle:growPaddle()

            -- play recover sound effect
            gSounds['recover']:play()
          end

          --
          -- collision code for bricks
          --
          -- we check to see if the opposite side of our velocity is outside of the brick;
          -- if it is, we trigger a collision on that side. else we're within the X + width of
          -- the brick and should check to see if the top or bottom edge is outside of the brick,
          -- colliding on the top or bottom accordingly
          --

          -- left edge; only check if we're moving right, and offset the check by a couple of pixels
          -- so that flush corner hits register as Y flips, not X flips
          if ball.x + 2 < brick.x and ball.dx > 0 then

              -- flip x velocity and reset position outside of brick
              ball.dx = -ball.dx
              ball.x = brick.x - 8

          -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
          -- so that flush corner hits register as Y flips, not X flips
          elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then

              -- flip x velocity and reset position outside of brick
              ball.dx = -ball.dx
              ball.x = brick.x + 32

          -- top edge if no X collisions, always check
          elseif ball.y < brick.y then

              -- flip y velocity and reset position outside of brick
              ball.dy = -ball.dy
              ball.y = brick.y - 8

          -- bottom edge if no X collisions or top collision, last possibility
          else

              -- flip y velocity and reset position outside of brick
              ball.dy = -ball.dy
              ball.y = brick.y + 16
          end

          -- slightly scale the y velocity to speed up the game, capping at +- 150
          if math.abs(ball.dy) < 150 then
              ball.dy = ball.dy * 1.02
          end

          -- only allow colliding with one brick, for corners
          break
      end
  end
end

function PlayState:rollPowerupChance(target)
  if  self.powerup == nil and self:isBallPowerupActive() then
    if math.random(1,4) == math.random(1,4) then
      self.powerup = Powerup(target.x + target.width / 2, target.y, 7, 8)
    end
  end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    inPlayBalls = self:getInPlayBalls()

    for k, ball in pairs(inPlayBalls) do
      ball:render()
    end

    if self.powerup then
      self.powerup:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end
    end

    return true
end
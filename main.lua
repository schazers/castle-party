-- "Welcome to Jumpy Town!" https://youtu.be/KfyKD959IeM?t=26

local moonshine = require 'moonshine'
local Sounds = require 'src/util/sounds'

local GAME_WIDTH = 400
local GAME_HEIGHT = 670

-- in [0, 1). exponential decay. lower = game gets difficult more quickly
local ENTROPY_FACTOR = 0.9975

local GRAVITY = -1600

local JUMP_STANDARD_LAUNCH_VEL = (GRAVITY / 1.8)
local JUMP_SPRING_LAUNCH_VEL = GRAVITY * 1.5

local MOVING_PLATFORM_SPEED = 60.0

local PLATFORM_HIT_GLOW_DUR = 0.6
local PLAYER_JUMP_GLOW_DUR = PLATFORM_HIT_GLOW_DUR

local avatarImage = nil

local player = {}
local platforms = {}
local num_platforms_cleared
local bg_horiz_line_heights = {}
local NUM_GRID_ROWS = 20
local NUM_GRID_COLS = NUM_GRID_ROWS * (GAME_WIDTH/GAME_HEIGHT)

local PLATFORM_WIDTH = (GAME_WIDTH / 5)
local platform_width = PLATFORM_WIDTH
local PLATFORM_HEIGHT = (GAME_HEIGHT / 35)
local PLATFORM_SPAWN_RATE_DEFAULT = 1.0
local platform_spawn_rate = PLATFORM_SPAWN_RATE_DEFAULT

local screen_effect = screen_effect or moonshine(moonshine.effects.glow)
.chain(moonshine.effects.godsray)
.chain(moonshine.effects.pixelate)
.chain(moonshine.effects.filmgrain)
.chain(moonshine.effects.crt)

screen_effect.pixelate.feedback = 0.0
screen_effect.glow.strength = 5.0
screen_effect.filmgrain.size = 5.0
screen_effect.filmgrain.opacity = 0.5
screen_effect.crt.x = 1.0
screen_effect.crt.y = 1.0
screen_effect.crt.feather = 0.1

screen_effect.godsray.exposure = 0.0

-- carefully set domain of below three numbers 
-- see spawnPlatformAtHeight
local red_platform_chance = 0.08
local blue_platform_chance = 0.18

local function spawnPlatformAtHeight(height)
  newPlatform = {
    x = ((GAME_WIDTH - PLATFORM_WIDTH) * math.random()) + (PLATFORM_WIDTH / 2.0),
    y = height,
    width = platform_width,
    height = PLATFORM_HEIGHT,
    time_since_hit = -1.0,
  }

  local randomType = math.random()

  if randomType < red_platform_chance then
    newPlatform.type = "spring"
  elseif randomType < blue_platform_chance then
    newPlatform.type = "moving"
    newPlatform.x_vel = MOVING_PLATFORM_SPEED
  else
    newPlatform.type = "default"
  end

  platforms[#platforms + 1] = newPlatform
end

local function initSounds()
  Sounds.jump = Sound:new('jump.mp3', 2)
  Sounds.jump:setVolume(0.5)

  Sounds.springJump = Sound:new('spring_jump.mp3', 4)
  Sounds.springJump:setVolume(0.5)

  Sounds.movingPlatform = Sound:new('moving_platform.mp3', 1)
  Sounds.movingPlatform:setVolume(0.06)
  Sounds.movingPlatform:setLooping(true)

  Sounds.movingPlatformBounce = Sound:new('moving_platform_bounce.mp3', 3)
  Sounds.movingPlatformBounce:setVolume(0.3)

  Sounds.ambience = Sound:new('ambience.mp3', 1)
  Sounds.ambience:setVolume(0.2)
  Sounds.ambience:setLooping(true)

  Sounds.music = Sound:new('music.mp3', 1)
  Sounds.music:setVolume(0.2)
  Sounds.music:setLooping(true)
end

local function resetGame()
  total_time_elapsed = 0.0

  screen_effect.crt.x = 1
  screen_effect.crt.y = 1

  Sounds.movingPlatform:stop()
  Sounds.ambience:stop()
  Sounds.ambience:play()

  num_platforms_cleared = 0
  platform_width = PLATFORM_WIDTH
  platform_spawn_rate = PLATFORM_SPAWN_RATE_DEFAULT

  -- reset player
  player.move_speed = 320
  player.width = GAME_WIDTH / 8
  player.height = player.width
  player.x = GAME_WIDTH / 2 - player.width / 2
  player.y = GAME_HEIGHT - player.height - 1
  player.xPrev = player.x
  player.yPrev = player.y
  player.y_velocity = GRAVITY
  player.time_since_jumped = -1.0

  -- clear all data structures
  for platform_idx in pairs(platforms) do
    platforms[platform_idx] = nil
  end

  for idx in pairs(bg_horiz_line_heights) do
    bg_horiz_line_heights[idx] = nil
  end

  -- spawn initial platforms
  platforms[#platforms + 1] = {
    x = GAME_WIDTH / 2 - platform_width / 2,
    y = GAME_HEIGHT * 0.8,
    width = platform_width,
    height = PLATFORM_HEIGHT,
    type = "default",
    time_since_hit = -1.0
  }
  spawnPlatformAtHeight(GAME_HEIGHT * 0.85)
  spawnPlatformAtHeight(GAME_HEIGHT * 0.7)
  spawnPlatformAtHeight(GAME_HEIGHT * 0.65)
  spawnPlatformAtHeight(GAME_HEIGHT * 0.55)
  spawnPlatformAtHeight(GAME_HEIGHT * 0.4)
  spawnPlatformAtHeight(GAME_HEIGHT * 0.3)
  spawnPlatformAtHeight(GAME_HEIGHT * 0.23)
  spawnPlatformAtHeight(GAME_HEIGHT * 0.2)
  spawnPlatformAtHeight(GAME_HEIGHT * 0.14)
  spawnPlatformAtHeight(GAME_HEIGHT * 0.1)
  spawnPlatformAtHeight(GAME_HEIGHT * 0.0)

  -- bg grid lines
  for i = 1, NUM_GRID_ROWS do
    bg_horiz_line_heights[#bg_horiz_line_heights + 1] = {
      y = (i - 1)/NUM_GRID_ROWS * GAME_HEIGHT
    }
  end
end

function love.load()
  math.randomseed(os.time())
  initSounds()
  Sounds.music:play()
  avatarImage = love.graphics.newImage('assets/img/avatar.png')
  resetGame()
end

-- ensure game isn't impossible by adding a platform if necessary
local function ensureGameIsPossible()
  table.sort(platforms, function(left, right)
    return left.y < right.y
  end)

  local biggestAllowedGap = GAME_HEIGHT / 2.8

  for i, platform in ipairs(platforms) do
    -- spawn at top if first platform on screen 
    -- leaves too big of gap at top of screen
    if platform.y > 0 then 
      if platform.y > biggestAllowedGap then
        spawnPlatformAtHeight(-PLATFORM_HEIGHT)
      end
      break
    end

    -- skip last iteration
    if i < #platforms then
      nextPlatform = platforms[i + 1]
      verticalGap = nextPlatform.y - platform.y
      if verticalGap > biggestAllowedGap then
        spawnPlatformAtHeight(platform.y + verticalGap/2.0)
      end
    end
  end
end

local function updateScreenDistortionBasedUponProgress()
  if num_platforms_cleared > 400 then
    -- TODO: how to alter this section to make it more clear?
    screen_effect.crt.x = -1.0
    screen_effect.crt.y = -1.0
  elseif num_platforms_cleared > 260 then
    -- intentionally let amt go into the negative
    amt = 1.0 - ((num_platforms_cleared - 260) / 10)
    warp_amt = 1.0 + amt * math.sin(total_time_elapsed * (0.5 + 5.0))
    screen_effect.crt.x = warp_amt
    screen_effect.crt.y = warp_amt
  elseif num_platforms_cleared > 110 then
    amt = ((num_platforms_cleared - 110) / 150)
    warp_amt = 1.0 + amt * math.sin(total_time_elapsed * (0.5 + (5.0 * amt)))
    screen_effect.crt.x = warp_amt
    screen_effect.crt.y = warp_amt
    if num_platforms_cleared > 200 then
      blue_platform_chance = 0.5
    end
  elseif num_platforms_cleared > 100 then
    amt = 1.5 - 0.5 * ((num_platforms_cleared - 100) / 10)
    screen_effect.crt.x = amt
    screen_effect.crt.y = amt
  elseif num_platforms_cleared > 0 then 
    amt = 1.0 + 0.5 * (num_platforms_cleared / 100)
    screen_effect.crt.x = amt
    screen_effect.crt.y = amt
  end
end

function love.update(dt)
  if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
    player.x = player.x + (player.move_speed * dt)
    if player.x > GAME_WIDTH - player.width then
      player.x = GAME_WIDTH - player.width
    end
  elseif love.keyboard.isDown("a") or love.keyboard.isDown("left") then
    player.x = player.x - (player.move_speed * dt)
    if player.x < 0 then
      player.x = 0
    end
  end

  player.y = player.y + player.y_velocity * dt
  player.y_velocity = player.y_velocity - GRAVITY * dt

  if player.y > GAME_HEIGHT * 6.6 then
    resetGame()
    return
  end

  -- for all existing platforms
  local platformPlayerHit = nil
  local movingPlatformIsOnscreen = false
  for i = #platforms, 1, -1 do
    local platform = platforms[i]

    -- update moving platforms
    if platform.type == "moving" then
      if platform.x + platform.width > GAME_WIDTH then
        platform.x = GAME_WIDTH - platform.width
        platform.x_vel = -platform.x_vel
        Sounds.movingPlatformBounce:play()
      elseif platform.x < 0 then
        platform.x = 0
        platform.x_vel = -platform.x_vel
        Sounds.movingPlatformBounce:play()
      end
      platform.x = platform.x + platform.x_vel * dt
      movingPlatformIsOnscreen = true
    end

    -- update platform's time for animation if was touched
    if platform.time_since_hit > 0.0 then
      if platform.time_since_hit > PLATFORM_HIT_GLOW_DUR then
        platform.time_since_hit = -1.0
      else
        platform.time_since_hit = platform.time_since_hit + dt
      end
    end

    -- handle collisions with player
    if player.yPrev + player.height < platform.y and player.y + player.height > platform.y and
       player.x + player.width > platform.x and player.x < platform.x + platform.width and
       player.y + player.height > 0
    then
      platformPlayerHit = platform
    end

    -- remove platforms when they go off bottom of screen
    if (platform.y > GAME_HEIGHT) then
      num_platforms_cleared = num_platforms_cleared + 1
      table.remove(platforms, i)

      -- maybe spawn a new platform at a small offset above screen's top
      local shouldSpawnPlatform = (math.random() < platform_spawn_rate)
      if (shouldSpawnPlatform) then
        spawnPlatformAtHeight(-PLATFORM_HEIGHT)
      end

      -- Try exponential decay on platform spawn rate
      platform_spawn_rate = platform_spawn_rate * ENTROPY_FACTOR
      platform_width = platform_width * ENTROPY_FACTOR
    end

    -- slide platforms downward as player is above threshold on screen
    local camera_threshold = (GAME_HEIGHT / 2.0) - (player.height / 2.0)
    if player.y < camera_threshold and player.y_velocity < 0 then
      player.y = camera_threshold - 1
      platform.y = platform.y - player.y_velocity * dt

      -- bg grid lines
      for i = 1, NUM_GRID_ROWS do
        line = bg_horiz_line_heights[i]
        line.y = line.y - player.y_velocity * dt

        -- wrap
        if line.y < 0 then
          line.y = line.y + GAME_HEIGHT
        elseif line.y > GAME_HEIGHT then
          line.y = line.y - GAME_HEIGHT
        end
      end
    end
  end

  if movingPlatformIsOnscreen then
    Sounds.movingPlatform:play()
  else
    Sounds.movingPlatform:stop()
  end

  if platformPlayerHit ~= nil then
    player.time_since_jumped = 0.01
    platformPlayerHit.time_since_hit = 0.01
    player.y = platformPlayerHit.y - player.height
    if platformPlayerHit.type == "default" or platformPlayerHit.type == "moving" then
      player.y_velocity = JUMP_STANDARD_LAUNCH_VEL
      Sounds.jump:play()
    elseif platformPlayerHit.type == "spring" then
      player.y_velocity = JUMP_SPRING_LAUNCH_VEL
      Sounds.springJump:play()
    end
  end

  if player.time_since_jumped > PLAYER_JUMP_GLOW_DUR then
    player.time_since_jumped = -1.0
  else 
    player.time_since_jumped = player.time_since_jumped + dt
  end

  ensureGameIsPossible()
  updateScreenDistortionBasedUponProgress()

  player.xPrev = player.x
  player.yPrev = player.y

  total_time_elapsed = total_time_elapsed + dt
end

function love.draw()
  screen_effect(function()
    -- center game within castle window
    love.graphics.push()
    gTranslateScreenToCenterDx = 0.5 * (love.graphics.getWidth() - GAME_WIDTH)
    gTranslateScreenToCenterDy = 0.5 * (love.graphics.getHeight() - GAME_HEIGHT)
    love.graphics.translate(gTranslateScreenToCenterDx, gTranslateScreenToCenterDy)
    love.graphics.setScissor(
        gTranslateScreenToCenterDx, gTranslateScreenToCenterDy,
        GAME_WIDTH + 1, GAME_HEIGHT + 1)
  
    -- bg
    love.graphics.setColor(0.20, 0.20, 0.26, 1.0)
    love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)

    -- bg gridlines
    love.graphics.setLineWidth(4.0)
    love.graphics.setColor(0.1, 0.1, 0.1, 1.0)
    for i = 1, #bg_horiz_line_heights do
      local line = bg_horiz_line_heights[i]
      love.graphics.line(0, line.y, GAME_WIDTH, line.y) 
    end

    for i = 1, NUM_GRID_COLS do
      local x = i/NUM_GRID_COLS * GAME_WIDTH
      love.graphics.line(x, 0, x, GAME_HEIGHT)
    end

    -- platforms
    for i = 1, #platforms do
      plat = platforms[i]

      -- platforms glow for a bit when hit
      local extra = 0.0
      if plat.time_since_hit > 0.0 then
        extra = 0.3 * (1.0 - (plat.time_since_hit/PLATFORM_HIT_GLOW_DUR))
      end

      if plat.type == "default" then
        love.graphics.setColor(0.4 + extra, 1.0, 0.4 + extra, 1.0)
      elseif plat.type == "moving" then
        love.graphics.setColor(0.4 + extra, 0.4 + extra, 1.0, 1.0)
      elseif plat.type == "spring" then 
        love.graphics.setColor(1.0, 0.4 + extra, 0.4 + extra, 1.0)
      end

      love.graphics.rectangle("fill", plat.x, plat.y, plat.width, plat.height, plat.width/16, plat.height/16, 32)
    end

    -- player
    local playerExtra = 0.0
    if player.time_since_jumped > 0.0 then
      playerExtra = 0.2 * (1.0 - (player.time_since_jumped/PLAYER_JUMP_GLOW_DUR))
    end
    love.graphics.setColor(0.8 + playerExtra, 0.8 + playerExtra, 0.8 + playerExtra, 1.0)
    love.graphics.draw(avatarImage, player.x, player.y, 0, 0.056, 0.056, 0, 0)

    -- frame
    --love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    --love.graphics.rectangle("line", 0, 0, GAME_WIDTH, GAME_HEIGHT)

    -- score
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(tostring(num_platforms_cleared), 16, 16, 0, 3, 3)

    -- restore translation to state before centering window
    love.graphics.pop()
  end) -- end effect function
end

-- "Welcome to Jumpy Town!" https://youtu.be/KfyKD959IeM?t=26

local GAME_WIDTH = 250
local GAME_HEIGHT = 415

local GRAVITY = -1000

local JUMP_STANDARD_LAUNCH_VEL = (GRAVITY / 1.8)
local JUMP_SPRING_LAUNCH_VEL = GRAVITY * 1.5

local player = {}
local platforms = {}
local num_platforms_cleared

local PLATFORM_WIDTH = (GAME_WIDTH / 5)
local PLATFORM_HEIGHT = (GAME_HEIGHT / 35)
local platform_spawn_rate = 1.0

local function spawnPlatformAtHeight(height)
  local randFloat = math.random()

  newPlatform = {
    x = (GAME_WIDTH * randFloat) - (PLATFORM_WIDTH / 2.0),
    y = height,
    width = PLATFORM_WIDTH,
    height = PLATFORM_HEIGHT,
  }

  local randomType = math.random()

  if randomType < 0.05 then
    newPlatform.type = "spring"
  elseif randomType < 0.2 then
    newPlatform.type = "moving"
  else
    newPlatform.type = "default"
  end

  platforms[#platforms + 1] = newPlatform
end

local function resetGame()
  num_platforms_cleared = 0

  -- reset player
  player.move_speed = 250
  player.width = 32
  player.height = 32
  player.x = GAME_WIDTH / 2 - player.width / 2
  player.y = GAME_HEIGHT / 2
  player.xPrev = player.x
  player.yPrev = player.y
  player.y_velocity = 0

  -- clear all platforms
  for platform_idx in pairs(platforms) do
    platforms[platform_idx] = nil
  end

  -- spawn initial platforms
  platforms[#platforms + 1] = {
    x = GAME_WIDTH / 2 - PLATFORM_WIDTH / 2,
    y = GAME_HEIGHT * 0.8,
    width = PLATFORM_WIDTH,
    height = PLATFORM_HEIGHT,
    type = "default"
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
end

function love.load()
  math.randomseed(os.time())
  resetGame()
end

-- ensure game isn't impossible by adding a platform if necessary
local function ensureGameIsPossible()
  table.sort(platforms, function(left, right)
    return left.y < right.y
  end)

  local biggestAllowedGap = GAME_HEIGHT / 2.8

  -- check all other platform gaps
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

  if player.y > GAME_HEIGHT then
    resetGame()
    return
  end

  -- for all existing platforms
  local platformPlayerHit = nil
  for i = #platforms, 1, -1 do
    local platform = platforms[i]

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
      platform_spawn_rate = platform_spawn_rate * 0.9975
    end

    -- slide platforms downward as player is above threshold on screen
    local camera_threshold = (GAME_HEIGHT / 2.0) - (player.height / 2.0)
    if player.y < camera_threshold and player.y_velocity < 0 then
      player.y = camera_threshold - 1
      platform.y = platform.y - player.y_velocity * dt
    end
  end

  if platformPlayerHit ~= nil then
    player.y = platformPlayerHit.y - player.height
    if platformPlayerHit.type == "default" or platformPlayerHit.type == "moving" then
      player.y_velocity = JUMP_STANDARD_LAUNCH_VEL
    elseif platformPlayerHit.type == "spring" then
      player.y_velocity = JUMP_SPRING_LAUNCH_VEL
    end
  end

  ensureGameIsPossible()

  player.xPrev = player.x
  player.yPrev = player.y
end

function love.draw()
  -- center game within castle window
  love.graphics.push()
  gTranslateScreenToCenterDx = 0.5 * (love.graphics.getWidth() - GAME_WIDTH)
  gTranslateScreenToCenterDy = 0.5 * (love.graphics.getHeight() - GAME_HEIGHT)
  love.graphics.translate(gTranslateScreenToCenterDx, gTranslateScreenToCenterDy)
  love.graphics.setScissor(
      gTranslateScreenToCenterDx, gTranslateScreenToCenterDy,
      GAME_WIDTH + 1, GAME_HEIGHT + 1)

  -- bg
  love.graphics.setColor(0.1, 0.1, 0.1, 1.0)
  love.graphics.rectangle("fill", 0, 0, GAME_WIDTH, GAME_HEIGHT)

  -- platforms
  for i = 1, #platforms do
    plat = platforms[i]
    if plat.type == "default" then
      love.graphics.setColor(0.4, 1.0, 0.4, 1.0)
    elseif plat.type == "moving" then
      love.graphics.setColor(0.4, 0.4, 1.0, 1.0)
    elseif plat.type == "spring" then 
      love.graphics.setColor(1.0, 0.4, 0.4, 1.0)
    end

    love.graphics.rectangle("fill", plat.x, plat.y, PLATFORM_WIDTH, PLATFORM_HEIGHT)
  end

  -- player
  love.graphics.setColor(1.0, 0.4, 0.4, 1.0)
  love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)

  -- frame
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  love.graphics.rectangle("line", 0, 0, GAME_WIDTH, GAME_HEIGHT)

  -- score
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(tostring(num_platforms_cleared), 16, 16, 0, 3, 3  )

  -- restore translation to state before centering window
  love.graphics.pop()
end

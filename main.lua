-- "Welcome to Jumpy Town!" https://youtu.be/KfyKD959IeM?t=26

local GAME_WIDTH = 250
local GAME_HEIGHT = 415

local GRAVITY = -1200

local player = {}
local platforms = {}
local num_platforms_cleared

local PLATFORM_WIDTH = (GAME_WIDTH / 5)
local PLATFORM_HEIGHT = (GAME_HEIGHT / 35)
local platform_spawn_rate = 12.0

local function spawnPlatformAtHeight(height)
  local randFloat = math.random()
  platforms[#platforms + 1] = {
    x = GAME_WIDTH * randFloat,
    y = height,
    width = PLATFORM_WIDTH,
    height = PLATFORM_HEIGHT,
  }
end

local function resetGame()
  num_platforms_cleared = 0

  -- reset player
  player.move_speed = 250
  player.width = 32
  player.height = 32
  player.x = GAME_WIDTH / 2 + player.width / 2
  player.y = GAME_HEIGHT / 2
  player.xPrev = player.x
  player.yPrev = player.y
  player.y_velocity = -5
  player.jump_initial_velocity = GRAVITY / 2

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
  }
  spawnPlatformAtHeight(GAME_HEIGHT * 0.5)
  spawnPlatformAtHeight(GAME_HEIGHT * 0.3)
end

function love.load()
  math.randomseed(os.time())
  resetGame()
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
  local didHitPlatform = false
  for i = #platforms, 1, -1 do
    local platform = platforms[i]

    -- handle collisions with player
    if player.yPrev + player.height < platform.y and player.y + player.height > platform.y and
       player.x + player.width > platform.x and player.x < platform.x + platform.width and
       player.y + player.height > 0 
    then
      didHitPlatform = true
    end

    -- remove platforms when they go off bottom of screen
    if (platform.y > GAME_HEIGHT) then
      num_platforms_cleared = num_platforms_cleared + 1
      -- TRY exponential decay
      platform_spawn_rate = platform_spawn_rate - (platform_spawn_rate / 4)
      table.remove(platforms, i)
    end

    -- slide platforms downward as player is above threshold on screen
    local threshold = (GAME_HEIGHT / 2.3)
    if player.y < threshold and player.y_velocity < 0 then
      platform.y = platform.y + (player.yPrev - player.y)
    end
  end

  if didHitPlatform then
    player.y_velocity = player.jump_initial_velocity

    -- spawn platform
    for num = 1, platform_spawn_rate/10 do
      local shouldSpawnPlatform = (math.random() < platform_spawn_rate * dt)
      if (shouldSpawnPlatform) then
        -- TODO: platforms should be generated above the current highest platform
        spawnPlatformAtHeight(-PLATFORM_HEIGHT * (PLATFORM_HEIGHT * 10.0 * math.random()))
      end
    end

    spawnPlatformAtHeight(-PLATFORM_HEIGHT)
  end

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

  -- player
  love.graphics.setColor(1.0, 0.4, 0.4, 1.0)
  love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)

  -- platforms
  love.graphics.setColor(0.4, 1.0, 0.4, 1.0)
  for i = 1, #platforms do
    love.graphics.rectangle("fill", platforms[i].x, platforms[i].y, PLATFORM_WIDTH, PLATFORM_HEIGHT)
  end

  -- frame
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  love.graphics.rectangle("line", 0, 0, GAME_WIDTH, GAME_HEIGHT)

  -- score
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(tostring(num_platforms_cleared), 16, 16, 0, 3, 3  )

  -- restore translation to state before centering window
  love.graphics.pop()
end

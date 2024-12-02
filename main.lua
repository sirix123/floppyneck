-- flappy neck
-- control the length of your human neck to collect fruit, w increase neck height
-- s decrease neck height, higher the neck more swing
-- and avoid obstacle
-- infinite scroller game, speeds up over time
-- timer running controls the score
-- send stats to leaderboard on sdgames.co

-- main.lua
local http = require("socket.http")

-- http.request{ 
--     url = "https://sdgames.co/floppyneck/randomnames", 
--     sink = ltn12.sink.file(io.stdout)
-- }

local startTime = love.timer.getTime()
local canvas
local crtShader
local windowWidth, windowHeight = 800, 600

-- Load assets and initialize variables
function love.load()
    love.window.setTitle("Floppy Neck")
    crtShader = love.graphics.newShader("crt.glsl")
    canvas = love.graphics.newCanvas(windowWidth, windowHeight, { type = '2d', readable = true })
    love.window.setMode(windowWidth, windowHeight)
    background = love.graphics.newImage("background.jpg")
    scoreFont = love.graphics.newFont( "score_font.ttf" , 20)

    player = { name = "player head", width = 70, height = 70, collisionWidth = nil, collisionHeight = nil }
    player.collisionWidth = player.width + 10
    player.collisionHeight = player.height + 10
    playerHeadXSpawn = 150
    playerHeadYSpawn = 300
    playerNeckSegmentHeight = 40
    playerNeckSegmentJointLength = 40
    playerNeckSegmentWidth = 40
    maxPlayerNeckSegments = 30

    fruits = {}
    fruitTimer = 0
    fruitInterval = 4
    obstacles = {}
    obstacleTimer = 0
    obstacleInterval = 2
    
    score = 0

    love.physics.setMeter(64)
    world = love.physics.newWorld(0, 9.81*64, true)
    objects = {}

    objects.neckSegments = {}
    objects.neckSegments.name = "neck segment"
    objects.neckSegments.image = love.graphics.newImage("neck.png")

    -- joints
    objects.joints = {}

    -- first neck segement
    objects.neckSegments[1] = {}
    objects.neckSegments[1].body = love.physics.newBody(world, playerHeadXSpawn, playerHeadYSpawn - playerNeckSegmentHeight, "dynamic")
    objects.neckSegments[1].shape = love.physics.newRectangleShape(playerNeckSegmentWidth, playerNeckSegmentHeight)
    objects.neckSegments[1].fixture = love.physics.newFixture(objects.neckSegments[1].body, objects.neckSegments[1].shape)
    objects.neckSegments[1].fixture:setDensity(0.1)
    objects.neckSegments[1].body:resetMassData()

    objects.head = {}
    objects.head.name = "player head"
    objects.head.image = love.graphics.newImage("head.png")
    objects.head.body = love.physics.newBody(world, playerHeadXSpawn, playerHeadYSpawn - playerNeckSegmentHeight - player.height, "dynamic")
    objects.head.shape = love.physics.newRectangleShape(player.width, player.height)
    objects.head.fixture = love.physics.newFixture(objects.head.body, objects.head.shape)
    objects.head.fixture:setDensity(0.1)
    objects.head.body:resetMassData()

    objects.neckSegments[1].jointSegmentHead = love.physics.newRopeJoint( objects.neckSegments[1].body  , objects.head.body, objects.neckSegments[1].body:getX(), objects.neckSegments[1].body:getY(), objects.head.body:getX(), objects.head.body:getY(), playerNeckSegmentJointLength + playerNeckSegmentHeight / 2, true)

    objects.ground = {}
    objects.ground.body = love.physics.newBody(world, windowWidth/2, windowHeight+50) 
    objects.ground.shape = love.physics.newRectangleShape(windowWidth, 50)
    objects.ground.fixture = love.physics.newFixture(objects.ground.body, objects.ground.shape)

    objects.leftwall = {}
    objects.leftwall.body = love.physics.newBody(world, -50, windowHeight/2) 
    objects.leftwall.shape = love.physics.newRectangleShape(50, windowHeight)
    objects.leftwall.fixture = love.physics.newFixture(objects.leftwall.body, objects.leftwall.shape)

    objects.rightwall = {}
    objects.rightwall.body = love.physics.newBody(world, windowWidth+50, windowHeight/2) 
    objects.rightwall.shape = love.physics.newRectangleShape(50, windowHeight)
    objects.rightwall.fixture = love.physics.newFixture(objects.rightwall.body, objects.rightwall.shape)

    objects.roof = {}
    objects.roof.body = love.physics.newBody(world, windowWidth/2, -200) 
    objects.roof.shape = love.physics.newRectangleShape(windowWidth, 200)
    objects.roof.fixture = love.physics.newFixture(objects.roof.body, objects.roof.shape)
    
    objects.headAnchorJointDestroyed = false
end

function love.keypressed(key)
    local neckForceMultiplier = 200
    local headForce = 10000 + neckForceMultiplier * #objects.neckSegments
    local neckForce = 3000 + neckForceMultiplier * #objects.neckSegments

    if key == "w"  then 
        objects.head.body:applyForce(0, -headForce)
    elseif key == "s"then
        objects.head.body:applyForce(0, headForce)
    end

    if key == "d" then
        objects.neckSegments[#objects.neckSegments].body:applyForce(neckForce, 0)
    end

    if key == "a" then
        objects.neckSegments[#objects.neckSegments].body:applyForce(-neckForce, 0)
    end

    if key == "r" then
        love.load()
    end

    if key == "escape" then
        love.event.quit()
    end
end

function createNeckSegement()
    if #objects.neckSegments >= maxPlayerNeckSegments then
        return
    end

    local lastSegment = objects.neckSegments[#objects.neckSegments]
    -- create new segement, below the last segement and connect it to the last segement
    local newSegmentBody =  love.physics.newBody(world, lastSegment.body:getX(), lastSegment.body:getY() - playerNeckSegmentHeight * #objects.neckSegments, "dynamic")
    local newSegmentShape = love.physics.newRectangleShape(playerNeckSegmentWidth, playerNeckSegmentHeight)
    local newSegmentFixture = love.physics.newFixture(newSegmentBody, newSegmentShape)
    local density = 0.1
    newSegmentFixture:setDensity(density)
    newSegmentBody:resetMassData()
    local jointSegmentSegment = love.physics.newRopeJoint( lastSegment.body , newSegmentBody , lastSegment.body:getX(), lastSegment.body:getY(), newSegmentBody:getX(), newSegmentBody:getY(), playerNeckSegmentJointLength, false)

    table.insert(objects.neckSegments, { body = newSegmentBody, shape = newSegmentShape, fixture = newSegmentFixture})
end

-- Update game state
function love.update(dt)
    world:update(dt)

    -- obstacle
    obstacleTimer = obstacleTimer + dt
    if obstacleTimer > obstacleInterval then
        table.insert(obstacles, { name = "obstacle", x = 800, y = math.random(windowHeight - 200, 0), width = 30, height = 30 })
        obstacleTimer = 0
    end

    for i, obstacle in ipairs(obstacles) do
        obstacle.x = obstacle.x - 200 * dt
        if obstacle.x < -obstacle.width then
            table.remove(obstacles, i)
        end
    end

    for _, obstacle in ipairs(obstacles) do
        if checkCollisionObjectHead(obstacle, objects.head.body:getX(), objects.head.body:getY(), player.collisionWidth , player.collisionHeight) then
            -- love.load()
            -- print ("collision with obstacle")
        end
    end

    -- fruit
    fruitTimer = fruitTimer + dt
    if fruitTimer > fruitInterval then
        table.insert(fruits, { x = 800, y = math.random(windowHeight - 200, 0), width = 30, height = 30 })
        fruitTimer = 0
    end

    -- move fruit
    for i, fruit in ipairs(fruits) do
        fruit.x = fruit.x - 200 * dt
        if fruit.x < -fruit.width then
            table.remove(fruits, i)
        end
    end

    -- Check for fruit collision
    for i = #fruits, 1, -1 do
        if checkCollisionObjectHead(fruits[i], objects.head.body:getX(), objects.head.body:getY(), player.collisionWidth , player.collisionHeight) then
            table.remove(fruits, i)
            createNeckSegement()
            score = score + 1
        end
    end

end

function love.draw()

    love.graphics.setCanvas(canvas)
    love.graphics.clear()

    love.graphics.setFont(scoreFont)

    local sx = love.graphics.getWidth() / background:getWidth()
    local sy = love.graphics.getHeight() / background:getHeight()
    love.graphics.draw(background,0,-100,sx, sy)


    for _, segment in ipairs(objects.neckSegments) do
        love.graphics.draw( objects.neckSegments.image, segment.body:getX(), segment.body:getY(), segment.body:getAngle(), 0.05, 0.05, 500, 500, 0, 0 )
        love.graphics.polygon("line", segment.body:getWorldPoints(segment.shape:getPoints()))
    end

    love.graphics.polygon("line", objects.head.body:getWorldPoints(objects.head.shape:getPoints()))
    love.graphics.draw( objects.head.image, objects.head.body:getX(), objects.head.body:getY(), 0, 0.05, 0.05, 500,  1000, 0, 0 )

    love.graphics.polygon("fill", objects.ground.body:getWorldPoints(objects.ground.shape:getPoints()))
    love.graphics.polygon("fill", objects.leftwall.body:getWorldPoints(objects.leftwall.shape:getPoints()))
    love.graphics.polygon("fill", objects.rightwall.body:getWorldPoints(objects.rightwall.shape:getPoints()))
    love.graphics.polygon("fill", objects.roof.body:getWorldPoints(objects.roof.shape:getPoints()))

    -- love.graphics.polygon("line", objects.anchor.body:getWorldPoints(objects.anchor.shape:getPoints()))
    -- love.graphics.draw( objects.anchor.image, objects.anchor.body:getX(), objects.anchor.body:getY(), 0, 0.2, 0.1, 200,  300, 0, 0 )

    for _, obstacle in ipairs(obstacles) do
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", obstacle.x, obstacle.y, obstacle.width, obstacle.height)
        love.graphics.setColor(1, 1, 1)
    end

    for _, fruit in ipairs(fruits) do
        love.graphics.setColor(0, 1, 0)
        love.graphics.rectangle("fill", fruit.x, fruit.y, fruit.width, fruit.height)
        love.graphics.setColor(1, 1, 1)
    end

    love.graphics.setColor(1, 1, 1) -- Reset color to white

    love.graphics.print("Score: " .. score, 10, 10)

    love.graphics.setCanvas()
    crtShader:send('millis', love.timer.getTime() - startTime)
    love.graphics.setShader(crtShader)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setShader()

    -- reset
    love.graphics.setColor(1, 1, 1) 
end

-- Check for collision between two rectangles
function checkCollisionObjectHead(object, bodyX, bodyY, bodyWidth, bodyHeight)
    return object.x < bodyX + bodyWidth and
        object.x + object.width > bodyX and
        object.y < bodyY + bodyHeight and
        object.y + object.height > bodyY
end

function fruitParticleExplodeEffect()
    
end


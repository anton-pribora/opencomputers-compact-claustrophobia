-- TREE FARM

local robot     = require("robot")
local component = require("component")
local event     = require("event")
local inventory = component.inventory_controller
local minSlot   = 1
local maxSlot   = robot.inventorySize()

local function selectSlot(material)
  local startSlot = robot.select()

  for i = minSlot, maxSlot do
    local slot = startSlot - minSlot + i

    if slot > maxSlot then
      slot = (slot % maxSlot) + (minSlot - 1)
    end

    local info = inventory.getStackInInternalSlot(slot)

    if info and info.name:find(material) then
      robot.select(slot)
      return slot, info
    end
  end
end

local function dump(material)
  local side = 3  -- Always dump to the front
  local slot = 1  -- Always dump to the first slot of the outside inventory

  while selectSlot(material) do
    inventory.dropIntoSlot(side, slot)
  end
end

local function dumpWood()
  dump(":log")
end

local function dumpApples()
  dump(":apple")
end

local function dumpSaplings()
  dump(":sapling")
  robot.suck(9)
end

local function plant()
  if selectSlot(":sapling") then
    robot.placeDown()
  end
end

local function chopTree()
  local _, block = robot.detectDown()

  if block == "solid" then
    robot.swingDown()
    robot.swingUp()
    robot.up()
    robot.swingUp()
    robot.swingDown()
    robot.down()
  end
end

local function fillWateringCan()
  robot.use()
end

local function water()
  for _ = 1, 20 do
    robot.useDown()
  end
end

local function forward()
  local result = robot.forward()

  while not result do
    robot.swing()
    result = robot.forward()
  end
end

local function run(steps)
  for _, step in pairs(steps) do
    step();
  end
end

-- Steps
local begin = {
  robot.turnAround,
  robot.swingUp, robot.up,
  forward, chopTree, plant,
}

local plantingAndChopping = {
  forward, chopTree, plant,
  forward, chopTree, plant,
  robot.turnLeft,
  forward, chopTree, plant,
  robot.turnLeft,
  forward, chopTree, plant,
  forward, chopTree, plant,
  robot.turnRight,
  forward, chopTree, plant,
  robot.turnRight,
  forward, chopTree, plant,
  forward, chopTree, plant,
  forward, robot.down,
}

local dumpingAndWatering = {
  dumpWood,
  robot.turnRight,
  dumpApples,
  robot.turnAround,
  fillWateringCan,
  robot.turnRight,
  robot.swingUp, robot.up,
  dumpSaplings,
  robot.turnAround,
  forward, chopTree, plant,
  water,
}

-- Equip a watering can if we have it in the inventory
if selectSlot(':watering_can') then
  inventory.equip()
end

-- Main cycle
repeat
  run(begin)
  run(plantingAndChopping)
  run(dumpingAndWatering)
  run(plantingAndChopping)
until event.pull(3, "interrupted")

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

local function plant()
  if selectSlot(":sapling") then
    robot.placeDown()
  end
end

local function chopTree()
  local _, block = robot.detectDown()

  if block == "solid" then
    if not robot.durability() and selectSlot(':*axe') then
      inventory.equip()
    end

    robot.swingDown()
    robot.swingUp()
    robot.up()
    robot.swingUp()
    robot.swingDown()
    robot.down()
  end
end

local function forward()
  local result = robot.forward()

  while not result do
    robot.swing()
    result = robot.forward()
  end
end

local function goChopAndPlant()
  forward()
  chopTree()
  plant()
end

local function fillWateringCan()
  if selectSlot(':watering_can') then
    inventory.equip()
    robot.turnLeft()
    robot.use()
    robot.turnRight()
    inventory.equip()
  end
end

local function watering()
  if selectSlot(':watering_can') then
    inventory.equip()
    for _ = 1, 20 do
      robot.useDown()
    end
    inventory.equip()
  end
end

local function dumpResources()
  for slot = minSlot, maxSlot do
    local info = inventory.getStackInInternalSlot(slot)

    if info and not (info.name:find(':*axe') or info.name:find(':watering_can')) then
      robot.select(slot)
      robot.dropDown()
    end
  end
end

local function takeSaplings()
  robot.down()
  inventory.suckFromSlot(3, 1, 24)
  robot.up()
end

local function run(steps)
  for _, step in pairs(steps) do
    step();
  end
end

-- Steps
local steps = {
  robot.turnAround,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  robot.turnLeft, goChopAndPlant, robot.turnLeft,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  robot.turnRight, goChopAndPlant, robot.turnRight,
  goChopAndPlant,
  goChopAndPlant,
  watering,
  goChopAndPlant,
  goChopAndPlant,
  dumpResources,
  takeSaplings,
  robot.turnLeft, goChopAndPlant, robot.turnLeft,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  robot.turnRight, goChopAndPlant, robot.turnRight,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  robot.turnRight,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  robot.turnRight,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  goChopAndPlant,
  forward,
  fillWateringCan,
}

-- Main cycle
repeat
  run(steps)
until event.pull(3, "interrupted")

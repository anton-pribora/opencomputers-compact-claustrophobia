-- PIG SPAWN EGG 5x5

local materials = {
  ['P'] = 'Pink Wool',     -- If your language in MC is not ENG USA then you have to change those labels
  ['G'] = '^Gray Wool',
  ['@'] = 'Black Wool',
  ['W'] = 'White Wool',
}

local salt  = ':egg'
local pause = 6

local structure = {
  {'PPPPP',
   'PPPPP',
   'PPPPP',
   'PPPPP',
   ' GPG '},

  {'PPPPP',
   'P   P',
   'P   P',
   'PPPPP',
   ' PPP '},

  {'PPPPP',
   'P   P',
   'P   P',
   '@WPW@',
   '     '},

  {'PPPPP',
   'P   P',
   'P   P',
   'PPPPP',
   '     '},

  {'PPPPP',
   'PPPPP',
   'PPPPP',
   'PPPPP',
   '     '},
}

-- Определяем переменные
local program                 = {}  -- Программа действий, которая будет циклично крутиться
local minimumAmountOfMaterial = {}  -- Сколько материалов требуется для рецепта
local placeBlockFunction      = {}  -- Функции для установки блоков из разных материалов

local component = require("component")
local robot     = require("robot")
local event     = require("event")
local inventory = component.inventory_controller
local minSlot   = 1
local maxSlot   = robot.inventorySize()
local args      = {...}                   -- Аргументы программы
local loops     = tonumber(args[1] or 1)  -- Сколько раз нужно повторить программу, берём значение из первого аргумента или 1

-- Поиск и установка слота с нужным материалом
local function selectSlot(material)
  local startSlot = robot.select()

  for i = minSlot, maxSlot do
    local slot = startSlot - minSlot + i

    if slot > maxSlot then
      slot = (slot % maxSlot) + (minSlot - 1)
    end

    local info = inventory.getStackInInternalSlot(slot)

    if info and (info.label:find(material) or info.name:find(material)) then
      robot.select(slot)
      return slot, info
    end
  end
end

-- Функция проверяет, достаточно ли материала в инвентаре
local function checkAmount(material, minAmount)
  local amount = 0

  for i = minSlot, maxSlot do
    local info = inventory.getStackInInternalSlot(i)

    if info and (info.label:find(material) or info.name:find(material)) then
      amount = amount + tonumber(info.size)

      if amount >= minAmount then
        return true
      end
    end
  end

  return false, minAmount - amount
end

-- Установка блока из нужного материала
local function placeBlock(material)
  if selectSlot(material) then
    return robot.placeDown()
  end

  return false, "Not enough " .. material
end

-- Задаём функции для установки блоков из разных материалов
for block, material in pairs(materials) do
  placeBlockFunction[block] = function() return placeBlock(material) end
end

-- Начальный этап, когда робот стоит в одном блоке от будущей конструкции лицом к зарядному устройству
table.insert(program, robot.turnAround)
table.insert(program, robot.forward)
table.insert(program, robot.forward)
table.insert(program, robot.up)

-- Проходим по всей структуре, чтобы построить программу перемещений и заодно посчитаем расход материала
local width, deep, height = #structure[1][1], #structure[1], #structure
local steps  = width * deep * height - 1
local square = width * deep
local dy, dz = 1, 1

for k = 0, width * deep * height - 1 do
  z = math.floor(k / square)
  y = math.floor((k - z * square) / deep)
  x = (k - z * square - y * width) % width

  layer = z + 1
  row = (dz < 1 and deep - y - 1 or y) + 1
  pos = (dy < 1 and width - x - 1 or x) + 1

  local block = structure[layer][row]:sub(pos, pos)

  if block ~= ' ' then
    table.insert(program, placeBlockFunction[block])
    minimumAmountOfMaterial[materials[block]] = (minimumAmountOfMaterial[materials[block]] or 0) + 1
  end

  -- Если закончился ряд
  if (x + 1) % width == 0 then
    dy = dy * -1

    -- Если закончился слой
    if (y + 1) % deep == 0 then dz = dz * -1 end

    -- Разворот в зависимости от положения на рабочем поле
    local turn = (dy * dz < 0) and robot.turnRight or robot.turnLeft

    -- Если закончилась структура
    if k == steps then
      -- Если мы оказались в противоположном углу поля, разворачиваемся и идём домой
      if dz < 0 then
        table.insert(program, turn)
        for _ = 1, deep - 1 do table.insert(program, robot.forward) end
        table.insert(program, turn)
        for _ = 1, width - 1 do table.insert(program, robot.forward) end
        break
      end

    -- Если закончился слой
    elseif (y + 1) % deep == 0 then
      table.insert(program, robot.up)
      table.insert(program, turn)
      table.insert(program, turn)

    -- Если закончился ряд
    else
      table.insert(program, turn)
      table.insert(program, robot.forward)
      table.insert(program, turn)
    end
  else
      table.insert(program, robot.forward)
  end
end

-- Идём навстречу заряднику
table.insert(program, robot.forward)
table.insert(program, robot.forward)

-- Бросаем "соль" на конструкцию, чтобы запустить рецепт
minimumAmountOfMaterial[salt] = (minimumAmountOfMaterial[salt] or 0) + 1
table.insert(program, function()
  if selectSlot(salt) then
    robot.turnAround()
    robot.drop(1)
    robot.turnAround()

    return true
  end

  return false, "Not enough " .. salt
end)

-- Спускаемся вниз
for _ = 1, #structure do
  table.insert(program, robot.down)
end

-- Мы пришли к заряднику и встали в начальную позицию для следующего цикла

robot.setLightColor(0x00FF00)  -- Меняем цвет на рабочий

-- Запускаем основной цикл
while loops > 0 do
  -- Проверяем наличие материалов
  local enough = true

  for material, amount in pairs(minimumAmountOfMaterial) do
    local result, deficit = checkAmount(material, amount)

    if not result then
      print(string.format("Not enough %s need %d more", material, deficit))
      enough = false
    end
  end

  -- Если материалов не хватит, прерываем работу
  if not enough then break end

  -- Запускаем программу
  for _, step in pairs(program) do
    if step then
      repeat
        local result, error = step()

        if not result then
          print("Error: " .. tostring(error))
          component.computer.beep()
        end
      until result
    end
  end

  loops = loops - 1

  -- Пару раз вертимся, чтобы получить предметы, если в нас их кто-то пихает
  robot.turnAround()
  robot.turnAround()

  -- Если есть следующий цикл, включаем паузу
  if loops > 0 then
    -- Точнее ждём, пока кто-нибудь прервёт выполнение программы
    if event.pull(pause, "interrupted") then break end
  end
end

robot.setLightColor(0xF23030)   -- Меняем цвет на обычный

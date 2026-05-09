local cachePath = nil
local events = {}
local lastRead = 0

local rowY = {94, 134, 174, 214, 254, 294}
local hiddenColor = '255,255,255,0'
local mutedColor = '205,214,224,230'
local activeColor = '255,199,50,255'

local function read_file(path)
  local file = io.open(path, 'r')
  if not file then return nil end
  local text = file:read('*a')
  file:close()
  return text
end

local function trim(value)
  return (value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function read_cache()
  local text = read_file(cachePath)
  if not text then return end

  local vars = {}
  for line in text:gmatch('[^\r\n]+') do
    local key, value = line:match('^([^=]+)=(.*)$')
    if key and value then
      vars[trim(key)] = trim(value)
    end
  end

  events = {}
  local count = tonumber(vars.EventCount or '0') or 0
  for i = 1, count do
    local startEpoch = tonumber(vars['Event' .. i .. 'StartEpoch'] or '0') or 0
    local endEpoch = tonumber(vars['Event' .. i .. 'EndEpoch'] or '0') or 0
    table.insert(events, {
      title = vars['Event' .. i .. 'Title'] or '',
      location = vars['Event' .. i .. 'Location'] or '',
      time = vars['Event' .. i .. 'Time'] or '',
      endTime = vars['Event' .. i .. 'EndTime'] or '',
      date = vars['Event' .. i .. 'Date'] or '',
      startEpoch = startEpoch,
      endEpoch = endEpoch,
      allDay = vars['Event' .. i .. 'AllDay'] == '1',
      color = vars['Event' .. i .. 'Color'] or mutedColor
    })
  end

  SKIN:Bang('!SetVariable', 'LastUpdated', vars.LastUpdated or 'Not updated')
  SKIN:Bang('!SetVariable', 'SourceStatus', vars.SourceStatus or 'No calendar data')
end

local function format_countdown(seconds)
  if seconds < 0 then seconds = 0 end
  if seconds < 3600 then
    return tostring(math.max(1, math.ceil(seconds / 60))), 'min'
  end
  if seconds < 86400 then
    local hours = math.floor(seconds / 3600)
    local minutes = math.ceil((seconds % 3600) / 60)
    if minutes >= 60 then
      hours = hours + 1
      minutes = 0
    end
    if minutes == 0 then
      return tostring(hours), 'hr'
    end
    return tostring(hours .. 'h ' .. minutes), 'min'
  end
  return tostring(math.ceil(seconds / 86400)), 'day'
end

local function clear_row(slot)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Time', '')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Title', '')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Location', '')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Color', hiddenColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'TextColor', '255,255,255,0')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'SubColor', '255,255,255,0')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DotSize', '5')
end

local function set_row(slot, event, active)
  local textColor = active and '255,226,84,255' or '245,247,252,238'
  local subColor = active and '230,214,156,238' or '170,178,190,226'
  local color = active and activeColor or event.color

  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Time', event.time)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Title', event.title)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Location', event.location)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Color', color)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'TextColor', textColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'SubColor', subColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DotSize', active and '12' or '8')
end

local function find_selected(now)
  if #events == 0 then return 0, 'No events', 0 end

  for i, event in ipairs(events) do
    if now >= event.startEpoch and now < event.endEpoch then
      return i, 'ENDS', event.endEpoch - now
    end
    if now < event.startEpoch then
      return i, 'NEXT', event.startEpoch - now
    end
  end

  return #events, 'DONE', 0
end

function Initialize()
  cachePath = SKIN:MakePathAbsolute(SELF:GetOption('CachePath'))
  read_cache()
  lastRead = os.time()
end

function ReadAgenda()
  read_cache()
  lastRead = os.time()
  Update()
end

function Update()
  local now = os.time()
  if now - lastRead > 30 then
    read_cache()
    lastRead = now
  end

  local selected, label, seconds = find_selected(now)
  local number, unit = format_countdown(seconds)

  SKIN:Bang('!SetVariable', 'CountdownLabel', label)
  SKIN:Bang('!SetVariable', 'CountdownNumber', number)
  SKIN:Bang('!SetVariable', 'CountdownUnit', unit)

  if selected == 0 then
    SKIN:Bang('!SetVariable', 'HeaderDate', os.date('%a  %d %b'):upper())
    SKIN:Bang('!SetVariable', 'CountdownY', '146')
    for slot = 1, 6 do clear_row(slot) end
  else
    local startIndex = selected - 2
    if startIndex < 1 then startIndex = 1 end
    if #events > 6 and startIndex > #events - 5 then startIndex = #events - 5 end

    local activeSlot = selected - startIndex + 1
    if activeSlot < 1 then activeSlot = 1 end
    if activeSlot > 6 then activeSlot = 6 end

    SKIN:Bang('!SetVariable', 'HeaderDate', events[selected].date)
    SKIN:Bang('!SetVariable', 'CountdownY', tostring(rowY[activeSlot] - 20))
    SKIN:Bang('!SetVariable', 'ActiveRuleY', tostring(rowY[activeSlot] + 8))

    for slot = 1, 6 do
      local event = events[startIndex + slot - 1]
      if event then
        set_row(slot, event, startIndex + slot - 1 == selected)
      else
        clear_row(slot)
      end
    end
  end

  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
  return ''
end

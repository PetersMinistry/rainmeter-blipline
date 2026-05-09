local cachePath = nil
local events = {}
local lastRead = 0
local scrollCurrent = 0
local scrollTarget = 0
local userScrolled = false

local rowBaseY = {94, 134, 174, 214, 254, 294}
local rowGap = 40
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

local function read_number_variable(name, fallback, minValue, maxValue)
  local value = tonumber(SKIN:GetVariable(name) or '') or fallback
  if minValue and value < minValue then value = minValue end
  if maxValue and value > maxValue then value = maxValue end
  return math.floor(value)
end

local function clamp(value, minValue, maxValue)
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

local function max_scroll(maxRows)
  return math.max(0, #events - maxRows)
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
      notes = vars['Event' .. i .. 'Notes'] or '',
      calendar = vars['Event' .. i .. 'Calendar'] or '',
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
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Y', tostring(rowBaseY[slot] or 94))
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Time', '')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Title', '')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Location', '')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Color', hiddenColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'TextColor', '255,255,255,0')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'SubColor', '255,255,255,0')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DotSize', '5')
end

local function row_time_label(event, headerDate)
  if event.date ~= '' and headerDate ~= '' and event.date ~= headerDate then
    return event.date:sub(1, 3) .. ' ' .. event.time
  end
  return event.time
end

local function set_row(slot, event, active, headerDate, y)
  local style = SKIN:GetVariable('TimelineStyle') or 'Glass'
  local textColor = active and '255,226,84,255' or '245,247,252,238'
  local subColor = active and '230,214,156,238' or '170,178,190,226'
  local color = active and activeColor or event.color
  local detailParts = {}
  if event.calendar ~= '' then table.insert(detailParts, event.calendar) end
  if event.location ~= '' then table.insert(detailParts, event.location) end
  if style == 'Dense' and event.notes ~= '' then table.insert(detailParts, event.notes) end
  local detail = table.concat(detailParts, '  |  ')
  if detail == '' then
    detail = event.location
  end
  if style == 'Focus' and not active then
    detail = ''
  end

  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Y', tostring(math.floor(y + 0.5)))
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Time', row_time_label(event, headerDate))
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Title', event.title)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Location', detail)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Color', color)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'TextColor', textColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'SubColor', subColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DotSize', active and '12' or '8')
end

local function apply_style()
  local style = SKIN:GetVariable('TimelineStyle') or 'Glass'
  if style == 'Dense' then
    SKIN:Bang('!SetVariable', 'RowTitleSize', '10')
    SKIN:Bang('!SetVariable', 'RowSubSize', '8')
    SKIN:Bang('!SetVariable', 'RowTitleW', '238')
    SKIN:Bang('!SetVariable', 'RowDetailW', '246')
    SKIN:Bang('!SetVariable', 'PanelFill', '10,14,20,166')
  elseif style == 'Focus' then
    SKIN:Bang('!SetVariable', 'RowTitleSize', '12')
    SKIN:Bang('!SetVariable', 'RowSubSize', '8')
    SKIN:Bang('!SetVariable', 'RowTitleW', '238')
    SKIN:Bang('!SetVariable', 'RowDetailW', '246')
    SKIN:Bang('!SetVariable', 'PanelFill', '8,11,16,178')
  else
    SKIN:Bang('!SetVariable', 'RowTitleSize', '12')
    SKIN:Bang('!SetVariable', 'RowSubSize', '9')
    SKIN:Bang('!SetVariable', 'RowTitleW', '238')
    SKIN:Bang('!SetVariable', 'RowDetailW', '246')
    SKIN:Bang('!SetVariable', 'PanelFill', '12,16,22,150')
  end
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
  userScrolled = false
  Update()
end

function Scroll(direction)
  local maxRows = read_number_variable('MaxRows', 6, 1, 6)
  local step = read_number_variable('ScrollStep', 1, 1, 6)
  local amount = tonumber(direction or '0') or 0
  if amount == 0 then return '' end

  scrollTarget = clamp(scrollTarget + (amount * step), 0, max_scroll(maxRows))
  scrollCurrent = scrollTarget
  userScrolled = true
  Update()
  return ''
end

function CenterNow()
  userScrolled = false
  Update()
  return ''
end

function Update()
  local now = os.time()
  local maxRows = read_number_variable('MaxRows', 6, 1, 6)
  apply_style()
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
    local anchor = clamp(selected - 2, 0, max_scroll(maxRows))
    if not userScrolled then
      scrollTarget = anchor
      scrollCurrent = anchor
    end

    scrollTarget = clamp(scrollTarget, 0, max_scroll(maxRows))
    scrollCurrent = clamp(scrollCurrent, 0, max_scroll(maxRows))

    local startIndex = math.floor(scrollCurrent) + 1
    local fractional = scrollCurrent - math.floor(scrollCurrent)
    local activeSlot = selected - startIndex + 1
    local selectedVisible = activeSlot >= 1 and activeSlot <= maxRows
    local activeY = rowBaseY[1] + ((selected - 1 - scrollCurrent) * rowGap)
    local pointerY = clamp(activeY, rowBaseY[1], rowBaseY[maxRows])

    local headerDate = events[startIndex].date
    SKIN:Bang('!SetVariable', 'HeaderDate', headerDate)
    SKIN:Bang('!SetVariable', 'CountdownY', tostring(math.floor(pointerY - 20 + 0.5)))
    SKIN:Bang('!SetVariable', 'ActiveRuleY', tostring(math.floor(pointerY + 8 + 0.5)))

    for slot = 1, 6 do
      local event = events[startIndex + slot - 1]
      if event and slot <= maxRows then
        local y = rowBaseY[slot] - (fractional * rowGap)
        set_row(slot, event, selectedVisible and startIndex + slot - 1 == selected, headerDate, y)
      else
        clear_row(slot)
      end
    end
  end

  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
  return ''
end

local cachePath = nil
local events = {}
local lastRead = 0
local scrollCurrent = 0
local scrollTarget = 0
local userScrolled = false
local homeAnimating = false
local lastRenderSecond = -1

local rowBaseY = {94, 134, 174, 214, 254, 294}
local rowGap = 40
local hiddenColor = '255,255,255,0'
local mutedColor = '205,214,224,230'
local activeColor = '255,199,50,255'
local noShape = 'Rectangle 0,0,0,0 | Fill Color 0,0,0,0 | StrokeWidth 0'
local iconFg = '250,253,255,242'
local iconDim = '8,12,18,86'
local daySeparatorGap = 20

local function skin_var(name, fallback)
  local value = SKIN:GetVariable(name)
  if value == nil or value == '' then return fallback end
  return value
end

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

local function read_bool_variable(name, fallback)
  local value = SKIN:GetVariable(name)
  if value == nil or value == '' then return fallback end
  value = tostring(value):lower()
  return value == '1' or value == 'true' or value == 'yes' or value == 'on'
end

local function clamp(value, minValue, maxValue)
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

local function max_scroll(maxRows)
  return math.max(0, #events - maxRows)
end

local function color_alpha(color, alpha)
  local r, g, b = (color or ''):match('^(%d+),(%d+),(%d+)')
  if not r then return color or hiddenColor end
  return r .. ',' .. g .. ',' .. b .. ',' .. tostring(alpha)
end

local function icon_shapes(icon, color)
  if icon == '' then
    return noShape, noShape, noShape, noShape, noShape
  end

  local base = 'Rectangle 0,0,18,18,5 | Fill Color ' .. color .. ' | StrokeWidth 1 | Stroke Color 255,255,255,58'

  if icon == 'MEAL' then
    return base,
      'Rectangle 5,4,1.4,10,1 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Rectangle 8,4,1.4,10,1 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Rectangle 12,4,1.6,10,1 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Ellipse 4,3,3,3 | Fill Color ' .. iconFg .. ' | StrokeWidth 0'
  end

  if icon == 'SUN' then
    return base,
      'Ellipse 6,6,6,6 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Line 9,3,9,5 | StrokeWidth 1 | Stroke Color ' .. iconFg,
      'Line 4,9,6,9 | StrokeWidth 1 | Stroke Color ' .. iconFg,
      'Line 12,12,14,14 | StrokeWidth 1 | Stroke Color ' .. iconFg
  end

  if icon == 'BOOK' then
    return base,
      'Rectangle 4,5,5,8,1 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Rectangle 10,5,5,8,1 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Line 9,5,9,14 | StrokeWidth 1 | Stroke Color ' .. iconDim,
      'Line 5,7,8,7 | StrokeWidth 1 | Stroke Color ' .. iconDim
  end

  if icon == '+' then
    return base,
      'Rectangle 8,4,2,10,1 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Rectangle 5,7,8,2,1 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      noShape,
      noShape
  end

  if icon == 'BDAY' then
    return base,
      'Rectangle 4,10,10,4,1 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Rectangle 6,7,6,3,1 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Rectangle 8,4,2,3,1 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Ellipse 7,2,4,3 | Fill Color 255,224,90,236 | StrokeWidth 0'
  end

  if icon == 'LADY' then
    return base,
      'Ellipse 7,7,4,4 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Ellipse 4,5,5,5 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Ellipse 9,5,5,5 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Ellipse 7,10,5,5 | Fill Color ' .. iconFg .. ' | StrokeWidth 0'
  end

  if icon == 'IRON' then
    return base,
      'Line 4,14,14,4 | StrokeWidth 2 | Stroke Color ' .. iconFg,
      'Line 4,4,14,14 | StrokeWidth 2 | Stroke Color ' .. iconFg,
      'Ellipse 3,13,3,3 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
      'Ellipse 12,13,3,3 | Fill Color ' .. iconFg .. ' | StrokeWidth 0'
  end

  return base,
    'Ellipse 7,7,4,4 | Fill Color ' .. iconFg .. ' | StrokeWidth 0',
    noShape,
    noShape,
    noShape
end

local function clear_separator(slot)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DividerText', '')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DividerY', '0')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DividerLine', hiddenColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DividerAccent', hiddenColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DividerFill', '0,0,0,0')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DividerTextColor', hiddenColor)
end

local function set_separator(slot, event, y)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DividerText', event.date)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DividerY', tostring(math.floor(y - 22 + 0.5)))
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DividerLine', skin_var('DividerLineColor', '255,255,255,34'))
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DividerAccent', color_alpha(event.color, 176))
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DividerFill', skin_var('DividerFillColor', '8,12,18,178'))
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DividerTextColor', skin_var('DividerTextColor', '202,211,224,218'))
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
      icon = vars['Event' .. i .. 'Icon'] or '',
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
    return tostring(hours) .. 'h', tostring(minutes) .. 'm'
  end
  return tostring(math.ceil(seconds / 86400)), 'day'
end

local function clear_row(slot)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Y', tostring(rowBaseY[slot] or 94))
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Time', '')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Title', '')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Icon', '')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'IconFill', hiddenColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'IconStroke', hiddenColor)
  for i = 1, 5 do
    SKIN:Bang('!SetVariable', 'Row' .. slot .. 'IconShape' .. i, noShape)
  end
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Location', '')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Color', hiddenColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'TextColor', '255,255,255,0')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'SubColor', '255,255,255,0')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DotSize', '5')
  clear_separator(slot)
end

local function row_time_label(event, headerDate)
  return event.time
end

local function set_row(slot, event, active, headerDate, y)
  local style = SKIN:GetVariable('TimelineStyle') or 'Glass'
  local textColor = active and skin_var('RowActiveTextColor', '255,226,84,255') or skin_var('RowNormalTextColor', '245,247,252,238')
  local subColor = active and skin_var('RowActiveSubColor', '230,214,156,238') or skin_var('RowNormalSubColor', '170,178,190,226')
  local color = active and skin_var('AccentColor', activeColor) or event.color
  local showCalendar = read_bool_variable('ShowCalendarName', true)
  local showLocation = read_bool_variable('ShowEventLocation', true)
  local showNotes = read_bool_variable('ShowEventNotes', true)
  local detailParts = {}
  if showCalendar and event.calendar ~= '' then table.insert(detailParts, event.calendar) end
  if showLocation and event.location ~= '' then table.insert(detailParts, event.location) end
  if showNotes and style == 'Dense' and event.notes ~= '' then table.insert(detailParts, event.notes) end
  local detail = table.concat(detailParts, '  |  ')
  if detail == '' and showLocation then
    detail = event.location
  end
  if style == 'Dense' then
    detail = showLocation and event.location or ''
    if showNotes and event.notes ~= '' and detail ~= '' then
      detail = detail .. '  |  ' .. event.notes
    elseif showNotes and event.notes ~= '' then
      detail = event.notes
    elseif detail == '' and showCalendar then
      detail = event.calendar
    end
  end
  if style == 'Focus' and not active then
    detail = ''
  end
  local shape1, shape2, shape3, shape4, shape5 = icon_shapes(event.icon, event.color)

  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Y', tostring(math.floor(y + 0.5)))
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Time', row_time_label(event, headerDate))
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Title', event.title)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Icon', '')
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'IconFill', event.icon ~= '' and event.color or hiddenColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'IconStroke', event.icon ~= '' and '255,255,255,48' or hiddenColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'IconShape1', shape1)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'IconShape2', shape2)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'IconShape3', shape3)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'IconShape4', shape4)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'IconShape5', shape5)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Location', detail)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'Color', color)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'TextColor', textColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'SubColor', subColor)
  SKIN:Bang('!SetVariable', 'Row' .. slot .. 'DotSize', active and '12' or '8')
end

local function apply_style()
  local style = SKIN:GetVariable('TimelineStyle') or 'Glass'
  local template = SKIN:GetVariable('LayoutTemplate') or 'Classic'

  local presets = {
    Classic = {
      title = '12', sub = '8', titleW = '306', detailW = '318', timelineX = '232', timeX = '210', iconX = '258', titleX = '286', baseY = {98, 146, 194, 242, 290, 338}, gap = 48,
      panelX = '92', panelY = '22', panelW = '526', panelH = '446', panelRadius = '14', headerX = '356', headerY = '42', calX = '586', calY = '42', sourceX = '356', sourceY = '430', sourceW = '410',
      lineY = '92', lineH = '344', scrollX = '92', scrollY = '72', scrollW = '526', scrollH = '376', countdownX = '2', countdownTextX = '36', connectorX = '92', connectorW = '132',
      divLeftX = '286', divLeftW = '32', divRightX = '398', divRightW = '154', divChipX = '321', divDotX = '230', divTextX = '356',
      panel = '12,16,22,150', edge = '255,255,255,62', line = '225,230,238,96', text = '245,247,252,238', subc = '170,178,190,226',
      activeText = '255,226,84,255', activeSub = '230,214,156,238', accent = '255,199,50,255', accentSoft = '255,199,50,112',
      dividerLine = '255,255,255,34', dividerFill = '8,12,18,178', dividerText = '202,211,224,218', tag = '12,16,22,206', tagSub = '224,214,162,238',
      sheen = '255,255,255,5', glow1 = '255,199,50,42', glow2 = '255,199,50,86'
    },
    Command = {
      title = '10', sub = '8', titleW = '286', detailW = '300', timelineX = '220', timeX = '198', iconX = '246', titleX = '276', baseY = {94, 138, 182, 226, 270, 314}, gap = 44,
      panelX = '116', panelY = '10', panelW = '500', panelH = '442', panelRadius = '4', headerX = '366', headerY = '28', calX = '584', calY = '28', sourceX = '366', sourceY = '430', sourceW = '400',
      lineY = '82', lineH = '336', scrollX = '116', scrollY = '64', scrollW = '500', scrollH = '376', countdownX = '18', countdownTextX = '52', connectorX = '104', connectorW = '116',
      divLeftX = '276', divLeftW = '32', divRightX = '402', divRightW = '154', divChipX = '316', divDotX = '218', divTextX = '356',
      panel = '3,8,7,222', edge = '85,255,170,108', line = '82,255,170,96', text = '224,255,238,244', subc = '140,207,180,232',
      activeText = '96,255,180,255', activeSub = '185,255,218,238', accent = '96,255,180,255', accentSoft = '96,255,180,100',
      dividerLine = '82,255,170,44', dividerFill = '3,24,18,220', dividerText = '178,255,216,230', tag = '3,16,13,238', tagSub = '164,246,204,238',
      sheen = '255,255,255,0', tagGlow = '96,255,180,34', glow1 = '96,255,180,34', glow2 = '96,255,180,76'
    },
    Ledger = {
      title = '11', sub = '8', titleW = '360', detailW = '374', timelineX = '220', timeX = '176', iconX = '252', titleX = '284', baseY = {106, 150, 194, 238, 282, 326}, gap = 44,
      panelX = '62', panelY = '38', panelW = '632', panelH = '414', panelRadius = '2', headerX = '378', headerY = '58', calX = '662', calY = '58', sourceX = '378', sourceY = '430', sourceW = '520',
      lineY = '92', lineH = '320', scrollX = '62', scrollY = '82', scrollW = '632', scrollH = '350', countdownX = '708', countdownTextX = '742', connectorX = '694', connectorW = '14',
      divLeftX = '284', divLeftW = '58', divRightX = '444', divRightW = '204', divChipX = '354', divDotX = '218', divTextX = '392',
      panel = '16,15,13,220', edge = '238,215,170,86', line = '238,215,170,72', text = '249,241,226,244', subc = '199,184,158,232',
      activeText = '255,205,92,255', activeSub = '238,216,174,238', accent = '255,205,92,255', accentSoft = '255,205,92,100',
      dividerLine = '238,215,170,34', dividerFill = '26,23,18,224', dividerText = '229,211,181,230', tag = '20,17,12,238', tagSub = '238,216,174,238',
      sheen = '255,255,255,4', tagGlow = '255,205,92,36', glow1 = '255,205,92,36', glow2 = '255,205,92,78'
    },
    Metro = {
      title = '11', sub = '8', titleW = '354', detailW = '368', timelineX = '250', timeX = '228', iconX = '278', titleX = '310', baseY = {96, 140, 184, 228, 272, 316}, gap = 44,
      panelX = '126', panelY = '50', panelW = '670', panelH = '388', panelRadius = '22', headerX = '462', headerY = '70', calX = '762', calY = '70', sourceX = '462', sourceY = '414', sourceW = '540',
      lineY = '88', lineH = '306', scrollX = '126', scrollY = '78', scrollW = '670', scrollH = '342', countdownX = '18', countdownTextX = '52', connectorX = '104', connectorW = '146',
      divLeftX = '310', divLeftW = '44', divRightX = '448', divRightW = '258', divChipX = '364', divDotX = '248', divTextX = '400',
      panel = '8,13,24,214', edge = '86,160,255,104', line = '105,180,255,86', text = '236,244,255,246', subc = '154,180,216,232',
      activeText = '130,204,255,255', activeSub = '196,226,255,238', accent = '104,170,255,255', accentSoft = '104,170,255,104',
      dividerLine = '105,180,255,38', dividerFill = '8,20,38,224', dividerText = '198,225,255,230', tag = '6,15,30,238', tagSub = '188,218,255,238',
      sheen = '255,255,255,6', tagGlow = '104,170,255,34', glow1 = '104,170,255,34', glow2 = '104,170,255,82'
    },
    Studio = {
      title = '12', sub = '8', titleW = '300', detailW = '314', timelineX = '374', timeX = '352', iconX = '400', titleX = '430', baseY = {92, 132, 174, 216, 258, 300}, gap = 42,
      panelX = '250', panelY = '24', panelW = '528', panelH = '420', panelRadius = '18', headerX = '514', headerY = '44', calX = '744', calY = '44', sourceX = '514', sourceY = '412', sourceW = '418',
      lineY = '82', lineH = '320', scrollX = '250', scrollY = '76', scrollW = '528', scrollH = '342', countdownX = '136', countdownTextX = '170', connectorX = '222', connectorW = '152',
      divLeftX = '430', divLeftW = '38', divRightX = '552', divRightW = '158', divChipX = '474', divDotX = '372', divTextX = '509',
      panel = '14,10,16,222', edge = '238,120,150,96', line = '238,120,150,72', text = '252,239,246,246', subc = '205,169,187,232',
      activeText = '255,159,194,255', activeSub = '242,203,219,238', accent = '238,120,150,255', accentSoft = '238,120,150,104',
      dividerLine = '238,120,150,38', dividerFill = '28,14,24,224', dividerText = '242,203,219,230', tag = '24,12,21,238', tagSub = '242,203,219,238',
      sheen = '255,255,255,5', tagGlow = '238,120,150,34', glow1 = '238,120,150,34', glow2 = '238,120,150,82'
    },
    Daylight = {
      title = '12', sub = '8', titleW = '350', detailW = '364', timelineX = '246', timeX = '224', iconX = '274', titleX = '304', baseY = {102, 146, 190, 234, 278, 322}, gap = 44,
      panelX = '104', panelY = '18', panelW = '622', panelH = '432', panelRadius = '10', headerX = '416', headerY = '40', calX = '694', calY = '40', sourceX = '416', sourceY = '432', sourceW = '500',
      lineY = '92', lineH = '326', scrollX = '104', scrollY = '74', scrollW = '622', scrollH = '360', countdownX = '6', countdownTextX = '40', connectorX = '92', connectorW = '154',
      divLeftX = '304', divLeftW = '46', divRightX = '448', divRightW = '216', divChipX = '360', divDotX = '244', divTextX = '400',
      panel = '250,252,255,238', edge = '32,40,55,68', line = '54,68,90,74', text = '22,27,36,246', subc = '84,95,112,234',
      activeText = '178,114,0,255', activeSub = '98,78,40,238', accent = '223,150,28,255', accentSoft = '223,150,28,104',
      dividerLine = '54,68,90,30', dividerFill = '255,255,255,232', dividerText = '58,68,84,232', tag = '255,255,255,246', tagSub = '98,78,40,238',
      sheen = '255,255,255,0', tagGlow = '223,150,28,34', glow1 = '223,150,28,34', glow2 = '223,150,28,78'
    }
  }

  local preset = presets[template] or presets.Classic
  local classic = presets.Classic
  local sharedGeometry = {
    'titleW', 'detailW', 'timelineX', 'timeX', 'iconX', 'titleX', 'baseY', 'gap',
    'panelX', 'panelY', 'panelW', 'panelH', 'panelRadius',
    'headerX', 'headerY', 'calX', 'calY', 'sourceX', 'sourceY', 'sourceW',
    'lineY', 'lineH', 'scrollX', 'scrollY', 'scrollW', 'scrollH',
    'countdownX', 'countdownTextX', 'connectorX', 'connectorW',
    'divLeftX', 'divLeftW', 'divRightX', 'divRightW', 'divChipX', 'divDotX', 'divTextX'
  }
  if preset ~= classic then
    for _, key in ipairs(sharedGeometry) do
      preset[key] = classic[key]
    end
  end

  rowBaseY = preset.baseY
  rowGap = preset.gap
  if style == 'Dense' then
    preset.title = '10'
    preset.sub = '8'
  elseif style == 'Focus' then
    preset.sub = '8'
  end

  SKIN:Bang('!SetVariable', 'RowTitleSize', preset.title)
  SKIN:Bang('!SetVariable', 'RowSubSize', preset.sub)
  SKIN:Bang('!SetVariable', 'RowTitleW', preset.titleW)
  SKIN:Bang('!SetVariable', 'RowDetailW', preset.detailW)
  SKIN:Bang('!SetVariable', 'TimelineX', preset.timelineX)
  SKIN:Bang('!SetVariable', 'TimeX', preset.timeX)
  SKIN:Bang('!SetVariable', 'IconX', preset.iconX)
  SKIN:Bang('!SetVariable', 'TitleX', preset.titleX)
  SKIN:Bang('!SetVariable', 'PanelX', preset.panelX)
  SKIN:Bang('!SetVariable', 'PanelY', preset.panelY)
  SKIN:Bang('!SetVariable', 'PanelW', preset.panelW)
  SKIN:Bang('!SetVariable', 'PanelH', preset.panelH)
  SKIN:Bang('!SetVariable', 'PanelRadius', preset.panelRadius)
  SKIN:Bang('!SetVariable', 'HeaderX', preset.headerX)
  SKIN:Bang('!SetVariable', 'HeaderY', preset.headerY)
  SKIN:Bang('!SetVariable', 'CalendarX', preset.calX)
  SKIN:Bang('!SetVariable', 'CalendarY', preset.calY)
  SKIN:Bang('!SetVariable', 'SourceX', preset.sourceX)
  SKIN:Bang('!SetVariable', 'SourceY', preset.sourceY)
  SKIN:Bang('!SetVariable', 'SourceW', preset.sourceW)
  SKIN:Bang('!SetVariable', 'TimelineLineY', preset.lineY)
  SKIN:Bang('!SetVariable', 'TimelineLineH', preset.lineH)
  SKIN:Bang('!SetVariable', 'ScrollX', preset.scrollX)
  SKIN:Bang('!SetVariable', 'ScrollY', preset.scrollY)
  SKIN:Bang('!SetVariable', 'ScrollW', preset.scrollW)
  SKIN:Bang('!SetVariable', 'ScrollH', preset.scrollH)
  SKIN:Bang('!SetVariable', 'CountdownX', preset.countdownX)
  SKIN:Bang('!SetVariable', 'CountdownTextX', preset.countdownTextX)
  SKIN:Bang('!SetVariable', 'ConnectorX', preset.connectorX)
  SKIN:Bang('!SetVariable', 'ConnectorW', preset.connectorW)
  SKIN:Bang('!SetVariable', 'DividerLeftX', preset.divLeftX)
  SKIN:Bang('!SetVariable', 'DividerLeftW', preset.divLeftW)
  SKIN:Bang('!SetVariable', 'DividerRightX', preset.divRightX)
  SKIN:Bang('!SetVariable', 'DividerRightW', preset.divRightW)
  SKIN:Bang('!SetVariable', 'DividerChipX', preset.divChipX)
  SKIN:Bang('!SetVariable', 'DividerDotX', preset.divDotX)
  SKIN:Bang('!SetVariable', 'DividerTextX', preset.divTextX)
  SKIN:Bang('!SetVariable', 'PanelFill', preset.panel)
  SKIN:Bang('!SetVariable', 'PanelEdge', preset.edge)
  SKIN:Bang('!SetVariable', 'LineColor', preset.line)
  SKIN:Bang('!SetVariable', 'TextColor', preset.text)
  SKIN:Bang('!SetVariable', 'SoftText', preset.text)
  SKIN:Bang('!SetVariable', 'MutedText', preset.subc)
  SKIN:Bang('!SetVariable', 'AccentColor', preset.accent)
  SKIN:Bang('!SetVariable', 'AccentSoft', preset.accentSoft)
  SKIN:Bang('!SetVariable', 'RowNormalTextColor', preset.text)
  SKIN:Bang('!SetVariable', 'RowNormalSubColor', preset.subc)
  SKIN:Bang('!SetVariable', 'RowActiveTextColor', preset.activeText)
  SKIN:Bang('!SetVariable', 'RowActiveSubColor', preset.activeSub)
  SKIN:Bang('!SetVariable', 'DividerLineColor', preset.dividerLine)
  SKIN:Bang('!SetVariable', 'DividerFillColor', preset.dividerFill)
  SKIN:Bang('!SetVariable', 'DividerTextColor', preset.dividerText)
  SKIN:Bang('!SetVariable', 'CountdownTagFill', preset.tag)
  SKIN:Bang('!SetVariable', 'CountdownUnitColor', preset.tagSub)
  SKIN:Bang('!SetVariable', 'CountdownGlow', preset.tagGlow or preset.glow1)
  SKIN:Bang('!SetVariable', 'PanelSheen', preset.sheen)
  SKIN:Bang('!SetVariable', 'ActiveGlow1', preset.glow1)
  SKIN:Bang('!SetVariable', 'ActiveGlow2', preset.glow2)
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
  Update(true)
end

function Scroll(direction)
  local maxRows = read_number_variable('MaxRows', 6, 1, 6)
  local step = read_number_variable('ScrollStep', 1, 1, 6)
  local amount = tonumber(direction or '0') or 0
  if amount == 0 then return '' end

  scrollTarget = clamp(scrollTarget + (amount * step), 0, max_scroll(maxRows))
  scrollCurrent = scrollTarget
  userScrolled = true
  homeAnimating = false
  Update(true)
  return ''
end

function CenterNow()
  local maxRows = read_number_variable('MaxRows', 6, 1, 6)
  local selected = find_selected(os.time())
  if selected == 0 then return '' end

  scrollTarget = clamp(selected - 2, 0, max_scroll(maxRows))
  userScrolled = true
  homeAnimating = true
  Update(true)
  return ''
end

function Update(force)
  local now = os.time()
  if not force and not homeAnimating and now == lastRenderSecond then
    return ''
  end
  lastRenderSecond = now

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
    if homeAnimating then
      scrollTarget = anchor
    elseif not userScrolled then
      scrollTarget = anchor
      scrollCurrent = anchor
    end

    scrollTarget = clamp(scrollTarget, 0, max_scroll(maxRows))
    scrollCurrent = clamp(scrollCurrent, 0, max_scroll(maxRows))

    if homeAnimating then
      local delta = scrollTarget - scrollCurrent
      if math.abs(delta) < 0.05 then
        scrollCurrent = scrollTarget
        homeAnimating = false
        userScrolled = false
      else
        scrollCurrent = scrollCurrent + (delta * 0.22)
      end
    end

    local startIndex = math.floor(scrollCurrent) + 1
    local fractional = scrollCurrent - math.floor(scrollCurrent)
    local activeSlot = selected - startIndex + 1
    local selectedVisible = activeSlot >= 1 and activeSlot <= maxRows
    local rowY = {}
    local showSeparator = {}
    local separatorCount = 0

    for slot = 1, maxRows do
      local event = events[startIndex + slot - 1]
      local previousEvent = events[startIndex + slot - 2]
      showSeparator[slot] = event and previousEvent and event.date ~= '' and previousEvent.date ~= event.date
      if showSeparator[slot] then
        separatorCount = separatorCount + 1
      end
      rowY[slot] = rowBaseY[slot] - (fractional * rowGap) + (separatorCount * daySeparatorGap)
    end

    local activeY = selectedVisible and rowY[activeSlot] or rowBaseY[1] + ((selected - 1 - scrollCurrent) * rowGap)
    local pointerY = clamp(activeY, rowBaseY[1], rowBaseY[maxRows] + (daySeparatorGap * 3))

    local headerDate = events[startIndex].date
    SKIN:Bang('!SetVariable', 'HeaderDate', headerDate)
    SKIN:Bang('!SetVariable', 'CountdownY', tostring(math.floor(pointerY - 20 + 0.5)))
    SKIN:Bang('!SetVariable', 'ActiveRuleY', tostring(math.floor(pointerY + 8 + 0.5)))

    for slot = 1, 6 do
      local event = events[startIndex + slot - 1]
      if event and slot <= maxRows then
        if showSeparator[slot] then
          set_separator(slot, event, rowY[slot])
        else
          clear_separator(slot)
        end
        set_row(slot, event, selectedVisible and startIndex + slot - 1 == selected, headerDate, rowY[slot])
      else
        clear_row(slot)
      end
    end
  end

  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
  return ''
end

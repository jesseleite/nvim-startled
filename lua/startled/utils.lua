local M = {}

-- Get random value from table
M.random = function (values)
  math.randomseed(os.time())
  return values[math.random(#values)]
end

-- Function to handle both highlight links and hex colors
M.set_highlight = function (group, value)
  if type(value) == "string" then
    if value:match("^#%x%x%x%x%x%x$") or value:match("^#%x%x%x$") then
      -- It's a hex color (6 or 3 digit)
      vim.api.nvim_set_hl(0, group, { fg = value })
    else
      -- It's a highlight group link
      vim.api.nvim_set_hl(0, group, { link = value })
    end
  elseif type(value) == "table" then
    -- Direct table with fg/bg/etc
    vim.api.nvim_set_hl(0, group, value)
  end
end

-- Strip all Startled tags for width calculations
M.strip_startled_tags = function (text)
  return text:gsub('</?Startled[%w_]*>', '')
end

-- Wrap text to specified width without breaking words, respecting NoWrap tags
M.wrap_text = function (text, width)
  if not width or width <= 0 then
    return {text}
  end
  
  local lines = {}
  local current_line = ""
  
  -- Split text by spaces while preserving NoWrap tagged sections
  local parts = {}
  local pos = 1
  
  while pos <= #text do
    -- Look for NoWrap opening tag
    local nowrap_start, nowrap_end = string.find(text, '<StartledNoWrap>', pos)
    
    if nowrap_start then
      -- Add text before NoWrap tag as individual words
      if nowrap_start > pos then
        local before_nowrap = string.sub(text, pos, nowrap_start - 1)
        for word in before_nowrap:gmatch("%S+") do
          table.insert(parts, {text = word, nowrap = false})
        end
      end
      
      -- Find closing NoWrap tag
      local close_start, close_end = string.find(text, '</StartledNoWrap>', nowrap_end + 1)
      
      if close_start then
        -- Extract NoWrap content (including tags for later processing)
        local nowrap_content = string.sub(text, nowrap_start, close_end)
        table.insert(parts, {text = nowrap_content, nowrap = true})
        pos = close_end + 1
      else
        -- No closing tag, treat as regular text
        local remaining = string.sub(text, nowrap_start)
        for word in remaining:gmatch("%S+") do
          table.insert(parts, {text = word, nowrap = false})
        end
        break
      end
    else
      -- No more NoWrap tags, process remaining text as words
      local remaining = string.sub(text, pos)
      for word in remaining:gmatch("%S+") do
        table.insert(parts, {text = word, nowrap = false})
      end
      break
    end
  end
  
  -- Now wrap the parts, treating NoWrap sections as single units
  for _, part in ipairs(parts) do
    local part_text = part.text
    local clean_part_text = M.strip_startled_tags(part_text)
    local test_line = current_line == "" and part_text or current_line .. " " .. part_text
    local clean_test_line = M.strip_startled_tags(test_line)
    
    if vim.fn.strdisplaywidth(clean_test_line) <= width then
      current_line = test_line
    else
      if current_line ~= "" then
        table.insert(lines, current_line)
        current_line = part_text
      else
        -- Even a single NoWrap section might be too long, but we don't break it
        table.insert(lines, part_text)
        current_line = ""
      end
    end
  end
  
  if current_line ~= "" then
    table.insert(lines, current_line)
  end
  
  return lines
end

return M

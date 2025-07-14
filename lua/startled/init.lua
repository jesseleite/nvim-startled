local utils = require('startled.utils')

local M = {}

local config = {
  highlights = {
    StartledPrimary = 'String',
    StartledSecondary = 'Type',
    StartledMuted = 'Comment',
  },
  content = require('startled.content.default'),
}

M.setup = function(opts)
  config = vim.tbl_deep_extend('force', config, opts or {})

  -- Don't show default start message when starting Neovim
  vim.opt.shortmess:append('I')

  local popup_shown = false
  local popup_win = nil
  local popup_buf = nil
  local popup_content = {}

  local function destroy_popup()
    if popup_win and vim.api.nvim_win_is_valid(popup_win) then
      vim.api.nvim_win_close(popup_win, true)
    end
    if popup_buf and vim.api.nvim_buf_is_valid(popup_buf) then
      vim.api.nvim_buf_delete(popup_buf, { force = true })
    end
    popup_win = nil
    popup_buf = nil
  end

  local function show_startup_popup()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local not_unnamed_empty_buffer = #lines > 1 or (#lines == 1 and lines[1] ~= '') or vim.bo.filetype ~= ''
    local popup_already_exists = popup_win and vim.api.nvim_win_is_valid(popup_win)

    if not_unnamed_empty_buffer or popup_already_exists or popup_shown then
      return
    end

    popup_shown = true

    -- Pre-evaluate all function-based content to ensure consistency
    local evaluated_content = {}
    for i = 1, #config.content do
      local item = config.content[i]
      if type(item) == 'table' then
        local evaluated_item = vim.deepcopy(item)
        if item.text and type(item.text) == 'function' then
          evaluated_item.text = item.text()
        end
        evaluated_content[i] = evaluated_item
      else
        -- Handle single string text
        local text = item.text

        if item.wrap then
          local wrapped_lines = utils.wrap_text(text, item.wrap)
          for _, wrapped_line in ipairs(wrapped_lines) do
            local final_text = wrapped_line
            if item.center ~= false then
              final_text = center_text(wrapped_line, max_width)
            end
            table.insert(popup_content, {
              text = final_text,
              hl = item.hl
            })
          end
        else
          if item.center ~= false then
            text = center_text(text, max_width)
          end
          table.insert(popup_content, {
            text = text,
            hl = item.hl
          })
        end
      end
    end

    -- Calculate max_width needed for popup
    local max_width = 0
    for i = 1, #evaluated_content do
      local item = evaluated_content[i]
      if type(item) == 'table' and item.type ~= 'spacer' then
        if item.text then
          if type(item.text) == 'table' then
            -- Handle table of lines
            for _, line in ipairs(item.text) do
              local line_text = type(line) == 'function' and line() or line
              max_width = math.max(max_width, vim.fn.strdisplaywidth(line_text))
            end
          else
            -- Handle single string
            local clean_text = utils.strip_startled_tags(item.text)
            if item.wrap then
              local wrapped_lines = utils.wrap_text(item.text, item.wrap)
              for _, wrapped_line in ipairs(wrapped_lines) do
                local clean_wrapped_line = utils.strip_startled_tags(wrapped_line)
                max_width = math.max(max_width, vim.fn.strdisplaywidth(clean_wrapped_line))
              end
            else
              max_width = math.max(max_width, vim.fn.strdisplaywidth(clean_text))
            end
          end
        end
      end
    end

    -- Center text, stripping tags for width calculation but preserving them in output
    local function center_text(text, width)
      local clean_text = utils.strip_startled_tags(text)
      local padding = math.floor((width - vim.fn.strdisplaywidth(clean_text)) / 2)
      return string.rep(' ', padding) .. text
    end

    -- Center a block of text lines as a whole unit
    local function center_text_block(text_lines, width)
      -- Find the maximum width of all lines in the block
      local max_line_width = 0
      local clean_lines = {}

      for _, line in ipairs(text_lines) do
        local text = type(line) == 'function' and line() or line
        local clean_text = utils.strip_startled_tags(text)
        table.insert(clean_lines, {original = text, clean = clean_text})
        max_line_width = math.max(max_line_width, vim.fn.strdisplaywidth(clean_text))
      end

      -- Calculate padding to center the entire block
      local block_padding = math.floor((width - max_line_width) / 2)

      -- Apply the same padding to all lines
      local centered_lines = {}
      for _, line_data in ipairs(clean_lines) do
        table.insert(centered_lines, string.rep(' ', block_padding) .. line_data.original)
      end

      return centered_lines
    end

    -- Build the final content with tagged text for easy color control
    for i = 1, #evaluated_content do
      local item = evaluated_content[i]
      if item.type == 'spacer' then
        table.insert(popup_content, '')
      elseif item.text and type(item.text) == 'table' then
        -- Handle table of lines
        if item.center == 'block' then
          -- Center the entire block of lines as a unit
          local centered_lines = center_text_block(item.text, max_width)
          for _, text in ipairs(centered_lines) do
            table.insert(popup_content, {
              text = text,
              hl = item.hl
            })
          end
        else
          -- Center each line individually (existing behavior)
          for _, line in ipairs(item.text) do
            local text = type(line) == 'function' and line() or line
            if item.center ~= false then
              text = center_text(text, max_width)
            end
            table.insert(popup_content, {
              text = text,
              hl = item.hl
            })
          end
        end
      elseif item.text then
        local text = item.text

        if item.wrap then
          local wrapped_lines = utils.wrap_text(text, item.wrap)
          for _, wrapped_line in ipairs(wrapped_lines) do
            local final_text = wrapped_line
            if item.center ~= false then
              final_text = center_text(wrapped_line, max_width)
            end
            table.insert(popup_content, {
              text = final_text,
              hl = item.hl
            })
          end
        else
          if item.center ~= false then
            text = center_text(text, max_width)
          end
          table.insert(popup_content, {
            text = text,
            hl = item.hl
          })
        end
      end
    end

    -- Function to parse HTML-like tags and extract clean text with highlight positions
    local function parse_tagged_text(tagged_text)
      if type(tagged_text) ~= 'string' then
        return tagged_text, {}
      end

      local clean_text = ""
      local highlights = {}
      local pos = 1
      local clean_pos = 0

      while pos <= #tagged_text do
        -- Look for opening tag (only Startled tags)
        local tag_start, tag_end, tag_name = string.find(tagged_text, '<(Startled[%w_]*)>', pos)

        if tag_start then
          -- Add text before the tag
          if tag_start > pos then
            local before_tag = string.sub(tagged_text, pos, tag_start - 1)
            clean_text = clean_text .. before_tag
            clean_pos = clean_pos + #before_tag
          end

          -- Look for closing tag
          local close_tag_start, close_tag_end = string.find(tagged_text, '</' .. tag_name .. '>', tag_end + 1)

          if close_tag_start then
            -- Extract the content between tags
            local content = string.sub(tagged_text, tag_end + 1, close_tag_start - 1)
            local content_start = clean_pos
            clean_text = clean_text .. content
            clean_pos = clean_pos + #content

            -- Store highlight info (but not for NoWrap tags, which are only for layout)
            if tag_name ~= 'StartledNoWrap' then
              table.insert(highlights, {
                hl = tag_name,
                start_col = content_start,
                end_col = clean_pos
              })
            end

            pos = close_tag_end + 1
          else
            -- No closing tag found, treat as regular text
            local char = string.sub(tagged_text, tag_start, tag_start)
            clean_text = clean_text .. char
            clean_pos = clean_pos + 1
            pos = tag_start + 1
          end
        else
          -- No more tags, add remaining text
          local remaining = string.sub(tagged_text, pos)
          clean_text = clean_text .. remaining
          break
        end
      end

      return clean_text, highlights
    end

    -- Extract text lines from content structure and parse tags
    local text_lines = {}
    local parsed_content = {}

    for _, item in ipairs(popup_content) do
      if type(item) == 'string' then
        table.insert(text_lines, item)
        table.insert(parsed_content, {clean_text = item, highlights = {}})
      else
        local clean_text, highlights = parse_tagged_text(item.text or '')
        table.insert(text_lines, clean_text)
        table.insert(parsed_content, {
          clean_text = clean_text,
          highlights = highlights,
          base_hl = item.hl
        })
      end
    end

    -- Create popup buffer
    popup_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, text_lines)

    -- Set buffer options
    vim.api.nvim_set_option_value('modifiable', false, { buf = popup_buf })
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = popup_buf })

    -- Calculate popup position (centered on screen)
    local ui = vim.api.nvim_list_uis()[1]
    if not ui then
      return
    end

    local win_width = ui.width
    local win_height = ui.height

    local popup_height = #text_lines
    local popup_width = max_width

    local row = math.floor((win_height - popup_height) / 2)
    local col = math.floor((win_width - popup_width) / 2)

    -- Create popup window
    popup_win = vim.api.nvim_open_win(popup_buf, false, {
      relative = 'editor',
      width = popup_width,
      height = popup_height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'none',
      focusable = false,
    })

    -- Set window options
    vim.api.nvim_set_option_value('winblend', 0, { win = popup_win })
    vim.api.nvim_set_option_value('winhighlight', 'Normal:Normal', { win = popup_win })

    -- Set up highlighting with exact same colors from your alpha config
    local ns_id = vim.api.nvim_create_namespace('startup_popup')

    -- Set up highlight groups
    for group, value in pairs(config.highlights) do
      utils.set_highlight(group, value)
    end

    -- Apply highlights using parsed tag information
    for i, parsed in ipairs(parsed_content) do
      local line_num = i - 1 -- Convert to 0-based indexing

      -- Apply base highlight for the entire line if specified
      if parsed.base_hl then
        vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_num, 0, {
          end_line = line_num,
          end_col = #parsed.clean_text,
          hl_group = parsed.base_hl
        })
      end

      -- Apply tag-based highlights
      for _, highlight in ipairs(parsed.highlights) do
        vim.api.nvim_buf_set_extmark(popup_buf, ns_id, line_num, highlight.start_col, {
          end_col = highlight.end_col,
          hl_group = highlight.hl
        })
      end
    end
  end

  -- Show popup on VimEnter and when entering empty buffers
  vim.api.nvim_create_autocmd({'VimEnter', 'BufEnter'}, {
    callback = function()
      vim.schedule(show_startup_popup)
    end,
  })

  -- Close popup on any key press or mode change
  vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI', 'InsertEnter', 'CmdlineEnter', 'CursorMoved'}, {
    callback = destroy_popup,
  })

  -- Close popup on any key press in normal mode
  vim.api.nvim_create_autocmd('ModeChanged', {
    callback = destroy_popup,
  })

  -- Re-center popup on window resize
  local function recenter_popup()
    if popup_win and vim.api.nvim_win_is_valid(popup_win) then
      local ui = vim.api.nvim_list_uis()[1]
      local win_width = ui.width
      local win_height = ui.height

      local config = vim.api.nvim_win_get_config(popup_win)
      local popup_height = config.height
      local popup_width = config.width

      local row = math.floor((win_height - popup_height) / 2)
      local col = math.floor((win_width - popup_width) / 2)

      vim.api.nvim_win_set_config(popup_win, {
        relative = 'editor',
        width = popup_width,
        height = popup_height,
        row = row,
        col = col,
      })
    end
  end

  -- Re-center on window resize
  vim.api.nvim_create_autocmd('VimResized', {
    callback = recenter_popup,
  })

  -- Also close on window events
  vim.api.nvim_create_autocmd({'WinEnter', 'WinLeave', 'BufLeave'}, {
    callback = destroy_popup,
  })
end

return M

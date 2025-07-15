return {
  {
    text = function ()
      local v = vim.version()
      local version_text = v.major .. '.' .. v.minor .. '.' .. v.patch
      return 'NVIM v' .. version_text
    end,
    hl = 'StartledSecondary',
  },
  {
    type = 'spacer',
  },
  {
    text = [[
███▄    █ ▓█████  ▒█████   ██▒   █▓ ██▓ ███▄ ▄███▓    ▄▄▄▄   ▄▄▄█████▓ █     █░
 ██ ▀█   █ ▓█   ▀ ▒██▒  ██▒▓██░   █▒▓██▒▓██▒▀█▀ ██▒   ▓█████▄ ▓  ██▒ ▓▒▓█░ █ ░█░
▓██  ▀█ ██▒▒███   ▒██░  ██▒ ▓██  █▒░▒██▒▓██    ▓██░   ▒██▒ ▄██▒ ▓██░ ▒░▒█░ █ ░█
▓██▒  ▐▌██▒▒▓█  ▄ ▒██   ██░  ▒██ █░░░██░▒██    ▒██    ▒██░█▀  ░ ▓██▓ ░ ░█░ █ ░█
▒██░   ▓██░░▒████▒░ ████▓▒░   ▒▀█░  ░██░▒██▒   ░██▒   ░▓█  ▀█▓  ▒██▒ ░ ░░██▒██▓
░ ▒░   ▒ ▒ ░░ ▒░ ░░ ▒░▒░▒░    ░ ▐░  ░▓  ░ ▒░   ░  ░   ░▒▓███▀▒  ▒ ░░   ░ ▓░▒ ▒
░ ░░   ░ ▒░ ░ ░  ░  ░ ▒ ▒░    ░ ░░   ▒ ░░  ░      ░   ▒░▒   ░     ░      ▒ ░ ░
   ░   ░ ░    ░   ░ ░ ░ ▒       ░░   ▒ ░░      ░       ░    ░   ░        ░   ░
         ░    ░  ░    ░ ░        ░   ░         ░       ░                   ░
                                ░                           ░
]],
    hl = 'StartledPrimary',
  },
  {
    type = 'spacer',
  },
  {
    text = {
      'type <StartledSecondary>:help</StartledSecondary><StartledMuted><Enter></StartledMuted> for help',
      'type <StartledSecondary>:q</StartledSecondary><StartledMuted><Enter></StartledMuted> to exit',
    },
  },
  {
    type = 'spacer',
  },
  {
    text = function ()
      local quotes = require('startled.content.quotes')
      return require('startled.utils').random(quotes)
    end,
    wrap = 60,
    hl = 'StartledMuted',
  },
}

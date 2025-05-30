local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local curwin = n.api.nvim_get_current_win
local eq = t.eq
local exec_lua = n.exec_lua
local feed = n.feed
local fn = n.fn
local api = n.api
local is_os = t.is_os

describe('title', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
  end)

  it('has correct default title with unnamed file', function()
    local expected = '[No Name] - Nvim'
    command('set title')
    screen:expect(function()
      eq(expected, screen.title)
    end)
  end)

  it('has correct default title with named file', function()
    local expected = (is_os('win') and 'myfile (C:\\mydir) - Nvim' or 'myfile (/mydir) - Nvim')
    command('set title')
    command(is_os('win') and 'file C:\\mydir\\myfile' or 'file /mydir/myfile')
    screen:expect(function()
      eq(expected, screen.title)
    end)
  end)

  it('is updated in Insert mode', function()
    api.nvim_set_option_value('title', true, {})
    screen:expect(function()
      eq('[No Name] - Nvim', screen.title)
    end)
    feed('ifoo')
    screen:expect(function()
      eq('[No Name] + - Nvim', screen.title)
    end)
    feed('<Esc>')
    api.nvim_set_option_value('titlestring', '%m %f (%{mode(1)}) | nvim', {})
    screen:expect(function()
      eq('[+] [No Name] (n) | nvim', screen.title)
    end)
    feed('i')
    screen:expect(function()
      eq('[+] [No Name] (i) | nvim', screen.title)
    end)
    feed('<Esc>')
    screen:expect(function()
      eq('[+] [No Name] (n) | nvim', screen.title)
    end)
  end)

  it('is updated in Cmdline mode', function()
    api.nvim_set_option_value('title', true, {})
    api.nvim_set_option_value('titlestring', '%f (%{mode(1)}) | nvim', {})
    screen:expect(function()
      eq('[No Name] (n) | nvim', screen.title)
    end)
    feed(':')
    screen:expect(function()
      eq('[No Name] (c) | nvim', screen.title)
    end)
    feed('<Esc>')
    screen:expect(function()
      eq('[No Name] (n) | nvim', screen.title)
    end)
  end)

  it('is updated in Terminal mode', function()
    api.nvim_set_option_value('title', true, {})
    api.nvim_set_option_value('titlestring', '(%{mode(1)}) | nvim', {})
    fn.jobstart({ n.testprg('shell-test'), 'INTERACT' }, { term = true })
    screen:expect(function()
      eq('(nt) | nvim', screen.title)
    end)
    feed('i')
    screen:expect(function()
      eq('(t) | nvim', screen.title)
    end)
    feed([[<C-\><C-N>]])
    screen:expect(function()
      eq('(nt) | nvim', screen.title)
    end)
  end)

  describe('is not changed by', function()
    local file1 = is_os('win') and 'C:\\mydir\\myfile1' or '/mydir/myfile1'
    local file2 = is_os('win') and 'C:\\mydir\\myfile2' or '/mydir/myfile2'
    local expected = (is_os('win') and 'myfile1 (C:\\mydir) - Nvim' or 'myfile1 (/mydir) - Nvim')
    local buf2

    before_each(function()
      command('edit ' .. file1)
      buf2 = fn.bufadd(file2)
      command('set title')
    end)

    it('calling setbufvar() to set an option in a hidden buffer from i_CTRL-R', function()
      command([[inoremap <F2> <C-R>=setbufvar(]] .. buf2 .. [[, '&autoindent', 1) ?? ''<CR>]])
      feed('i<F2><Esc>')
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('an RPC call to nvim_set_option_value in a hidden buffer', function()
      api.nvim_set_option_value('autoindent', true, { buf = buf2 })
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('a Lua callback calling nvim_set_option_value in a hidden buffer', function()
      exec_lua(string.format(
        [[
        vim.schedule(function()
          vim.api.nvim_set_option_value('autoindent', true, { buf = %d })
        end)
      ]],
        buf2
      ))
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('a Lua callback calling vim._with in a hidden buffer', function()
      exec_lua(string.format(
        [[
        vim.schedule(function()
          vim._with({buf = %d}, function() end)
        end)
      ]],
        buf2
      ))
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('setting the buffer of another window using RPC', function()
      local oldwin = curwin()
      command('split')
      api.nvim_win_set_buf(oldwin, buf2)
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('setting the buffer of another window using Lua callback', function()
      local oldwin = curwin()
      command('split')
      exec_lua(string.format(
        [[
        vim.schedule(function()
          vim.api.nvim_win_set_buf(%d, %d)
        end)
      ]],
        oldwin,
        buf2
      ))
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('creating a floating window using RPC', function()
      api.nvim_open_win(buf2, false, {
        relative = 'editor',
        width = 5,
        height = 5,
        row = 0,
        col = 0,
      })
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('creating a floating window using Lua callback', function()
      exec_lua(string.format(
        [[
        vim.api.nvim_open_win(%d, false, {
          relative = 'editor', width = 5, height = 5, row = 0, col = 0,
        })
      ]],
        buf2
      ))
      command('redraw!')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)
  end)
end)

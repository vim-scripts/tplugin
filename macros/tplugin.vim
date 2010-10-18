" plugin.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2010-01-04.
" @Last Change: 2010-01-19.
" @Revision:    496

if &cp || exists("loaded_tplugin")
    finish
endif
let loaded_tplugin = 3

let s:save_cpo = &cpo
set cpo&vim


if !exists('g:tplugin_autoload')
    " Enable autoloading. See |:TPluginScan|, |:TPluginCommand|, and 
    " |:TPluginFunction|.
    let g:tplugin_autoload = 1   "{{{2
endif


function! s:Join(filename_parts) "{{{3
    let parts = map(copy(a:filename_parts), 'substitute(v:val, ''[\/]\+$'', "", "")')
    return join(parts, '/')
endf


let s:roots = []
let s:rtp = split(&rtp, ',')
let s:reg = {}
let s:done = {}
let s:immediate = 0
let s:before = {}
let s:after = {}


augroup TPlugin
    autocmd!
    autocmd VimEnter * call s:Process()
augroup END


" :nodoc:
function! TPluginGetRoot() "{{{3
    return s:roots[0]
endf


function! s:SetRoot(dir) "{{{3
    let root = substitute(fnamemodify(a:dir, ':p'), '[\/]\+$', '', '') |
    let root = substitute(root, '\\', '/', 'g')
    let idx = index(s:roots, root)
    if idx > 0
        call remove(s:roots, idx)
    endif
    if idx != 0
        call insert(s:roots, root)
    endif
    " Don't reload the file. Old autoload definitions won't be 
    " overwritten anyway.
    if idx == -1 && g:tplugin_autoload
        let autoload = join([root, 'tplugin.vim'], '/')
        if filereadable(autoload)
            exec 'source '. fnameescape(autoload)
        endif
    endif
endf


function! s:AddRepo(repos) "{{{3
    " TLogVAR a:repos
    let rtp = split(&rtp, ',')
    let idx = index(rtp, s:rtp[0])
    if idx == -1
        let idx = 1
    else
        let idx += 1
    endif
    let repos = filter(copy(a:repos), '!has_key(s:done, v:val)')
    if !empty(repos)
        for repo in repos
            let tplugin_repo = fnamemodify(repo, ':h') .'/tplugin_'. fnamemodify(repo, ':t') .'.vim'
            " TLogVAR repo, tplugin_repo
            exec 'silent! source '. fnameescape(tplugin_repo)
            " TLogVAR repo
            call insert(rtp, repo, idx)
            call insert(rtp, join([repo, 'after'], '/'), -1)
            " TLogVAR rtp
            let s:done[repo] = {}
        endfor
        let &rtp = join(rtp, ',')
    endif
endf


function! s:LoadPlugins(repo, plugins) "{{{3
    if empty(a:plugins)
        return
    endif
    " TLogVAR a:repo, a:plugins
    let done = s:done[a:repo]
    let pos0 = len(a:repo) + 1
    for plugin in a:plugins
        " TLogVAR plugin
        if !has_key(done, plugin)
            let done[plugin] = 1
            " TLogVAR plugin
            if filereadable(plugin)
                let before = filter(keys(s:before), 'plugin =~ v:val')
                if !empty(before)
                    call s:Depend(a:repo, before, s:before)
                endif
                " TLogDBG 'source '. plugin
                exec 'source '. fnameescape(plugin)
                " TLogDBG 'runtime! after/'. strpart(plugin, pos0)
                exec 'runtime! after/'. fnameescape(strpart(plugin, pos0))
                let after = filter(keys(s:after), 'plugin =~ v:val')
                if !empty(after)
                    call s:Depend(a:repo, after, s:after)
                endif
            endif
        endif
    endfor
endf


function! s:Depend(repo, filename_rxs, dict) "{{{3
    " TLogVAR a:filename_rxs
    for filename_rx in a:filename_rxs
        let others = a:dict[filename_rx]
        " TLogVAR others
        for other in others
            if stridx(other, '*') != -1
                let files = split(glob(a:repo .'/'. other), '\n')
            else
                let files = [a:repo .'/'. other]
            endif
            call s:LoadPlugins(a:repo, files)
        endfor
    endfor
endf


function! s:Process() "{{{3
    " TLogDBG "Plugin:Process"
    call s:AddRepo(keys(s:reg))
    if !empty(s:reg)
        " TLogVAR &rtp
        for [repo, plugins] in items(s:reg)
            call s:LoadPlugins(repo, plugins)
        endfor
    endif
    let s:immediate = 1
endf


" :nodoc:
function! TPlugin(immediate, root, repo, ...) "{{{3
    " TLogVAR a:immediate, a:root, a:repo, a:000
    if a:repo == '.'
        let repo = a:root
    else
        let root = empty(a:root) ? s:roots[0] : a:root
        let repo = join([root, a:repo], '/')
    endif
    " TLogVAR repo
    if a:repo =~ '[\/]'
        let pdir = repo
    else
        let pdir = join([repo, 'plugin'], '/')
    endif
    " TLogVAR a:repo, repo, pdir, a:000
    if empty(a:000)
        " TLogDBG join([pdir, '*.vim'], '/')
        let plugins = split(glob(join([pdir, '*.vim'], '/')), '\n')
    elseif a:1 == '.'
        let plugins = []
    else
        let plugins = map(copy(a:000), 'join([pdir, v:val .".vim"], "/")')
    endif
    " TLogVAR plugins
    if s:immediate || a:immediate
        " TLogVAR repo, plugins
        call s:AddRepo([repo])
        call s:LoadPlugins(repo, plugins)
    else
        if !has_key(s:reg, repo)
            let s:reg[repo] = []
        endif
        let s:reg[repo] += plugins
    end
endf


function! s:TPluginComplete(ArgLead, CmdLine, CursorPos) "{{{3
    " TLogVAR a:ArgLead, a:CmdLine, a:CursorPos
    let repo = matchstr(a:CmdLine, '\<TPlugin\s\+\zs\(\S\+\)\ze\s')
    " TLogVAR repo
    let rv = []
    " for root in s:roots
    let root = s:roots[0]
    " TLogVAR root
    if empty(repo)
        let pos0 = len(root) + 1
        let files = split(glob(join([root, '*'], '/')), '\n')
        call map(files, 'strpart(v:val, pos0)')
        call filter(files, 'stridx(v:val, a:ArgLead) != -1')
        " TLogVAR files
    else
        let pdir = join([repo, 'plugin'], '/')
        let dir = join([root, pdir], '/')
        let pos0 = len(dir) + 1
        let files = split(glob(join([dir, '*.vim'], '/')), '\n')
        call map(files, 'strpart(v:val, pos0, len(v:val) - pos0 - 4)')
        call filter(files, 'stridx(v:val, a:ArgLead) != -1')
        " TLogVAR files
    endif
    let rv += files
    " endfor
    " TLogVAR rv
    return rv
endf


" :display: :TPlugin[!] REPOSITORY [PLUGINS ...]
" Register certain plugins for being sourced at |VimEnter| time.
" See |tplugin.txt| for details.
"
" With the optional '!', the plugin will be loaded immediately.
" In interactive use, i.e. once vim was loaded, plugins will be loaded 
" immediately anyway.
"
" IF REPOSITORY contains a slash or a backslash, it is considered the 
" path relative from the current root directory to the plugin directory. 
" This allows you to deal with repositories with a non-standard 
" directory layout. Otherwise it is assumed that the source files are 
" located in the "plugin" subdirectory.
command! -bang -nargs=+ -complete=customlist,s:TPluginComplete TPlugin
            \ call TPlugin(!empty("<bang>"), '', <f-args>)


" :display: :TPluginRoot DIRECTORY
" Define the root directory for the following |:TPlugin| commands.
" Read autoload information if available (see |g:tplugin_autoload| and 
" |:TPluginScan|).
command! -nargs=1 -complete=dir TPluginRoot call s:SetRoot(<q-args>)



" :display: :TPluginBefore FILE_RX [FILE_PATTERNS ...]
" Load DEPENDENCIES before loading a file matching the regexp pattern 
" FILE_RX.
"
" The files matching FILE_PATTERNS are loaded after the repo's path is 
" added to the 'runtimepath'. You can thus use partial filenames as you 
" would use for the |:runtime| command.
"
" This command should be best put into ROOT/tplugin_REPO.vim files, 
" which are loaded when enabling a source repository.
"
" Example: >
"   " Load master.vim before loading any plugin in a repo
"   TPluginBefore plugin/*.vim plugin/master.vim
command! -nargs=+ TPluginBefore
            \ let s:before[[<f-args>][0]] = [<f-args>][1:-1]


" :display: :TPluginAfter FILE_RX [OTHER_PLUGINS ...]
" Load OTHER_PLUGINS after loading a file matching the regexp pattern 
" FILE_RX.
" See also |:TPluginBefore|.
"
" Example: >
"   " Load auxiliary plugins after loading master.vim
"   TPluginAfter plugin/master.vim plugin/sub_*.vim
command! -nargs=+ TPluginAfter
            \ let s:after[[<f-args>][0]] = [<f-args>][1:-1]


" :display: :TPluginFunction FUNCTION REPOSITORY [PLUGIN]
" Load a certain plugin on demand (aka autoload) when FUNCTION is called 
" for the first time.
command! -nargs=+ TPluginFunction
            \ if g:tplugin_autoload && !exists('*'. [<f-args>][0]) |
            \ call tplugin#RegisterFunction([s:roots[0], <f-args>])
            \ | endif


" :display: :TPluginCommand COMMAND REPOSITORY [PLUGIN]
" Load a certain plugin on demand (aka autoload) when COMMAND is called 
" for the first time. Then call the original command.
"
" For most plugins, |:TPluginScan| will generate the appropriate 
" TPluginCommand commands for you. For some plugins, you'll have to 
" define autocommands yourself in the |vimrc| file.
" 
" Example: >
"   TPluginCommand TSelectBuffer vimtlib tselectbuffer
command! -nargs=+ TPluginCommand
            \ if g:tplugin_autoload && exists(':'. [<f-args>][0]) != 2 |
            \ exec 'command! -bang -range -nargs=* '. [<f-args>][0]
            \ .' call tplugin#Autoload(1, ['. string(s:roots[0]) .', <f-args>], "<lt>bang>", ["<lt>line1>", "<lt>line2>"], <lt>q-args>)'
            \ | endif


" " :display: TPluginMap MAP_COMMAND REPOSITORY [PLUGIN]
" command! -nargs=+ TPluginMap
"             \ if g:tplugin_autoload |
"             \ call tplugin#Map([s:roots[0], <f-args>])
"             \ | endif


" :display: :TPluginScan[!] [WHAT] [ROOT]
" Scan the current root directory for commands and functions. Save 
" autoload information in "ROOT/tplugin.vim".
"
" Where WHAT is a combination of the following identifiers:
"
"    c ... commands
"    f ... functions
"    p ... <plug> maps
"    a ... autoload
"    t ... filetypes
"    h ... helptags (see also |g:tplugin_helptags|)
"    all ... all of the above
"
" WHAT defaults to |g:tplugin_scan|.
"
" With the optional '!', the autocommands are immediatly usable.
"
" Other than the AsNeeded plugin, tplugin doesn't support the creation 
" of autoload information for maps.
"
" If you collect repositories in one than more directory, I'd suggest to 
" create a special script.
"
" Example: >
"   TPluginRoot dir1
"   TPluginScan
"   TPluginRoot dir2
"   TPluginScan
command! -bang -nargs=* TPluginScan
            \ call tplugin#Scan(!empty("<bang>"), s:roots, [<f-args>])


call s:SetRoot(s:Join([s:rtp[0], 'repos']))


let &cpo = s:save_cpo
unlet s:save_cpo
finish

0.1
- Initial release

0.2
- Improved command-line completion for :TPlugin
- Experimental autoload for commands and functions (à la AsNeeded)
- The after path is inserted at the second to last position
- When autoload is enabled and g:tplugin_menu_prefix is not empty, build 
a menu with available plugins (NOTE: this is disabled by default)

0.3
- Build helptags during :TPluginScan (i.e. support for helptags requires 
autoload to be enabled)
- Call delcommand before autoloading a plugin because of an unknown 
command
- TPluginScan: Take a root directory as the second optional argument
- The autoload file was renamed to ROOT/tplugin.vim
- When adding a repository to &rtp, ROOT/tplugin_REPO.vim is loaded
- TPluginBefore, TPluginAfter commands to define inter-repo dependencies
- Support for autoloading <plug> maps
- Support for autoloading filetypes


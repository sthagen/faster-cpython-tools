
if $SUDO_USER != ""
    let s:sudocfg = '/home/'.$SUDO_USER.'/.vimrc'
    if filereadable(s:sudocfg)
        execute "source " . s:sudocfg
    endif
endif

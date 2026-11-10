function fish_prompt
    set -l last_pipestatus $pipestatus
    set -l normal (set_color normal)
    set -l status_segment ❱
    if string match -qv 0 -- $last_pipestatus
        set -l error_color (set_color $fish_color_error)
        set status_segment "$error_color| $last_pipestatus $error_color❱"
    end
    echo -n -s (set_color $fish_color_cwd) (__prompt_pwd) $normal " " $status_segment $normal " "
end

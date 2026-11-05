function __prompt_status
    set -l normal (set_color normal)
    set -l error_color (set_color $fish_color_error)

    for code in $__prompt_last_pipestatus
        if test $code -ne 0
            echo -n "$error_color| "(string join " " $__prompt_last_pipestatus)" $error_color❱$normal"
            return
        end
    end

    echo -n "❱"
end

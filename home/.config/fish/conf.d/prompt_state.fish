status is-interactive; or exit

set -g __prompt_last_pipestatus 0

function __prompt_store_pipestatus --on-event fish_postexec
    set -g __prompt_last_pipestatus $pipestatus
end

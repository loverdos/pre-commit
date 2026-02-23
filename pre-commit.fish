# Fish function to discover and run the pre-commit script.
# Source this file to make the `pre-commit` function available:
#   source /path/to/pre-commit.fish

function __in_green
    builtin echo -n (set_color green)"$argv"(set_color normal)
end

function log
    builtin echo (__in_green '** ')"$argv" 1>&2
end

function pre-commit --description "Discover and run the pre-commit script"
    # Try to resolve git root
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)

    # Discover pre-commit script:
    #   1. Check for pre-commit directly in the current directory
    #   2. Check for .pre-commit/pre-commit in the current directory
    #   3. Check for .pre-commit/pre-commit at the git repo root
    #   4. Search up to 2 levels deep from git root, let user pick with fzf
    #   5. Give up
    set -l script ""
    if test -x ./pre-commit
        set script (pwd)/pre-commit
        log "Found pre-commit (current directory)"
    else if test -x .pre-commit/pre-commit
        set script (pwd)/.pre-commit/pre-commit
        log "Found .pre-commit/pre-commit (current directory)"
    else if test -n "$git_root"; and test -x "$git_root/.pre-commit/pre-commit"
        set script "$git_root/.pre-commit/pre-commit"
        log "Found .pre-commit/pre-commit (at git root: "(basename "$git_root")")"
    else if test -n "$git_root"
        # Search up to 3 levels deep from git root for files named pre-commit,
        # excluding .git directories
        set -l levels 3
        set -l candidates (find "$git_root" -maxdepth $levels \( -name .git -prune \) -o \( -name pre-commit -type f -print \) 2>/dev/null)

        if test (count $candidates) -eq 0
            log "No pre-commit script found (searched $levels levels deep from "(basename "$git_root")")"
            return 2
        end

        # Show all candidates relative to git root
        log Found (count $candidates) "pre-commit script(s) in "(basename "$git_root")":"
        for c in $candidates
            log "  "(string replace "$git_root/" "" -- $c)
        end

        if test (count $candidates) -eq 1
            # Only one candidate, use it directly
            set script $candidates[1]
        else
            # Multiple candidates, let user pick with fzf
            # Display paths relative to git root, then resolve back to absolute
            set -l relative_candidates
            for c in $candidates
                set -a relative_candidates (string replace "$git_root/" "" -- $c)
            end

            set -l choice (printf '%s\n' $relative_candidates | fzf --prompt="Select pre-commit script: ")
            if test -z "$choice"
                log "No script selected"
                return 1
            end
            set script "$git_root/$choice"
        end

        log "Selected: "(string replace "$git_root/" "" -- $script)
    else
        log "No pre-commit script found (not in a git repo)"
        return 2
    end

    eval $script $argv
end

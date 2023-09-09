YARN_AUTO_COMP_PATH="$(dirname $0)/zsh-yarn-autocomplete"

_get_completions() {
    local completions=$($YARN_AUTO_COMP_PATH $@)
    local comp=(${=completions})
    compadd -- $comp
}

_yarn() {
    if [ -z ${words[2]} ]; then
        _get_completions run
        return
    fi

    case ${words[2]} in
        add) _get_completions add ${words[3]} ;;
        remove) _get_completions remove ;;
        *) ;;
    esac
}

compdef _yarn yarn

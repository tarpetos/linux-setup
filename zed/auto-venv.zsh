# Auto-activate a project's .venv on entering its directory (like PyCharm's terminal)

# Only in a real terminal. Editors (Zed, VS Code) capture the environment by running an
# interactive login shell with piped output; activating there leaks VIRTUAL_ENV and a
# prompt referencing oh-my-zsh functions into every process they start.
[[ -o interactive && -t 1 ]] || return 0

_auto_venv() {
  # A venv inherited through the environment has no deactivate function; drop it
  if [[ -n "$VIRTUAL_ENV" ]] && ! typeset -f deactivate >/dev/null; then
    path=(${path:#$VIRTUAL_ENV/bin})
    unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT
  fi
  if [[ -n "$_AUTO_VENV" && "$PWD/" != "$_AUTO_VENV/"* ]]; then
    deactivate 2>/dev/null
    unset _AUTO_VENV
  fi
  if [[ -z "$VIRTUAL_ENV" && -f .venv/bin/activate ]]; then
    source .venv/bin/activate
    _AUTO_VENV="$PWD"
    # activate exports PS1; keep it out of child processes
    typeset +x PS1
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _auto_venv
_auto_venv

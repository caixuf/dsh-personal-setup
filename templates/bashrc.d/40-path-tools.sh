# templates/bashrc.d/40-path-tools.sh
# 各 CLI 工具与用户级 bin 的 PATH
#
# 安装：追加到 ~/.bashrc
#
# ⚠️ 本文件**刻意不包含**旧机 .bashrc 第 200-210 行附近的以下两行明文密钥：
#     export AIWEBER_API_KEY=sk-ant-...          （另一个 provider 的 key）
#     export TRAECLI_PERSONAL_ACCESS_TOKEN=...   （Trae CLI token）
#   新机若需要，请**单独**安全存放（如 ~/.ccp/secrets.env），不要写进 .bashrc。

# 用户级 bin（ccp / agy-p / 各 CLI wrapper 都在这里）
export PATH="$HOME/.local/bin:$PATH"

# npm 全局包（prefix 由 ~/.npmrc 设为 ~/.npm-global）
# ⚠️ 同一行也需加到 ~/.profile —— .bashrc 的 PATH 只在交互 shell 生效，
#    而 `wsl.exe` 走登录式 shell 读不到（见 templates/profile.d/）
export PATH="$HOME/.npm-global/bin:$PATH"

# --- 各 CLI installer 追加的 PATH（按需启用，装了才加）---

# grok installer
if [ -d "$HOME/.grok/bin" ]; then
    export PATH="$HOME/.grok/bin:$PATH"
    [[ -r "$HOME/.grok/completions/bash/grok.bash" ]] && source "$HOME/.grok/completions/bash/grok.bash"
fi

# MiniMax Code CLI
[ -d "$HOME/.minimax-code/bin" ] && export PATH="$HOME/.minimax-code/bin:$PATH"
[ -d "$HOME/.minimax/bin" ] && export PATH="$HOME/.minimax/bin:$PATH"

# CodeM
[ -d "$HOME/.codem/bin" ] && export PATH="$HOME/.codem/bin:$PATH"

# Antigravity CLI（IDE remote server）
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

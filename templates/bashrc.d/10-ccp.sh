# templates/bashrc.d/10-ccp.sh
# ccp（终端 LLM 环境统一管理）
#
# 安装：追加到 ~/.bashrc（不要覆盖整份）
#   cat templates/bashrc.d/*.sh >> ~/.bashrc
#
# ⚠️ 放在交互守卫【之前】，这样交互 shell 与登录 shell（.profile → .bashrc）都能命中。
#
# 说明：禁止在此硬编码 Step/DeepSeek/Anthropic 的密钥 —— 统一由 ccp 管理（~/.ccp/env.sh）。
#   切换: ccp use deepseek | step | minimax
#   当前 shell 立即生效: ccp reload

if [ -f "$HOME/.ccp/env.sh" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.ccp/env.sh"
fi

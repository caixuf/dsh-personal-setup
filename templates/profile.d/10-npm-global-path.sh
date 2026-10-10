# templates/profile.d/10-npm-global-path.sh
# npm 全局 bin 的 PATH —— **必须放 .profile**，不能只放 .bashrc
#
# 安装：追加到 ~/.profile
#
# 为什么必须两边都有：
#   Ubuntu 默认 .bashrc 对**非交互 shell** 会提前 return（`case $- in *i*` 守卫），
#   而 `wsl.exe -d <distro> -- <cmd>` 走的是**登录式非交互** shell。
#   放在 .bashrc 的 PATH 因此读不到 —— 表现为 `pnpm: command not found`。
#
# 这是踩坑得来的：DSH 的 `wsl` 工具用登录式 shell，
#   ~/.npm-global/bin 只在 .bashrc 里时，pnpm 完全不可见。
#
# 前提：~/.npmrc 里 `prefix=$HOME/.npm-global`
#   （不要用 `corepack enable` —— 它会因 /usr/local/bin 不可写而 EACCES 失败）

if [ -d "$HOME/.npm-global/bin" ] ; then
    PATH="$HOME/.npm-global/bin:$PATH"
fi

# 用户级 bin（ccp 等）
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

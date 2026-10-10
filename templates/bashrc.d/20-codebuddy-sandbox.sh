# templates/bashrc.d/20-codebuddy-sandbox.sh
# CodeBuddy sandbox full pass
#
# ⚠️ 放在交互守卫【之前】，这样交互 shell 与登录 shell 都能命中。
# 效果：bypassPermissions 之上再跳过 HIGH/CRITICAL 危险命令的确认（默认 -y 仍会问）。
#
# ⚠️⚠️ 安全提示：官方标红的高危模式 —— 危险命令不再确认，仅限完全信任的机器。
# 新机若不接受此风险，**不要**启用这段。
#
# 关闭方式：注释/删除下面这行，或当前 shell 执行 `unset CODEBUDDY_IS_SANDBOX`。
export CODEBUDDY_IS_SANDBOX=1

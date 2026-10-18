/**
 * DSH LAN bridge — 让配对到局域网地址的手机 App 能连上只监听回环的 DSH。
 *
 * ## 为什么需要它（2026-10-18 实测）
 *
 * DSH 0.2.1 起 webserver **硬拒绝 0.0.0.0**（通配地址 = 全网卡监听 = 局域网 RCE 面），
 * 而 dsh-desktop-host 又在两处硬编码 `127.0.0.1`（spawn 的 `--host` 参数 +
 * 给 Electron 的 authenticatedUrl），所以桌面端**永远只监听回环**。
 *
 * 手机 App 配对时存下的是 `http://<lan-ip>:19387`（见网关 manage 页的
 * `selectedBaseUrl`，无 publicBaseUrl 时它回落到第一个局域网候选），
 * 于是一到 0.2.1 就永远「重连中」——`Failed to connect to /192.168.x.x:19387`。
 *
 * ## 它做什么
 *
 * 在**一个具体的局域网地址**上监听（不是通配），把 TCP 原样转给 127.0.0.1:19387。
 * 这不削弱 0.2.1 的通配禁令：只暴露单块网卡，正是 App 期望的地址。
 *
 * ## 为什么不用 netsh portproxy
 *
 * `netsh interface portproxy add` 需要管理员权限；本进程不需要，普通用户即可。
 *
 * ## 用法
 *
 *     node dsh-lan-bridge.mjs
 *
 * 可用环境变量覆盖：
 *   DSH_LAN_BRIDGE_HOST  监听地址，默认取系统探测到的第一块非虚拟局域网 IPv4
 *   DSH_LAN_BRIDGE_PORT  监听端口，默认 19387（与 DSH 同端口、不同地址，不冲突）
 *   DSH_LAN_BRIDGE_TARGET 转发目标端口，默认 19387
 */
import net from 'node:net'
import os from 'node:os'

/** 挑一块"像局域网"的非虚拟 IPv4：跳过回环、169.254 link-local、WSL/Hyper-V 虚拟网段。 */
function detectLanHost() {
  const candidates = []
  for (const [name, addresses] of Object.entries(os.networkInterfaces())) {
    for (const address of addresses ?? []) {
      if (address.family !== 'IPv4' || address.internal) continue
      const ip = address.address
      if (ip.startsWith('169.254.')) continue
      // 虚拟网卡（WSL / Hyper-V / Docker）的常见网段
      if (/^(172\.1[6-9]|172\.2\d|172\.3[01])\./.test(ip)) continue
      candidates.push({ name, ip })
    }
  }
  return candidates[0]?.ip
}

const LISTEN_HOST = process.env.DSH_LAN_BRIDGE_HOST ?? detectLanHost()
const LISTEN_PORT = Number(process.env.DSH_LAN_BRIDGE_PORT ?? 19387)
const TARGET_HOST = '127.0.0.1'
const TARGET_PORT = Number(process.env.DSH_LAN_BRIDGE_TARGET ?? 19387)

if (!LISTEN_HOST) {
  console.error(new Date().toISOString(), 'bridge: no LAN IPv4 interface found; set DSH_LAN_BRIDGE_HOST')
  process.exit(1)
}

const server = net.createServer((client) => {
  const upstream = net.connect(TARGET_PORT, TARGET_HOST)
  client.pipe(upstream)
  upstream.pipe(client)
  const close = () => {
    client.destroy()
    upstream.destroy()
  }
  client.on('error', close)
  upstream.on('error', close)
  client.on('close', () => upstream.destroy())
  upstream.on('close', () => client.destroy())
})

server.on('error', (err) => {
  console.error(new Date().toISOString(), 'bridge error:', err.message)
  process.exit(1)
})

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
  console.log(
    new Date().toISOString(),
    `bridge ${LISTEN_HOST}:${LISTEN_PORT} -> ${TARGET_HOST}:${TARGET_PORT}`,
  )
})

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => server.close(() => process.exit(0)))
}

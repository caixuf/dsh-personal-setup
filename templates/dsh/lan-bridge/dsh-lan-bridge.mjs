/**
 * DSH LAN bridge
 *
 * DSH 0.2.1 forbids the webserver from binding 0.0.0.0, and dsh-desktop-host
 * hardcodes --host 127.0.0.1, so the desktop GUI only listens on loopback.
 * The phone app is paired to http://<lan-ip>:19387 and would otherwise stay
 * in "reconnecting" forever.
 *
 * This bridge listens on ONE concrete LAN address (not the wildcard) and
 * forwards TCP to 127.0.0.1:19387. It does not weaken the wildcard ban: only
 * the single LAN interface is exposed, exactly what the app expects.
 *
 * ---- Why there is an HTTP-path fence in a TCP forwarder ----
 *
 * A TCP forwarder erases the caller's identity: every upstream connection
 * comes from 127.0.0.1. dsh-mobile-gateway's management panel guards itself
 * with `isLoopbackAddress(req.socket.remoteAddress)` (lib/manage.mjs:349), so
 * that guard is *always true* for traffic arriving through this bridge — a
 * LAN peer could read /mobile-gateway/manage and /mobile-gateway/manage/api/state
 * (device list, credential metadata) without authentication. Measured
 * 2026-10-18: those two paths answered 200 over 192.168.31.79 while /api
 * correctly returned 403.
 *
 * A Host-header check upstream would not fix it either: the header is
 * attacker-controlled (curl -H "Host: 127.0.0.1:19387" over LAN was accepted).
 * So the fence belongs here, at the only place that still knows the request
 * came from outside loopback.
 *
 * The blocked prefix mirrors the public-access whitelist in the VPS Caddy
 * config, which already refuses /mobile-gateway/manage from the internet. The
 * management panel is a desktop-browser tool; the phone app talks to
 * /mobile-gateway/api/*, /mobile-gateway/events.*, /mobile-gateway/pair and
 * /mobile-gateway/health, none of which are touched here.
 */
import net from 'node:net'
import os from 'node:os'

/**
 * Pick this machine's LAN IPv4 when none is configured.
 *
 * The hardcoded address this bridge used to ship with was the previous
 * machine's; on any other box `listen()` fails and the guard retries forever.
 * Prefer a private-range interface (the phone is on the same LAN), skip
 * loopback/link-local/virtual adapters, and fall back to the first external
 * IPv4 so a machine with an unusual layout still comes up.
 *
 * @returns {string} an IPv4 address, or '' when the machine has none
 */
function detectLanHost() {
  const candidates = []
  for (const [name, addresses] of Object.entries(os.networkInterfaces())) {
    for (const address of addresses ?? []) {
      if (address.internal === true) continue
      if (address.family !== 'IPv4' && address.family !== 4) continue
      if (address.address.startsWith('169.254.')) continue
      candidates.push({ name, address: address.address })
    }
  }
  const isPrivate = (ip) => /^10\./.test(ip) || /^192\.168\./.test(ip) || /^172\.(1[6-9]|2\d|3[01])\./.test(ip)
  const preferred = candidates.find((c) => isPrivate(c.address) && !/^vEthernet|^Loopback|^WSL|^Hyper-V/i.test(c.name))
  return (preferred ?? candidates[0])?.address ?? ''
}

const LISTEN_HOST = process.env.DSH_LAN_BRIDGE_HOST ?? detectLanHost()
const LISTEN_PORT = Number(process.env.DSH_LAN_BRIDGE_PORT ?? 19387)
const TARGET_HOST = '127.0.0.1'
const TARGET_PORT = Number(process.env.DSH_LAN_BRIDGE_TARGET ?? 19387)

/** Paths that must never be reachable through this bridge. */
const BLOCKED_PREFIXES = ['/mobile-gateway/manage']

/** Enough for a request line plus headers start; a longer one is not ours. */
const SNIFF_LIMIT = 8192

/** Does this first chunk of client bytes address a blocked path? */
function isBlockedRequest(chunk) {
  // Only HTTP verbs can be matched; anything else is passed through untouched
  // so a non-HTTP client (or a protocol we do not model) is never broken by
  // a guess.
  const head = chunk.subarray(0, SNIFF_LIMIT).toString('latin1')
  const line = head.slice(0, head.indexOf('\r\n') === -1 ? head.length : head.indexOf('\r\n'))
  const match = /^([A-Z]+)\s+(\S+)\s+HTTP\/\d\.\d$/.exec(line)
  if (match === null) return false
  // Absolute-form request targets (http://host/path) are normalised so the
  // path comparison cannot be dodged with a full URL.
  let pathname = match[2]
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(pathname)) {
    try { pathname = new URL(pathname).pathname } catch { return true }
  }
  if (!pathname.startsWith('/')) pathname = `/${pathname}`
  // Case-insensitive prefix test: HTTP paths are case-sensitive in theory but
  // a fence that can be defeated by capitalisation is not a fence.
  const lower = pathname.toLowerCase()
  return BLOCKED_PREFIXES.some((prefix) => lower === prefix || lower.startsWith(`${prefix}/`) || lower.startsWith(`${prefix}?`))
}

const server = net.createServer((client) => {
  let upstream = null
  let settled = false

  /** Start forwarding; called once we know the request is allowed. */
  const forward = (firstChunk) => {
    if (settled) return
    settled = true
    upstream = net.connect(TARGET_PORT, TARGET_HOST)
    upstream.on('error', close)
    if (firstChunk !== null) upstream.write(firstChunk)
    upstream.pipe(client)
    client.pipe(upstream)
    upstream.on('close', () => client.destroy())
    client.on('close', () => upstream.destroy())
  }

  const close = () => {
    settled = true
    client.destroy()
    upstream?.destroy()
  }

  client.on('error', close)

  // Buffer just until the request line is readable, then decide. A client that
  // sends nothing keeps the default idle behaviour of the socket.
  let buffered = Buffer.alloc(0)
  const onData = (chunk) => {
    buffered = Buffer.concat([buffered, chunk])
    if (settled) return
    if (isBlockedRequest(buffered)) {
      client.removeListener('data', onData)
      settled = true
      // Answer as a plain HTTP refusal so a misdirected browser tab shows the
      // reason instead of a hanging connection.
      client.end(
        'HTTP/1.1 403 Forbidden\r\n'
        + 'Content-Type: application/json; charset=utf-8\r\n'
        + 'Connection: close\r\n'
        + '\r\n'
        + JSON.stringify({ error: { code: 'lan_bridge_blocked', message: '管理面只允许从本机回环访问' } }),
      )
      return
    }
    // A request line ends with CRLF; once we have one, or enough bytes to know
    // this is not an HTTP request line, stop sniffing and forward verbatim.
    const hasLine = buffered.indexOf('\r\n') !== -1
    if (hasLine || buffered.length >= SNIFF_LIMIT) {
      client.removeListener('data', onData)
      forward(buffered)
    }
  }
  client.on('data', onData)
  client.on('close', () => { if (!settled) settled = true })
})

server.on('error', (err) => {
  console.error(new Date().toISOString(), 'bridge error:', err.message)
  process.exit(1)
})

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
  // The listening address is machine-derived, so the guard cannot hardcode it.
  // Print it in a stable, greppable form and the guard reads it back.
  console.log(new Date().toISOString(), `bridge ${LISTEN_HOST}:${LISTEN_PORT} -> ${TARGET_HOST}:${TARGET_PORT}`, `blocked=${BLOCKED_PREFIXES.join(',')}`)
  console.log(`LISTEN=${LISTEN_HOST}:${LISTEN_PORT}`)
})

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    server.close(() => process.exit(0))
  })
}

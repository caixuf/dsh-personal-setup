/**
 * Hidden process launcher for the DSH guard scripts.
 *
 * Why this exists: `start "" /min` in a .cmd only MINIMISES the child's console
 * window - the console still exists, so the window flashes on every guard tick
 * and a long-running child (frpc) keeps a real taskbar entry forever. The guard
 * .cmd files themselves are already started through run-hidden.vbs, but that
 * only hides the .cmd's own window; a child launched with `start` gets a fresh
 * console of its own.
 *
 * Node's `windowsHide: true` maps to CREATE_NO_WINDOW, so the child is created
 * with no console at all - nothing to flash, nothing in the taskbar.
 *
 * `detached: true` + `unref()` lets the guard .cmd exit immediately while the
 * child keeps running (same intent as `start`).
 *
 * Usage:
 *   node start-hidden.mjs <exe-or-script> [args...]
 *   node start-hidden.mjs --log <file> <exe-or-script> [args...]
 *
 * `--log` redirects the child's stdout+stderr into <file>. Without it the child
 * gets no stdio at all (`ignore`), which is right for a daemon whose output
 * nobody reads - but a child whose stdout carries machine-readable state (the
 * LAN bridge prints LISTEN=<ip>:<port> so the guard can learn its own address)
 * needs the file form. Previously the `>> log 2>&1` in the calling .cmd looked
 * like it captured that output, but `stdio: 'ignore'` in this launcher threw it
 * away, so the guard never saw the address it was waiting for.
 *
 * Pure ASCII only.
 */
import { spawn } from 'node:child_process'
import { openSync, closeSync, mkdirSync } from 'node:fs'
import { dirname } from 'node:path'

const argv = process.argv.slice(2)

let logFile = null
let rest = argv
if (rest[0] === '--log') {
  logFile = rest[1]
  rest = rest.slice(2)
  if (logFile === undefined || logFile === '') {
    console.error('start-hidden: --log needs a file path')
    process.exit(2)
  }
}

const [command, ...args] = rest
if (command === undefined || command === '') {
  console.error('start-hidden: missing command')
  process.exit(2)
}

let stdio = 'ignore'
let logFd = null
if (logFile !== null) {
  try {
    mkdirSync(dirname(logFile), { recursive: true })
    // `w` truncates: each start gets a fresh log, so a stale LISTEN= line from
    // a previous run can never be mistaken for the current one.
    logFd = openSync(logFile, 'w')
    stdio = ['ignore', logFd, logFd]
  } catch (error) {
    console.error(`start-hidden: cannot open log ${logFile}: ${error?.message ?? error}`)
    process.exit(3)
  }
}

let child
try {
  child = spawn(command, args, {
    detached: true,
    stdio,
    windowsHide: true,
  })
} catch (error) {
  console.error(`start-hidden: spawn failed: ${error?.message ?? error}`)
  process.exit(3)
}

let settled = false
child.on('error', (error) => {
  if (settled) return
  settled = true
  console.error(`start-hidden: ${error?.message ?? error}`)
  process.exit(3)
})
child.on('spawn', () => {
  if (settled) return
  settled = true
  // Report the pid so the caller can verify liveness without polling guesses.
  console.log(String(child.pid))
  child.unref()
  // The child owns the duplicated handle now; the parent must not keep it open
  // or the guard's own `>> log` redirect stays locked.
  if (logFd !== null) { try { closeSync(logFd) } catch { /* already closed */ } }
  process.exit(0)
})

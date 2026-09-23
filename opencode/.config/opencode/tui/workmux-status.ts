import { execFile } from "node:child_process"
import { promisify } from "node:util"

const run = promisify(execFile)

type Status = "working" | "waiting" | "done"

/**
 * Reports an aggregate OpenCode status to the surrounding workmux window.
 *
 * This is a TERMINAL plugin (cli.json), not a server plugin, and that is the
 * whole point. `workmux set-window-status` identifies its target from TMUX_PANE,
 * and OpenCode 2 serves every session from one shared daemon that inherited
 * TMUX_PANE from whichever client happened to start it first. A server-side
 * plugin therefore reports every job against one unrelated pane. Running in the
 * TUI process puts us back in the pane we are describing.
 * See https://github.com/raine/workmux/issues/291.
 *
 * The daemon streams events for every session, so only sessions rooted in this
 * TUI's own directory are counted. A pane can still host several at once (a
 * parent plus its subagents), and the window shows the most demanding one:
 * `waiting` (needs a human) outranks `working`, which outranks `done`.
 *
 * Exported as a plain object rather than via `Plugin.define` so the file needs
 * no runtime dependency on `@opencode/plugin`.
 */
export default {
  id: "workmux.status",

  setup(ctx: any) {
    const statusBySession = new Map<string, Status>()
    const deleted = new Set<string>()
    let reported: Status | undefined

    const here = (() => {
      try {
        return ctx.location.default()?.directory
      } catch {
        return undefined
      }
    })()

    // Another pane's job on the same daemon is none of this window's business.
    function mine(sessionID: string | undefined) {
      if (!sessionID) return false
      if (!here) return true
      try {
        return ctx.session.get(sessionID)?.location?.directory === here
      } catch {
        return false
      }
    }

    async function report() {
      const statuses = [...statusBySession.values()]
      const status: Status = statuses.includes("waiting")
        ? "waiting"
        : statuses.includes("working")
          ? "working"
          : "done"

      if (reported === status) return
      reported = status

      // Never let a missing or failing workmux take the plugin down with it.
      await run("workmux", ["set-window-status", status]).catch(() => {})
    }

    async function set(sessionID: string | undefined, status: Status) {
      if (!sessionID || deleted.has(sessionID)) return
      if (!mine(sessionID)) return
      // A session we never saw start has nothing to mark finished.
      if (status === "done" && !statusBySession.has(sessionID)) return
      if (statusBySession.get(sessionID) === status) return

      statusBySession.set(sessionID, status)
      await report()
    }

    const offs: Array<() => void> = []
    const on = (type: string, handler: (event: any) => void) => {
      try {
        offs.push(ctx.on(type, handler))
      } catch {
        /* event absent in this OpenCode build */
      }
    }

    // The execution lifecycle is authoritative: unlike raw busy/idle status
    // events it never repeats or trails a finished turn.
    on("session.execution.started", (e) => void set(e.data?.sessionID, "working"))
    for (const type of [
      "session.execution.succeeded",
      "session.execution.failed",
      "session.execution.interrupted",
      "session.idle",
    ]) {
      on(type, (e) => void set(e.data?.sessionID, "done"))
    }

    on("permission.asked", (e) => void set(e.data?.sessionID, "waiting"))
    on("form.created", (e) => void set(e.data?.form?.sessionID, "waiting"))

    for (const type of ["permission.replied", "form.replied", "form.cancelled"]) {
      on(type, (e) => void set(e.data?.sessionID, "working"))
    }

    on("session.deleted", (e) => {
      const sessionID = e.data?.sessionID
      if (!sessionID) return
      deleted.add(sessionID)
      if (statusBySession.delete(sessionID)) void report()
    })

    return () => {
      for (const off of offs) off()
    }
  },
}

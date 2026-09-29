import { execFile } from 'node:child_process';
import type { Plugin } from '@opencode/plugin';

function workmux(...args: string[]) {
  return new Promise<void>((resolve) => {
    execFile('workmux', args, () => resolve());
  });
}

const plugin: Plugin.Plugin = {
  id: 'tommmyy.workmux-status',
  setup: async (ctx) => {
    // Status tracking remains available when registration cannot reach workmux.
    await workmux('register-agent');

    // OpenCode can emit repeated `session.status busy` events for a single turn,
    // and can even emit a stale trailing `busy` after `idle` at the end. Track
    // every parent and child session so one idle session cannot mark the whole
    // pane done while another session is still working.
    const statusBySession = new Map<string, string>();
    const acceptBusyBySession = new Map<string, boolean>();
    const deletedSessions = new Set<string>();
    let reportedStatus: string | undefined;
    let statusQueue = Promise.resolve();

    function queueStatus(status: string) {
      statusQueue = statusQueue.then(() => workmux('set-window-status', status));
      return statusQueue;
    }

    async function reportAggregateStatus() {
      const statuses = [...statusBySession.values()];
      let status = 'done';

      if (statuses.includes('waiting')) {
        status = 'waiting';
      } else if (statuses.includes('working')) {
        status = 'working';
      }

      if (reportedStatus === status) {
        return;
      }

      reportedStatus = status;
      await queueStatus(status);
    }

    async function setStatus(sessionID: string | undefined, status: string) {
      if (!sessionID || deletedSessions.has(sessionID)) {
        return;
      }

      const previous = statusBySession.get(sessionID);
      if (status === 'done' && previous === undefined) {
        return;
      }
      // Ignore the final stale `busy` OpenCode sometimes emits after a session is
      // already done. The next execution re-arms `working` for the new turn.
      if (status === 'working' && acceptBusyBySession.get(sessionID) === false) {
        return;
      }
      if (previous === status) {
        return;
      }

      statusBySession.set(sessionID, status);
      acceptBusyBySession.set(sessionID, status !== 'done');

      await reportAggregateStatus();
    }

    const abort = new AbortController();

    void (async () => {
      for await (const event of ctx.event.subscribe({ signal: abort.signal })) {
        switch (event.type) {
          case 'session.execution.started':
            acceptBusyBySession.set(event.data.sessionID, true);
            break;
          case 'session.status':
            if (event.data.status.type === 'busy') {
              await setStatus(event.data.sessionID, 'working');
            }
            if (event.data.status.type === 'idle') {
              await setStatus(event.data.sessionID, 'done');
            }
            break;
          case 'permission.asked':
            await setStatus(event.data.sessionID, 'waiting');
            break;
          case 'form.created':
            await setStatus(event.data.form.sessionID, 'waiting');
            break;
          case 'permission.replied':
          case 'form.replied':
          case 'form.cancelled':
            await setStatus(event.data.sessionID, 'working');
            break;
          case 'session.idle':
            await setStatus(event.data.sessionID, 'done');
            break;
          case 'session.deleted': {
            const { sessionID } = event.data;
            deletedSessions.add(sessionID);
            acceptBusyBySession.delete(sessionID);
            if (statusBySession.delete(sessionID)) {
              await reportAggregateStatus();
            }
            break;
          }
        }
      }
    })().catch(() => {
      // The stream ends with an abort error on cleanup.
    });

    return () => abort.abort();
  },
};

export default plugin;

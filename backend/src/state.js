// A single SQLite-backed object serializes reservations across all Worker locations.
export class ScanState {
  constructor(ctx, env) {
    this.storage = ctx.storage;
    this.env = env;
    this.sql = this.storage.sql;
    this.sql.exec('CREATE TABLE IF NOT EXISTS nonce (id TEXT PRIMARY KEY, expires INTEGER NOT NULL)');
    this.sql.exec('CREATE TABLE IF NOT EXISTS quota (key TEXT PRIMARY KEY, count INTEGER NOT NULL)');
  }

  async fetch(request) {
    const { operation, id, expires, subject } = await request.json();
    const allowed = this.storage.transactionSync(() => {
      if (operation === 'consume') {
        const now = Math.floor(Date.now() / 1000);
        if (expires <= now) return false;
        this.sql.exec('DELETE FROM nonce WHERE expires <= ?', now);
        return this.sql.exec('INSERT OR IGNORE INTO nonce VALUES (?, ?) RETURNING id', id, expires).toArray().length === 1;
      }
      if (operation !== 'reserve') return false;
      const day = new Date().toISOString().slice(0, 10);
      this.sql.exec("DELETE FROM quota WHERE key LIKE 'day:%' AND key NOT LIKE ?", 'day:' + day + ':%');
      const limits = [
        ['total', Number(this.env.SCAN_TOTAL_LIMIT)],
        ['day:' + day + ':all', Number(this.env.SCAN_DAILY_LIMIT)],
        ['day:' + day + ':user:' + subject, Number(this.env.SCAN_USER_DAILY_LIMIT)]
      ];
      for (const [key, limit] of limits) {
        const count = this.sql.exec('SELECT count FROM quota WHERE key = ?', key).toArray()[0]?.count ?? 0;
        if (!Number.isSafeInteger(limit) || limit < 1 || count >= limit) return false;
      }
      for (const [key] of limits) {
        this.sql.exec('INSERT INTO quota VALUES (?, 1) ON CONFLICT(key) DO UPDATE SET count = count + 1', key);
      }
      return true;
    });
    return Response.json({ allowed });
  }
}

export function scanState(env) {
  const stub = env.SCAN_STATE.get(env.SCAN_STATE.idFromName('primalmacro-scan-budget-v1'));
  async function invoke(payload) {
    const response = await stub.fetch('https://state.internal/', {
      method: 'POST', body: JSON.stringify(payload)
    });
    if (!response.ok) throw new Error('Scan state unavailable');
    return (await response.json()).allowed === true;
  }
  return {
    consume: (id, expires) => invoke({ operation: 'consume', id, expires }),
    reserve: subject => invoke({ operation: 'reserve', subject })
  };
}

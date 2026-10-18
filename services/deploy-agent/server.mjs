// fiddy deploy-agent — one-click read-node deploy as a service.
//
// Runs on a host that has the fiddy repo checked out (e.g. the LC gateway VPS).
// Clients POST a target; the agent runs the same `bin/fiddy` scripts a human
// would, so the service and the tutorial can never drift apart.
//
//   POST /deploy   {"sshTarget": "ubuntu@1.2.3.4"}        -> { jobId }
//   GET  /status/:jobId                                   -> { state, log tail }
//   GET  /health                                          -> { ok: true }
//
// Auth: Authorization: Bearer $DEPLOY_AGENT_TOKEN. The agent never sees user
// keys or seed phrases — it only ever touches infra the user furnishes.
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { writeFile, mkdir } from 'node:fs/promises';

const PORT = process.env.PORT || 3225;
const TOKEN = process.env.DEPLOY_AGENT_TOKEN;
const REPO = process.env.FIDDY_REPO || new URL('../..', import.meta.url).pathname;
const JOBS = new Map();
const MAX_LOG = 64 * 1024;

if (!TOKEN) {
  console.error('DEPLOY_AGENT_TOKEN is required');
  process.exit(1);
}

function runJob(job) {
  job.state = 'running';
  const env = { ...process.env, FIDDY_HOME: `${process.env.HOME}/.fiddy/jobs/${job.id}` };
  const steps = [
    ['provision', ['--ssh', job.sshTarget]],
    ['node', ['up']],
  ];
  (async () => {
    for (const [cmd, args] of steps) {
      job.step = `${cmd} ${args.join(' ')}`;
      const code = await new Promise((resolve) => {
        const p = spawn(`${REPO}/bin/fiddy`, [cmd, ...args], { env });
        p.stdout.on('data', (d) => job.append(d));
        p.stderr.on('data', (d) => job.append(d));
        p.on('error', (e) => { job.append(`\nspawn error: ${e.message}\n`); resolve(1); });
        p.on('close', resolve);
      });
      if (code !== 0) {
        job.state = 'failed';
        job.append(`\n✗ fiddy ${job.step} exited ${code}\n`);
        return;
      }
    }
    // Read back the node endpoint the CLI recorded for this job.
    try {
      const cfg = await import('node:fs/promises').then((fs) =>
        fs.readFile(`${env.FIDDY_HOME}/config`, 'utf8'));
      const m = cfg.match(/^FIDDY_NODE_HTTP=(.+)$/m);
      if (m) job.nodeHttp = m[1].replace(/^["']|["']$/g, '');
    } catch { /* config read is best-effort */ }
    job.state = 'done';
  })();
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const send = (code, obj) => {
    res.writeHead(code, { 'content-type': 'application/json' });
    res.end(JSON.stringify(obj));
  };

  if (url.pathname === '/health') return send(200, { ok: true, service: 'fiddy-deploy-agent' });
  if (req.headers.authorization !== `Bearer ${TOKEN}`) return send(401, { error: 'unauthorized' });

  if (req.method === 'POST' && url.pathname === '/deploy') {
    let body = '';
    for await (const chunk of req) {
      body += chunk;
      if (body.length > 4096) return send(413, { error: 'body too large' });
    }
    let sshTarget;
    try { sshTarget = JSON.parse(body).sshTarget; } catch { return send(400, { error: 'invalid JSON' }); }
    if (typeof sshTarget !== 'string' || !/^[\w.-]+@[\w.-]+$/.test(sshTarget)) {
      return send(400, { error: 'sshTarget must look like user@host' });
    }
    const id = randomUUID();
    const job = {
      id, sshTarget, state: 'queued', step: null, log: '', nodeHttp: null,
      append(d) { this.log = (this.log + d.toString()).slice(-MAX_LOG); },
    };
    JOBS.set(id, job);
    runJob(job);
    return send(202, { jobId: id, statusUrl: `/status/${id}` });
  }

  const m = url.pathname.match(/^\/status\/([\w-]+)$/);
  if (req.method === 'GET' && m) {
    const job = JOBS.get(m[1]);
    if (!job) return send(404, { error: 'unknown job' });
    return send(200, {
      state: job.state, step: job.step, nodeHttp: job.nodeHttp,
      logTail: job.log.slice(-4000),
    });
  }

  send(404, { error: 'not found' });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`fiddy-deploy-agent listening on 127.0.0.1:${PORT}`);
});

#!/usr/bin/env node
import { execFile } from 'node:child_process';
import { access } from 'node:fs/promises';
import { constants } from 'node:fs';

const BRIDGE = Object.freeze({
  name: 'claude-bridge',
  version: '0.1.0',
  transport: 'stdio-json',
});

const args = process.argv.slice(2);
if (!isStatusCommand(args)) {
  writeStatus(unavailable(`unsupported claude-bridge command: ${args.join(' ') || '<empty>'}`));
  process.exitCode = 2;
} else {
  const status = await runtimeStatus();
  writeStatus(status);
}

function isStatusCommand(args) {
  if (args.length === 0) {
    return true;
  }
  if (args.length === 1) {
    return args[0] === 'status' || args[0] === '--json';
  }
  if (args.length === 2) {
    return args[0] === 'status' && args[1] === '--json';
  }
  return false;
}

function writeStatus(status) {
  process.stdout.write(`${JSON.stringify(status)}\n`);
}

async function runtimeStatus() {
  const warnings = [];
  const binaryPath = await findClaudeBinary(warnings);
  if (!binaryPath) {
    return unavailable('claude binary not found in PATH', warnings);
  }

  const [versionResult, helpResult] = await Promise.all([
    run(binaryPath, ['--version'], 3_000),
    run(binaryPath, ['--help'], 3_000),
  ]);

  if (!versionResult.ok) {
    warnings.push(`claude --version failed: ${versionResult.message}`);
  }

  if (!helpResult.ok) {
    warnings.push(`claude --help failed: ${helpResult.message}`);
  }

  const helpText = helpResult.ok ? helpResult.stdout + helpResult.stderr : '';
  const helpSignals = collectHelpSignals(helpText);

  return {
    kind: 'claude_runtime_status',
    runtime: 'claude-code-cli',
    available: versionResult.ok,
    bridge: BRIDGE,
    binaryPath,
    cliVersion: versionResult.ok ? clean(versionResult.stdout || versionResult.stderr) : null,
    nodeVersion: process.version,
    checkedAt: new Date().toISOString(),
    capabilities: capabilitiesFromSignals(helpSignals),
    helpSignals,
    warnings,
  };
}

function unavailable(reason, extraWarnings = []) {
  return {
    kind: 'claude_runtime_status',
    runtime: 'claude-code-cli',
    available: false,
    bridge: BRIDGE,
    binaryPath: null,
    cliVersion: null,
    nodeVersion: process.version,
    checkedAt: new Date().toISOString(),
    capabilities: {
      runtimeDiscovery: false,
      cliPrintJson: false,
      cliStreamJsonOutput: false,
      cliStreamJsonInput: false,
      cliSessionResume: false,
      cliExplicitSessionId: false,
      cliPermissionMode: false,
      cliMcpConfig: false,
      bridgeTurnStreaming: false,
      bridgeSessionMirror: false,
      bridgeNativeApprovals: false,
      bridgeTracingHandoff: false,
    },
    helpSignals: [],
    warnings: [reason, ...extraWarnings],
  };
}

async function findClaudeBinary(warnings) {
  const explicit = process.env.CLAUDE_CODE_BINARY;
  if (explicit) {
    try {
      await access(explicit, constants.X_OK);
      return explicit;
    } catch (error) {
      warnings.push(`CLAUDE_CODE_BINARY is not executable: ${explicit}: ${error.message}`);
    }
  }

  const result = await run('command', ['-v', 'claude'], 2_000, { shell: true });
  if (result.ok) {
    const candidate = clean(result.stdout).split('\n')[0];
    if (candidate) {
      return candidate;
    }
  }

  const whichResult = await run('which', ['claude'], 2_000);
  if (whichResult.ok) {
    const candidate = clean(whichResult.stdout).split('\n')[0];
    if (candidate) {
      return candidate;
    }
  }

  if (result.message) {
    warnings.push(`command -v claude failed: ${result.message}`);
  }
  return null;
}

function collectHelpSignals(helpText) {
  const checks = [
    ['--print', /(?:^|\s)--print(?:\s|,|$)/],
    ['--output-format', /--output-format/],
    ['--output-format=stream-json', /stream-json/],
    ['--input-format=stream-json', /--input-format[\s\S]*stream-json/],
    ['--resume', /--resume/],
    ['--continue', /--continue/],
    ['--session-id', /--session-id/],
    ['--permission-mode', /--permission-mode/],
    ['--mcp-config', /--mcp-config/],
  ];

  return checks
    .filter(([, pattern]) => pattern.test(helpText))
    .map(([signal]) => signal);
}

function capabilitiesFromSignals(signals) {
  const has = new Set(signals);
  return {
    runtimeDiscovery: true,
    cliPrintJson: has.has('--print') && has.has('--output-format'),
    cliStreamJsonOutput: has.has('--output-format=stream-json'),
    cliStreamJsonInput: has.has('--input-format=stream-json'),
    cliSessionResume: has.has('--resume') || has.has('--continue'),
    cliExplicitSessionId: has.has('--session-id'),
    cliPermissionMode: has.has('--permission-mode'),
    cliMcpConfig: has.has('--mcp-config'),
    bridgeTurnStreaming: false,
    bridgeSessionMirror: false,
    bridgeNativeApprovals: false,
    bridgeTracingHandoff: false,
  };
}

function run(command, args, timeoutMs, options = {}) {
  return new Promise((resolve) => {
    execFile(command, args, { timeout: timeoutMs, maxBuffer: 1024 * 1024, ...options }, (error, stdout, stderr) => {
      if (error) {
        resolve({ ok: false, stdout: stdout ?? '', stderr: stderr ?? '', message: error.message });
        return;
      }
      resolve({ ok: true, stdout: stdout ?? '', stderr: stderr ?? '', message: '' });
    });
  });
}

function clean(value) {
  return String(value ?? '').trim();
}

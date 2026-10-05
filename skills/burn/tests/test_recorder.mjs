// Behaviour tests for the usage recorder.
//
// Six statuslines render at once and all six want to write the same sample.
// Every case here is a way that collision corrupts the history the whole
// projection is built on.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, readFileSync, writeFileSync, appendFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const HERE = dirname(fileURLToPath(import.meta.url));
const RECORDER = join(HERE, "..", "..", "..", "hud", "usage-recorder.mjs");
const { recordUsage, trimHistory } = await import(RECORDER);

const NOW = 1_800_000_000_000;      // ms

function payload(five = 40, week = 12) {
  return {
    rate_limits: {
      five_hour: { used_percentage: five, resets_at: NOW / 1000 + 3600 },
      seven_day: { used_percentage: week, resets_at: NOW / 1000 + 86400 },
    },
    model: { id: "claude-opus-5" },
  };
}

function fresh() {
  return mkdtempSync(join(tmpdir(), "burn-rec-"));
}

function lines(dir) {
  try {
    return readFileSync(join(dir, "usage-history.jsonl"), "utf8")
      .split("\n").filter(Boolean);
  } catch {
    return [];
  }
}

test("records the server percentages as one line", () => {
  const dir = fresh();
  recordUsage(payload(), { dir, now: NOW });
  const rows = lines(dir).map((l) => JSON.parse(l));
  assert.equal(rows.length, 1);
  assert.equal(rows[0].five_hour.used_percentage, 40);
  assert.equal(rows[0].seven_day.used_percentage, 12);
  rmSync(dir, { recursive: true, force: true });
});

test("six panes in the same minute write one sample between them", () => {
  // Not a tidiness point: six samples a minute make the file six times its
  // size and make a single rounding step look like six.
  const dir = fresh();
  for (let i = 0; i < 6; i++) recordUsage(payload(), { dir, now: NOW });
  assert.equal(lines(dir).length, 1);
  rmSync(dir, { recursive: true, force: true });
});

test("six SEPARATE processes in the same minute still write one sample", () => {
  // The in-process case is easy. The real shape is six independent statusline
  // processes that never see each other, which is what defeats a check on
  // the file's own timestamp.
  const dir = fresh();
  const script = `
    const { recordUsage } = await import(${JSON.stringify(RECORDER)});
    recordUsage(${JSON.stringify(payload())}, { dir: ${JSON.stringify(dir)}, now: ${NOW} });
  `;
  const kids = [];
  for (let i = 0; i < 6; i++) {
    kids.push(new Promise((resolve) => {
      try {
        execFileSync(process.execPath, ["--input-type=module", "-e", script]);
      } catch { /* a loser exiting is fine */ }
      resolve();
    }));
  }
  assert.equal(lines(dir).length, 1);
  rmSync(dir, { recursive: true, force: true });
});

test("the next minute is sampled again", () => {
  const dir = fresh();
  recordUsage(payload(), { dir, now: NOW });
  recordUsage(payload(), { dir, now: NOW + 61_000 });
  assert.equal(lines(dir).length, 2);
  rmSync(dir, { recursive: true, force: true });
});

test("trimming keeps the newest lines", () => {
  const dir = fresh();
  const path = join(dir, "usage-history.jsonl");
  writeFileSync(path, Array.from({ length: 50 }, (_, i) => `{"ts":${i}}`).join("\n") + "\n");
  trimHistory(path, 10);
  const rows = lines(dir).map((l) => JSON.parse(l));
  assert.equal(rows.length, 10);
  assert.equal(rows[0].ts, 40);
  assert.equal(rows[9].ts, 49);
  rmSync(dir, { recursive: true, force: true });
});

test("a sample written during the trim is not lost", () => {
  // Read, rewrite, rename. Anything appended between the read and the rename
  // is silently deleted by the rename, and with six writers that window is
  // hit sooner or later. The lost line is always the newest one.
  const dir = fresh();
  const path = join(dir, "usage-history.jsonl");
  writeFileSync(path, Array.from({ length: 50 }, (_, i) => `{"ts":${i}}`).join("\n") + "\n");
  trimHistory(path, 10, () => appendFileSync(path, '{"ts":999}\n'));
  const rows = lines(dir).map((l) => JSON.parse(l));
  assert.equal(rows[rows.length - 1].ts, 999);
  rmSync(dir, { recursive: true, force: true });
});

test("a missing quota payload writes nothing at all", () => {
  const dir = fresh();
  recordUsage({ model: { id: "claude-opus-5" } }, { dir, now: NOW });
  assert.equal(lines(dir).length, 0);
  rmSync(dir, { recursive: true, force: true });
});

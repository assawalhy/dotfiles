#!/usr/bin/env node
// Probe WebGL2, WebGPU and video in a real Brave window over CDP.
//
//   node probe-brave-webgpu.mjs [browser] [-- extra browser flags...]
//
// `browser` defaults to `brave` (the wrapper on PATH). To test a build before
// switching to it: `nix/update-nixos.sh build`, then pass the built wrapper,
// e.g. `/nix/var/nix/profiles/system/sw/bin/brave` after a switch, or the
// `result/sw/bin/brave` of a scratch build. Run it from the graphical session:
// it opens a window, because compositing is part of what is being tested.
//
// Exit code 0 means: WebGL2 on, a WebGPU adapter and a compute dispatch that
// returns 41, video frames presented after seeking, and zero GPU-process
// errors in the log. Uses only Node built-ins (Node >= 22 for WebSocket).
import { spawn, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";

const argv = process.argv.slice(2);
const sep = argv.indexOf("--");
const browser = (sep === -1 ? argv[0] : argv.slice(0, sep)[0]) ?? "brave";
const extra = sep === -1 ? [] : argv.slice(sep + 1);

const dir = mkdtempSync(join(tmpdir(), "brave-webgpu-probe-"));
const profile = join(dir, "profile");

// A 6 s H.264 clip, so the video path (VA-API decode, then the import into the
// compositor) is exercised the way a normal page would.
const video = join(dir, "clip.mp4");
const ff = spawnSync("ffmpeg", ["-v", "error", "-f", "lavfi", "-i", "testsrc2=size=1280x720:rate=30",
  "-t", "6", "-c:v", "libx264", "-pix_fmt", "yuv420p", video]);
const haveVideo = ff.status === 0 && existsSync(video);

writeFileSync(join(dir, "probe.html"), `<!doctype html><meta charset=utf-8>
<canvas id=c width=64 height=64></canvas><video id=v muted playsinline width=640 src="clip.mp4"></video>
<script>
window.runProbe = async () => {
  const out = {};
  try {
    const gl = document.getElementById("c").getContext("webgl2");
    if (gl) { gl.clearColor(0, 1, 0, 1); gl.clear(gl.COLOR_BUFFER_BIT);
      const px = new Uint8Array(4); gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px);
      const dbg = gl.getExtension("WEBGL_debug_renderer_info");
      out.webgl2 = { ok: px[1] === 255, renderer: dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : null };
    } else out.webgl2 = { ok: false };
  } catch (e) { out.webgl2 = { ok: false, error: String(e) }; }
  try {
    if (!navigator.gpu) throw new Error("navigator.gpu missing");
    const adapter = await navigator.gpu.requestAdapter();
    if (!adapter) throw new Error("requestAdapter() returned null");
    const i = adapter.info || {};
    out.adapter = { vendor: i.vendor, architecture: i.architecture, device: i.device, description: i.description };
    const dev = await adapter.requestDevice();
    const buf = dev.createBuffer({ size: 4, usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC });
    const rd = dev.createBuffer({ size: 4, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST });
    const pipe = dev.createComputePipeline({ layout: "auto", compute: { entryPoint: "main",
      module: dev.createShaderModule({ code: "@group(0) @binding(0) var<storage, read_write> o: u32; @compute @workgroup_size(1) fn main() { o = 41u; }" }) } });
    const enc = dev.createCommandEncoder(); const p = enc.beginComputePass();
    p.setPipeline(pipe); p.setBindGroup(0, dev.createBindGroup({ layout: pipe.getBindGroupLayout(0), entries: [{ binding: 0, resource: { buffer: buf } }] }));
    p.dispatchWorkgroups(1); p.end(); enc.copyBufferToBuffer(buf, 0, rd, 0, 4); dev.queue.submit([enc.finish()]);
    await rd.mapAsync(GPUMapMode.READ); out.dispatch = new Uint32Array(rd.getMappedRange())[0];
  } catch (e) { out.webgpu_error = String(e); }
  try {
    const v = document.getElementById("v");
    if (!v.src.endsWith("clip.mp4") || ${haveVideo ? "false" : "true"}) throw new Error("no clip (ffmpeg missing?)");
    await v.play();
    for (const t of [1, 4, 2, 5, 0.5, 3]) { v.currentTime = t; await new Promise(r => v.addEventListener("seeked", r, { once: true })); }
    let frames = 0; const count = () => { frames++; v.requestVideoFrameCallback(count); };
    v.requestVideoFrameCallback(count); await new Promise(r => setTimeout(r, 2000));
    out.video = { framesIn2s: frames };
  } catch (e) { out.video = { error: String(e) }; }
  return JSON.stringify(out);
};
</script>`);

const flags = [`--user-data-dir=${profile}`, "--remote-debugging-port=0", "--no-first-run",
  "--no-default-browser-check", "--enable-logging=stderr", "--v=0", ...extra,
  `file://${join(dir, "probe.html")}`];
console.log(`launch: ${browser} ${flags.join(" ")}`);
const child = spawn(browser, flags, { stdio: ["ignore", "pipe", "pipe"] });
let log = "";
child.stdout.on("data", d => (log += d));
child.stderr.on("data", d => (log += d));

let port;
for (let i = 0; i < 100 && !port; i++) {
  await sleep(200);
  const f = join(profile, "DevToolsActivePort");
  if (existsSync(f)) port = readFileSync(f, "utf8").split("\n")[0];
}
if (!port) { console.error("browser never opened a DevTools port\n" + log.slice(-3000)); child.kill(); process.exit(2); }

let id = 0;
const call = (ws, method, params = {}) => new Promise((res, rej) => {
  const n = ++id;
  const on = ev => { const m = JSON.parse(ev.data); if (m.id !== n) return;
    ws.removeEventListener("message", on); m.error ? rej(new Error(m.error.message)) : res(m.result); };
  ws.addEventListener("message", on); ws.send(JSON.stringify({ id: n, method, params }));
});
const open = url => new Promise((res, rej) => { const ws = new WebSocket(url);
  ws.addEventListener("open", () => res(ws)); ws.addEventListener("error", rej); });

const version = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json();
const bws = await open(version.webSocketDebuggerUrl);
let page;
for (let i = 0; i < 50 && !page; i++) {
  const list = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  page = list.find(t => t.type === "page" && t.url.endsWith("probe.html"));
  if (!page) await sleep(200);
}
const pws = await open(page.webSocketDebuggerUrl);
for (let i = 0; i < 50; i++) {
  const r = await call(pws, "Runtime.evaluate", { expression: "typeof window.runProbe" });
  if (r.result.value === "function") break;
  await sleep(200);
}
const r = await call(pws, "Runtime.evaluate", { expression: "window.runProbe()", awaitPromise: true });
const res = JSON.parse(r.result.value);
const info = await call(bws, "SystemInfo.getInfo").catch(() => null);
await sleep(1500); // let late GPU-process errors reach the log
await call(bws, "Browser.close").catch(() => child.kill());

const count = re => (log.match(re) || []).length;
const errors = {
  produceSkia: count(/ProduceSkia/g),
  contextLost: count(/Context was lost|context lost/gi),
  gpuProcessExit: count(/GPU process exited|GPU process crashed|exit_code=\d+/g),
  vulkanWaylandWarning: count(/not compatible with Vulkan/g),
};
const fs = info?.gpu?.featureStatus ?? {};
const summary = {
  browser: version.Browser,
  sessionType: process.env.XDG_SESSION_TYPE,
  waylandDisplay: process.env.WAYLAND_DISPLAY ?? null,
  featureStatus: { webgpu: fs.webgpu, vulkan: fs.vulkan, gpu_compositing: fs.gpu_compositing,
    video_decode: fs.video_decode, webgl2: fs.webgl2, opengl: fs.opengl, skia_graphite: fs.skia_graphite },
  ...res, logErrors: errors,
};
console.log(JSON.stringify(summary, null, 2));

// A software fallback (SwiftShader, llvmpipe, lavapipe) is a failure here:
// the point is hardware WebGL2 and a hardware WebGPU adapter.
const soft = /swiftshader|llvmpipe|lavapipe|software/i;
const hardware = res.adapter && !soft.test(JSON.stringify(res.adapter))
  && !soft.test(res.webgl2?.renderer ?? "");
summary.hardware = Boolean(hardware);
if (!hardware) console.log("software renderer or no adapter: not a hardware path");
const ok = hardware && res.webgl2?.ok && res.dispatch === 41
  && (!haveVideo || res.video?.framesIn2s > 0)
  && errors.produceSkia === 0 && errors.contextLost === 0 && errors.gpuProcessExit === 0;
console.log(ok ? "PASS" : "FAIL");
if (!ok) writeFileSync(join(dir, "browser.log"), log), console.log(`browser log kept in ${join(dir, "browser.log")}`);
else rmSync(dir, { recursive: true, force: true });
process.exit(ok ? 0 : 1);

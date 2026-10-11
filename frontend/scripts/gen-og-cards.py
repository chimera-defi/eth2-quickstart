#!/usr/bin/env python3
"""Generate the blog OpenGraph share cards (1200x630 PNGs) into ../public.

Renders a small self-contained HTML card template to PNG with headless
Chromium. Set CHROME_BIN to your Chromium/Chrome binary, or the script will try
a few common locations (including the Playwright cache).

Usage:  python3 frontend/scripts/gen-og-cards.py
Edit the VARIANTS below (or the CSS/template) and re-run to refresh the cards.
"""
import glob
import os
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
PUBLIC = os.path.normpath(os.path.join(HERE, "..", "public"))


def find_chrome():
    if os.environ.get("CHROME_BIN"):
        return os.environ["CHROME_BIN"]
    candidates = [
        "/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser",
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    ]
    # Playwright's bundled Chromium (any installed version)
    candidates += sorted(glob.glob(
        os.path.expanduser("~/.cache/ms-playwright/chromium-*/chrome-linux*/chrome")))
    for c in candidates:
        if c and os.path.exists(c):
            return c
    return None


CSS = """
<style>
  *{margin:0;box-sizing:border-box}
  html,body{width:1200px;height:630px;overflow:hidden}
  body{background:#0a0b12;color:#e9eaf2;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
    position:relative;padding:70px 76px;display:flex;flex-direction:column;justify-content:space-between}
  .grid{position:absolute;inset:0;background-image:linear-gradient(#23253a 1px,transparent 1px),linear-gradient(90deg,#23253a 1px,transparent 1px);background-size:54px 54px;opacity:.18;-webkit-mask-image:radial-gradient(120% 100% at 78% 0%,#000 30%,transparent 76%)}
  .glow{position:absolute;top:-160px;right:-120px;width:560px;height:560px;border-radius:50%;background:radial-gradient(circle,rgba(167,139,250,.22),transparent 62%);filter:blur(8px)}
  .row{position:relative;display:flex;align-items:center;justify-content:space-between}
  .brand{font-family:ui-monospace,"JetBrains Mono",Menlo,monospace;font-size:22px;letter-spacing:.22em;text-transform:uppercase;color:#8b8ea8}
  .brand b{color:#e9eaf2}
  .tag{font-family:ui-monospace,monospace;font-size:18px;letter-spacing:.14em;text-transform:uppercase;color:#a78bfa;border:1px solid #2e3150;border-radius:8px;padding:8px 14px}
  h1{position:relative;font-size:70px;line-height:1.04;letter-spacing:-.022em;font-weight:800;max-width:21ch}
  h1 .hot{color:#a78bfa}
  .sub{position:relative;font-family:ui-monospace,"JetBrains Mono",monospace;font-size:23px;color:#8b8ea8;letter-spacing:.01em;margin-top:22px;max-width:60ch}
  .sub b{color:#e9eaf2}
  .gauges{position:relative;display:flex;gap:26px}
  .gz{display:flex;flex-direction:column;gap:9px}
  .gz .lab{font-family:ui-monospace,monospace;font-size:15px;letter-spacing:.12em;text-transform:uppercase;color:#5a5d76}
  .gz .val{font-family:ui-monospace,monospace;font-size:27px;font-weight:700;color:#e9eaf2}
  .gz .val.acc{color:#a78bfa}.gz .val.sig{color:#f5a524}
  .foot{position:relative;font-family:ui-monospace,monospace;font-size:22px;color:#a78bfa;letter-spacing:.02em}
</style>
"""


def stat(lab, val, cls=""):
    return f'<div class="gz"><span class="lab">{lab}</span><span class="val {cls}">{val}</span></div>'


def card(tag, headline, sub, stats):
    stats_html = "".join(stat(*s) for s in stats)
    return (f"{CSS}\n<div class=\"grid\"></div><div class=\"glow\"></div>\n"
            f"<div class=\"row\"><div class=\"brand\"><b>ETH2QS</b> · sync-lab</div>"
            f"<div class=\"tag\">{tag}</div></div>\n"
            f"<div><h1>{headline}</h1><div class=\"sub\">{sub}</div></div>\n"
            f"<div class=\"row\"><div class=\"gauges\">{stats_html}</div>"
            f"<div class=\"foot\">eth2quickstart.com</div></div>\n")


def validate_png(path):
    with open(path, "rb") as image:
        header = image.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError(f"Chromium did not produce a valid PNG: {path}")
    width, height = struct.unpack(">II", header[16:24])
    if (width, height) != (1200, 630):
        raise RuntimeError(
            f"Unexpected card dimensions for {path}: {width}x{height} (expected 1200x630)"
        )
    if os.path.getsize(path) == 0:
        raise RuntimeError(f"Chromium produced an empty PNG: {path}")


# name (-> public/<name>.png) : rendered card
VARIANTS = {
    "og": card(
        "Six-week field report",
        'The fastest Ethereum client is one almost <span class="hot">nobody runs</span>.',
        '<b>7 execution + 5 consensus clients</b> · one host · run by AI agents',
        [("Disk", "no clear winner", "acc"), ("Speed winner", "ethrex · 2h16m", "sig"), ("The catch", "restart cliff", "")]),
    "og-bakeoff": card(
        "Six-week field report",
        'The fastest Ethereum client is one almost <span class="hot">nobody runs</span>.',
        '<b>7 execution + 5 consensus clients</b> · one host · run by AI agents',
        [("Disk", "no clear winner", "acc"), ("Speed winner", "ethrex · 2h16m", "sig"), ("The catch", "restart cliff", "")]),
    "og-how-we-tested": card(
        "Methodology",
        'How we ran a six-week bake-off <span class="hot">with Claude</span>.',
        '<b>The orchestration model + the harness</b> that kept a six-week benchmark honest',
        [("Orchestrator", "Claude Opus", "acc"), ("Builders", "Sonnet subagents", ""), ("Governed by", "humans", "sig")]),
    "og-harness": card(
        "Engineering",
        'The bake-off harness, <span class="hot">function by function</span>.',
        '<b>Every script, flag, and data file</b> — the reference for reproducing the campaign',
        [("Runner", "run_bakeoff.sh", "acc"), ("Fairness gate", "config-optimality", ""), ("Restarts", "crash-safe resume", "sig")]),
    "og-results": card(
        "Raw data",
        'Bake-off results — <span class="hot">the raw data</span>.',
        '<b>Every Stage A row, disk footprint, and CL matrix</b> — unrounded, straight from the run',
        [("Stage A", "12/12 PASS", "acc"), ("CL anchors", "3 ELs", ""), ("Figures", "exact bytes", "sig")]),
}


def main():
    chrome = find_chrome()
    if not chrome:
        sys.exit("No Chromium found. Set CHROME_BIN to a Chrome/Chromium binary and re-run.")
    os.makedirs(PUBLIC, exist_ok=True)
    for name, doc in VARIANTS.items():
        html_path = None
        temp_png = None
        destination = os.path.join(PUBLIC, name + ".png")
        try:
            with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as html:
                html.write(doc)
                html_path = html.name
            temp_fd, temp_png = tempfile.mkstemp(
                prefix=f".{name}-", suffix=".png", dir=PUBLIC
            )
            os.close(temp_fd)
            os.unlink(temp_png)
            subprocess.run(
                [
                    chrome,
                    "--headless=new",
                    "--no-sandbox",
                    "--disable-gpu",
                    "--disable-dev-shm-usage",
                    "--hide-scrollbars",
                    "--force-color-profile=srgb",
                    "--run-all-compositor-stages-before-draw",
                    "--virtual-time-budget=2500",
                    "--window-size=1200,630",
                    "--screenshot=" + temp_png,
                    "file://" + html_path,
                ],
                check=True,
                timeout=60,
                stdout=subprocess.DEVNULL,
            )
            validate_png(temp_png)
            os.replace(temp_png, destination)
            temp_png = None
            print(f"{name}.png -> {os.path.getsize(destination)} bytes")
        finally:
            for path in (html_path, temp_png):
                if path and os.path.exists(path):
                    os.unlink(path)


if __name__ == "__main__":
    main()

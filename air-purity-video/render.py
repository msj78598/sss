# -*- coding: utf-8 -*-
"""
تصيير الفيديو: يلتقط إطارات المشاهد من scenes.html عبر Chromium (Playwright)
إطاراً بإطار بزمن محدَّد، ثم يضغطها بـ H.264، ويمزج التعليق الصوتي مع موسيقى خلفية هادئة.
الاستخدام:  python3 narration.py && python3 render.py [--preview]
"""
import json, os, subprocess, sys, time
import imageio_ffmpeg
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
OUT_DIR = os.path.join(HERE, "output")
FINAL = os.path.join(OUT_DIR, "نقاوة-الهواء-ديم-الجميعان.mp4")
POSTER = os.path.join(OUT_DIR, "poster.jpg")
W, H = 1920, 1080
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
CHROME = os.environ.get("CHROME_PATH")
if not CHROME:
    root = os.environ.get("PLAYWRIGHT_BROWSERS_PATH", os.path.expanduser("~/.cache/ms-playwright"))
    for d in sorted(os.listdir(root)) if os.path.isdir(root) else []:
        cand = os.path.join(root, d, "chrome-linux", "chrome")
        if d.startswith("chromium-") and os.path.exists(cand):
            CHROME = cand

PREVIEW = "--preview" in sys.argv   # يصيّر إطاراً واحداً لكل مشهد فقط للمراجعة


def render_frames(timing, video_path):
    fps = timing["fps"]
    total = timing["total"]
    n = int(round(total * fps))
    enc = subprocess.Popen(
        [FFMPEG, "-y", "-loglevel", "error", "-f", "image2pipe", "-vcodec", "mjpeg", "-r", str(fps), "-i", "-",
         "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
         "-profile:v", "high", "-level", "4.1", "-movflags", "+faststart", video_path],
        stdin=subprocess.PIPE)
    with sync_playwright() as p:
        kw = {"executable_path": CHROME} if CHROME else {}
        browser = p.chromium.launch(**kw)
        page = browser.new_page(viewport={"width": W, "height": H}, device_scale_factor=1)
        page.goto("file://" + os.path.join(HERE, "scenes.html"))
        page.evaluate("t => initTiming(t)", timing)
        page.evaluate("document.fonts.ready")
        page.wait_for_timeout(600)
        t0 = time.time()
        for i in range(n):
            t = i / fps
            page.evaluate("t => render(t)", t)
            enc.stdin.write(page.screenshot(type="jpeg", quality=96))
            if i % 300 == 0:
                el = time.time() - t0
                print(f"frame {i}/{n}  t={t:6.1f}s  elapsed {el:5.0f}s", flush=True)
        # صورة الغلاف من مشهد العنوان
        page.evaluate("t => render(t)", 3.5)
        page.screenshot(type="jpeg", quality=92, path=POSTER)
        browser.close()
    enc.stdin.close()
    enc.wait()
    print("video frames done ->", video_path)


def preview_frames(timing):
    os.makedirs(os.path.join(BUILD, "preview"), exist_ok=True)
    with sync_playwright() as p:
        kw = {"executable_path": CHROME} if CHROME else {}
        browser = p.chromium.launch(**kw)
        page = browser.new_page(viewport={"width": W, "height": H})
        page.goto("file://" + os.path.join(HERE, "scenes.html"))
        page.evaluate("t => initTiming(t)", timing)
        page.evaluate("document.fonts.ready")
        page.wait_for_timeout(600)
        for s in timing["scenes"]:
            for frac in (0.15, 0.6, 0.95):
                t = s["start"] + s["dur"] * frac
                page.evaluate("t => render(t)", t)
                page.screenshot(type="jpeg", quality=85,
                                path=os.path.join(BUILD, "preview", f"{s['id']}_{int(frac*100):02d}.jpg"))
        browser.close()
    print("previews in", os.path.join(BUILD, "preview"))


def build_audio(timing, audio_path):
    """يمزج مقاطع التعليق الصوتي في مواضعها الزمنية مع موسيقى خلفية مُولَّدة رقمياً."""
    total = timing["total"]
    inputs, filters, mix_labels = [], [], []
    for i, s in enumerate(timing["scenes"]):
        inputs += ["-i", s["wav"]]
        ms = int(s["audio_offset"] * 1000)
        filters.append(f"[{i}:a]aresample=48000,adelay={ms}|{ms},volume=1.0[n{i}]")
        mix_labels.append(f"[n{i}]")
    k = len(timing["scenes"])
    # موسيقى خلفية: وسادة صوتية ناعمة تتناوب بين وترَين بهدوء (A major / D major)
    pad = ("aevalsrc="
           "'(0.5+0.5*sin(2*PI*t/24))*(sin(2*PI*220*t)+0.8*sin(2*PI*277.18*t)+0.7*sin(2*PI*329.63*t)+0.35*sin(2*PI*440*t))"
           "+(0.5-0.5*sin(2*PI*t/24))*(sin(2*PI*293.66*t)+0.8*sin(2*PI*369.99*t)+0.7*sin(2*PI*440*t)+0.35*sin(2*PI*587.33*t))'"
           f":s=48000:c=stereo:d={total}")
    filters.append(f"{pad},lowpass=f=900,tremolo=f=0.15:d=0.25,volume=0.011,"
                   f"afade=t=in:st=0:d=3,afade=t=out:st={total-4:.2f}:d=4[bg]")
    filters.append("".join(mix_labels) + f"amix=inputs={k}:normalize=0:dropout_transition=0,"
                   "alimiter=limit=0.95[voice]")
    filters.append("[voice][bg]amix=inputs=2:normalize=0,loudnorm=I=-16:TP=-1.5:LRA=11[out]")
    cmd = [FFMPEG, "-y", "-loglevel", "error"] + inputs + [
        "-filter_complex", ";".join(filters), "-map", "[out]",
        "-t", f"{total:.3f}", "-c:a", "aac", "-b:a", "192k", audio_path]
    subprocess.run(cmd, check=True)
    print("audio mix done ->", audio_path)


def mux(video_path, audio_path, final):
    os.makedirs(os.path.dirname(final), exist_ok=True)
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", video_path, "-i", audio_path,
                    "-c:v", "copy", "-c:a", "copy", "-shortest", "-movflags", "+faststart", final], check=True)
    print("final ->", final)


if __name__ == "__main__":
    timing = json.load(open(os.path.join(BUILD, "timing.json"), encoding="utf-8"))
    if PREVIEW:
        preview_frames(timing)
        sys.exit(0)
    video = os.path.join(BUILD, "video_only.mp4")
    audio = os.path.join(BUILD, "audio_mix.m4a")
    build_audio(timing, audio)
    render_frames(timing, video)
    mux(video, audio, FINAL)

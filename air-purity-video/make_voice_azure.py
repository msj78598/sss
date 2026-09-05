# -*- coding: utf-8 -*-
"""
توليد التعليق الصوتي بأصوات Azure AI Speech العصبية (عربية سعودية) إلى مجلد voice/.
المتطلبات: متغيّرا البيئة AZURE_SPEECH_KEY و AZURE_SPEECH_REGION (مثل uaenorth أو eastus)،
والسماح بالوصول إلى *.tts.speech.microsoft.com.
    python3 make_voice_azure.py                      # ar-SA-ZariyahNeural (أنثوي)
    python3 make_voice_azure.py ar-SA-HamedNeural    # رجالي
ثم: python3 narration.py && python3 render.py
"""
import os, re, sys, urllib.request
from xml.sax.saxutils import escape
from narration import SCENES

KEY = os.environ.get("AZURE_SPEECH_KEY")
REGION = os.environ.get("AZURE_SPEECH_REGION", "uaenorth")
VOICE_NAME = sys.argv[1] if len(sys.argv) > 1 else "ar-SA-ZariyahNeural"
RATE = os.environ.get("AZURE_SPEECH_RATE", "-6%")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "voice")


def strip_tashkeel(t):
    # الصوت العصبي يتنبأ بالتشكيل بدقة؛ نُبقي الشدّة والتنوين فقط لأنهما يفيدان في النطق والوقف
    return re.sub(r"[َُِْٰ]", "", t)


def synth(text, path):
    ssml = (f'<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="ar-SA">'
            f'<voice name="{VOICE_NAME}"><prosody rate="{RATE}">{escape(text)}</prosody></voice></speak>')
    req = urllib.request.Request(
        f"https://{REGION}.tts.speech.microsoft.com/cognitiveservices/v1",
        data=ssml.encode("utf-8"), method="POST",
        headers={"Ocp-Apim-Subscription-Key": KEY, "Content-Type": "application/ssml+xml",
                 "X-Microsoft-OutputFormat": "riff-24khz-16bit-mono-pcm", "User-Agent": "air-purity-video"})
    with urllib.request.urlopen(req, timeout=60) as r, open(path, "wb") as f:
        f.write(r.read())


def main():
    if not KEY:
        sys.exit("AZURE_SPEECH_KEY غير مضبوط. أضِفه كمتغيّر بيئة (لا تلصقه في الكود).")
    os.makedirs(OUT, exist_ok=True)
    for sid, _, _, text in SCENES:
        path = os.path.join(OUT, f"{sid}.wav")
        synth(strip_tashkeel(text), path)
        print("saved", path, os.path.getsize(path) // 1024, "KB")


if __name__ == "__main__":
    main()

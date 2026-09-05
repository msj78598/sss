# -*- coding: utf-8 -*-
"""
توليد تعليق صوتي عربي طبيعي (صوت عصبي من Microsoft، مجاني بلا مفتاح) لكل مشهد إلى مجلد voice/.
يحتاج اتصالاً بالإنترنت (speech.platform.bing.com). شغّله على جهازك ثم:
    pip install edge-tts
    python3 make_voice_edge.py                 # صوت أنثوي سعودي: ar-SA-ZariyahNeural
    python3 make_voice_edge.py ar-SA-HamedNeural   # أو صوت رجالي
ثم: python3 narration.py && python3 render.py
"""
import asyncio, os, re, sys
import edge_tts
from narration import SCENES

VOICE_NAME = sys.argv[1] if len(sys.argv) > 1 else "ar-SA-ZariyahNeural"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "voice")


def strip_tashkeel(t):
    # الأصوات العصبية تنطق النص غير المشكَّل نطقاً صحيحاً؛ نُبقي الشدّة والتنوين فقط لأنها تفيد الوقف
    return re.sub(r"[ًٌٍَُِْٰ]", "", t)


async def main():
    os.makedirs(OUT, exist_ok=True)
    for sid, _, _, text in SCENES:
        path = os.path.join(OUT, f"{sid}.mp3")
        await edge_tts.Communicate(text, VOICE_NAME, rate="-8%").save(path)
        print("saved", path)


if __name__ == "__main__":
    asyncio.run(main())

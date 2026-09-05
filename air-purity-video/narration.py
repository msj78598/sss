# -*- coding: utf-8 -*-
"""
توليد التعليق الصوتي العربي لكل مشهد (بدون إنترنت بعد تنزيل النموذج)
يستخدم نموذج Piper العربي (ar_JO-kareem-medium) عبر sherpa-onnx.
الناتج: build/audio/sXX.wav + build/timing.json (أزمنة بداية كل مشهد ومدته).
"""
import json, os, sys, tarfile, urllib.request
import sherpa_onnx, soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
AUDIO = os.path.join(BUILD, "audio")
MODEL_DIR = os.path.join(BUILD, "vits-piper-ar_JO-kareem-medium")
MODEL_URL = ("https://github.com/k2-fsa/sherpa-onnx/releases/download/"
             "tts-models/vits-piper-ar_JO-kareem-medium.tar.bz2")

# النص مُشكَّل بالكامل لتحسين نطق المحرّك الصوتي
SCENES = [
    ("s1", 1.2, 2.0,
     "السَّلامُ عَلَيْكُمْ وَرَحْمَةُ اللهِ وَبَرَكاتُهُ. "
     "نُرَحِّبُ بِكُمْ فِي هَذا العَرْضِ عَنْ نَقاوَةِ الهَواءِ، "
     "مِنْ إِعْدادِ الطّالِبَةِ دِيم مَشْهُور الجُمَيْعان، "
     "مِنَ الصَّفِّ الثّالِثِ المُتَوَسِّطِ، بِمُتَوَسِّطَةِ الوادِي وَالبُحَيْرات."),
    ("s2", 0.8, 2.2,
     "الهَواءُ الَّذِي نَتَنَفَّسُهُ خَلِيطٌ مِنَ الغازاتِ: "
     "ثَمانِيَةٌ وَسَبْعُونَ بِالمِئَةِ نِيتْرُوجِين، وَواحِدٌ وَعِشْرُونَ بِالمِئَةِ أُكْسِجِين، "
     "وَنَحْوُ واحِدٍ بِالمِئَةِ غازاتٌ أُخْرى. "
     "وَنَقاوَةُ الهَواءِ تَعْنِي خُلُوَّهُ مِنَ المُلَوِّثاتِ الضّارَّةِ "
     "بِتَراكِيزَ تُهَدِّدُ صِحَّةَ الإِنْسانِ وَالبِيئَةِ."),
    ("s3", 0.8, 2.2,
     "مِنْ أَبْرَزِ مُلَوِّثاتِ الهَواءِ: الجُسَيْماتُ الدَّقِيقَةُ الَّتِي لا تَراها العَيْنُ، "
     "وَأَوَّلُ أُكْسِيدِ الكَرْبُونِ، وَثانِي أُكْسِيدِ النِّيتْرُوجِينِ، "
     "وَثانِي أُكْسِيدِ الكِبْرِيتِ، وَالأُوزُونُ الأَرْضِيُّ، "
     "وَالمُرَكَّباتُ العُضْوِيَّةُ المُتَطايِرَةُ."),
    ("s4", 0.8, 2.2,
     "وَتَأْتِي هَذِهِ المُلَوِّثاتُ مِنْ مَصادِرَ عَدِيدَةٍ: "
     "عَوادِمِ السَّيّاراتِ، وَدُخانِ المَصانِعِ، وَحَرْقِ النُّفاياتِ، وَالعَواصِفِ الرَّمْلِيَّةِ، "
     "إِضافَةً إِلى مَصادِرَ داخِلَ المَنازِلِ، مِثْلِ التَّدْخِينِ وَالمُنَظِّفاتِ الكِيمِيائِيَّةِ."),
    ("s5", 0.8, 2.2,
     "تُقَدِّرُ مُنَظَّمَةُ الصِّحَّةِ العالَمِيَّةُ أَنَّ تَلَوُّثَ الهَواءِ "
     "يُسَبِّبُ نَحْوَ سَبْعَةِ مَلايِينِ وَفاةٍ مُبَكِّرَةٍ سَنَوِيًّا، "
     "وَأَنَّ تِسْعَةً وَتِسْعِينَ بِالمِئَةِ مِنْ سُكّانِ العالَمِ "
     "يَتَنَفَّسُونَ هَواءً يَتَجاوَزُ الحُدُودَ الآمِنَةَ. "
     "وَيُؤَدِّي الهَواءُ المُلَوَّثُ إِلى الرَّبْوِ، وَأَمْراضِ الرِّئَةِ، وَأَمْراضِ القَلْبِ."),
    ("s6", 0.8, 2.2,
     "وَلِقِياسِ جَوْدَةِ الهَواءِ نَسْتَخْدِمُ مُؤَشِّرَ جَوْدَةِ الهَواءِ. "
     "فَمِنْ صِفْرٍ إِلى خَمْسِينَ يَكُونُ الهَواءُ جَيِّدًا، "
     "وَمِنْ خَمْسِينَ إِلى مِئَةٍ مُعْتَدِلًا، "
     "وَكُلَّما ارْتَفَعَ المُؤَشِّرُ زادَ الخَطَرُ عَلى الصِّحَّةِ، "
     "حَتّى يَصِلَ إِلى مُسْتَوىً خَطِيرٍ فَوْقَ ثَلاثِ مِئَةٍ."),
    ("s7", 0.8, 2.2,
     "وَالحُلُولُ تَبْدَأُ مِنّا: زِراعَةُ الأَشْجارِ، وَاسْتِخْدامُ وَسائِلِ النَّقْلِ العامِّ، "
     "وَتَرْشِيدُ اسْتِهْلاكِ الطّاقَةِ، وَتَهْوِيَةُ المَنازِلِ، وَالابْتِعادُ عَنِ الحَرْقِ وَالتَّدْخِينِ. "
     "وَتَسْعى مُبادَرَةُ السُّعُودِيَّةِ الخَضْراءِ إِلى زِراعَةِ عَشَرَةِ مِلْياراتِ شَجَرَةٍ، "
     "لِهَواءٍ أَنْقى وَمُسْتَقْبَلٍ أَجْمَلَ."),
    ("s8", 1.0, 3.0,
     "الهَواءُ النَّقِيُّ نِعْمَةٌ وَمَسْؤُولِيَّةٌ، فَلْنَحْمِها مَعًا. "
     "كانَ هَذا العَرْضُ مِنْ إِعْدادِ الطّالِبَةِ دِيم مَشْهُور الجُمَيْعان، "
     "مِنْ مُتَوَسِّطَةِ الوادِي وَالبُحَيْرات. شُكْرًا لِحُسْنِ اسْتِماعِكُمْ."),
]


def ensure_model():
    if os.path.isdir(MODEL_DIR):
        return
    os.makedirs(BUILD, exist_ok=True)
    tgz = MODEL_DIR + ".tar.bz2"
    print("downloading voice model ...")
    urllib.request.urlretrieve(MODEL_URL, tgz)
    with tarfile.open(tgz, "r:bz2") as t:
        t.extractall(BUILD)
    os.remove(tgz)


def main():
    ensure_model()
    os.makedirs(AUDIO, exist_ok=True)
    cfg = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                model=os.path.join(MODEL_DIR, "ar_JO-kareem-medium.onnx"),
                tokens=os.path.join(MODEL_DIR, "tokens.txt"),
                data_dir=os.path.join(MODEL_DIR, "espeak-ng-data"),
                length_scale=1.12,   # أبطأ قليلاً لوضوح أفضل
            ),
            num_threads=4,
        )
    )
    tts = sherpa_onnx.OfflineTts(cfg)

    t = 0.0
    scenes = []
    for sid, lead, tail, text in SCENES:
        audio = tts.generate(text, sid=0, speed=1.0)
        path = os.path.join(AUDIO, f"{sid}.wav")
        sf.write(path, audio.samples, audio.sample_rate)
        dur_audio = len(audio.samples) / audio.sample_rate
        dur = lead + dur_audio + tail
        scenes.append({"id": sid, "start": round(t, 3), "dur": round(dur, 3),
                       "audio_offset": round(t + lead, 3), "audio_dur": round(dur_audio, 3),
                       "wav": path})
        print(f"{sid}: narration {dur_audio:5.1f}s  scene {dur:5.1f}s  starts at {t:6.1f}s")
        t += dur
    timing = {"fps": 30, "total": round(t, 3), "scenes": scenes}
    with open(os.path.join(BUILD, "timing.json"), "w", encoding="utf-8") as f:
        json.dump(timing, f, ensure_ascii=False, indent=1)
    print(f"total: {t:.1f}s")


if __name__ == "__main__":
    main()

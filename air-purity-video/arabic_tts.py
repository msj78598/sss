# -*- coding: utf-8 -*-
"""
محوّل نص عربي مُشكَّل إلى رموز صوتية (IPA) بقواعد صريحة، ثم توليد الصوت مباشرة من نموذج Piper
عبر onnxruntime. الهدف: تجاوز espeak-ng الذي يُسقط حركات الحروف المشدّدة ويخطئ في المدّ والهمزة،
وهو سبب "الكلام المكسّر" في النسخة الأولى.
"""
import json, re, numpy as np, onnxruntime as ort

FATHA, DAMMA, KASRA, SUKUN, SHADDA = "َ", "ُ", "ِ", "ْ", "ّ"
FATHATAN, DAMMATAN, KASRATAN = "ً", "ٌ", "ٍ"
DAGGER = "ٰ"
HARAKAT = {FATHA: "a", DAMMA: "u", KASRA: "i"}
TANWEEN = {FATHATAN: "an", DAMMATAN: "un", KASRATAN: "in"}
DIACRITICS = set(HARAKAT) | set(TANWEEN) | {SUKUN, SHADDA, DAGGER}

CONS = {
    "ب": "b", "ت": "t", "ث": "θ", "ج": "dʒ", "ح": "ħ", "خ": "χ", "د": "d", "ذ": "ð", "ر": "r", "ز": "z",
    "س": "s", "ش": "ʃ", "ص": "s̪", "ض": "dˤ", "ط": "t̪", "ظ": "ð", "ع": "ʕ", "غ": "ɣ", "ف": "f", "ق": "q",
    "ك": "k", "ل": "l", "م": "m", "ن": "n", "ه": "h", "و": "w", "ي": "j",
    "ء": "ʔ", "أ": "ʔ", "إ": "ʔ", "ؤ": "ʔ", "ئ": "ʔ", "ة": "t", "ى": "aː", "آ": "ʔaː",
}
SUN = set("تثدذرزسشصضطظلن")
PUNCT_MAP = {"،": ",", ",": ",", "؛": ",", ";": ",", ":": ",", ".": ".", "؟": ".", "?": ".", "!": ".", "…": "."}


def split_word(w):
    """يقسّم الكلمة إلى وحدات (حرف, مجموعة حركاته)."""
    units = []
    for ch in w:
        if ch in DIACRITICS:
            if units:
                units[-1][1] += ch
        elif ch == "ـ":  # تطويل
            continue
        else:
            units.append([ch, ""])
    return units


def word_to_phones(word, utter_initial, pausal):
    # لفظ الجلالة: الألف الخنجرية غير مكتوبة
    m = re.fullmatch(r"([وفبل]?[َِ]?)(ال|ل)ل[َّ]*ه([َُِ]?)", word)
    if m and word.replace("ّ", "") in ("الله", "اللهِ", "اللهُ", "اللهَ", "والله", "وَاللهِ", "بِاللهِ", "لِلهِ", "وَاللهُ", "تَاللهِ"):
        pre = {"": "", "وَ": "wa", "بِ": "bi", "لِ": "li", "تَ": "ta", "و": "wa", "ب": "bi", "ل": "li", "ف": "fa", "فَ": "fa"}.get(m.group(1), "")
        v = HARAKAT.get(m.group(3), "")
        core = ("ʔa" if (not pre and utter_initial) else ("a" if not pre else "")) + "ll" + "ˈaː" + "h"
        phones = ([pre] if pre else []) + [core] + ([v] if (v and not pausal) else [])
        return phones
    units = split_word(word)
    out = []          # قائمة رموز
    i = 0
    n = len(units)

    def vowel_of(d):
        if SHADDA in d and not any(h in d for h in HARAKAT) and not any(t in d for t in TANWEEN):
            return ""  # شدة بلا حركة (نادر): سكون
        for h, v in HARAKAT.items():
            if h in d:
                return v
        for t, v in TANWEEN.items():
            if t in d:
                return v
        if DAGGER in d:
            return "aː"
        return None   # لا حركة مكتوبة

    def emit_cons(c, d):
        ph = CONS.get(c, "")
        if not ph:
            return
        if SHADDA in d:
            out.append(ph)
        out.append(ph)

    while i < n:
        c, d = units[i]
        nxt = units[i + 1] if i + 1 < n else None
        # ---- أداة التعريف (ال) ----
        if c == "ا" and nxt and nxt[0] == "ل" and (i == 0 or (i == 1 and units[0][0] in "وفبكل")) \
           and (i + 2 < n) and SHADDA not in d and d in ("", FATHA):
            after = units[i + 2] if i + 2 < n else None
            # الحرف الشمسي يحمل شدّة -> تُدغم اللام
            if i == 0:
                out.append("ʔ" if utter_initial else "")
                out.append("a")
            else:
                pass  # وَالْ / بِالْ : وصل
            if after and after[0] in SUN and SHADDA in after[1]:
                pass  # تُسقط اللام؛ الشدة تضاعف الحرف التالي
            else:
                out.append("l")
            i += 2
            continue
        # ---- ألف الوصل (اسْتِخْدام، ابْتِعاد، وَالابْتِعاد): ألف بلا حركة يليها حرف ساكن ----
        if c == "ا" and d == "" and nxt and SUKUN in nxt[1]:
            if not out:
                out.append("ʔi" if utter_initial else "i")
            elif out[-1] and out[-1][-1] not in "aiuː":   # بعد صامت (لام التعريف مثلاً) -> كسرة
                out.append("i")
            # بعد حركة (وَاسْتِخْدام): تسقط همزة الوصل
            i += 1
            continue
        # ---- الألف: مدّ بعد فتحة، أو فتحة ممدودة بعد صامت غير مشكَّل، أو صامتة بعد تنوين ----
        if c == "ا":
            if out and out[-1] == "a":
                out[-1] = "aː"
            elif out and out[-1] == "an":
                pass  # ألف التنوين صامتة
            elif out and out[-1] and out[-1][-1] not in "aiuː":
                out.append("aː")          # الهواء، الغازات، هذا
            elif not out:
                out.append("ʔa" if utter_initial else "a")
            i += 1
            continue
        # ---- الواو والياء كحرفَي مدّ ----
        if c == "و" and d in ("", SUKUN) and out and out[-1] == "u" and not (nxt and nxt[0] == "ا" and nxt[1] == ""):
            out[-1] = "uː"; i += 1; continue
        if c == "و" and d == SUKUN and out and out[-1] == "a":
            out[-1] = "au"; i += 1; continue   # يَوْم -> jaum (كما في espeak)
        if c == "ي" and d in ("", SUKUN) and out and out[-1] == "i" and not (nxt and nxt[0] == "ا" and nxt[1] == ""):
            out[-1] = "iː"; i += 1; continue   # قِيام: الياء صامتة (j) إذا تلتها ألف
        if c == "ي" and d == SUKUN and out and out[-1] == "a":
            out[-1] = "ai"; i += 1; continue
        if c == "ى":
            if out and out[-1] == "a":
                out[-1] = "aː"
            else:
                out.append("aː")
            i += 1; continue
        if c == "آ":
            out.append("ʔ"); out.append("aː"); i += 1; continue
        # ---- التاء المربوطة ----
        if c == "ة":
            v = vowel_of(d)
            if v is None or (pausal and i == n - 1):
                # في الوقف: يبقى صوت الفتحة قبلها فقط + هاء خفيفة
                out.append("h")
            else:
                out.append("t"); out.append(v)
            i += 1; continue
        # ---- الصوامت ----
        if c in CONS:
            emit_cons(c, d)
            v = vowel_of(d)
            if v:
                out.append(v)
            i += 1
            continue
        i += 1  # حرف غير معروف
    # ---- الوقف: إسقاط الحركة الأخيرة القصيرة أو التنوين ----
    if pausal and out:
        last = out[-1]
        if last in ("a", "i", "u", "un", "in"):
            out.pop()
        elif last == "an":
            out[-1] = "aː"
    # ---- النبر: قبل آخر مقطع ذي مدّ وإلا قبل الحركة قبل الأخيرة ----
    phones = [p for p in out if p]
    vowel_idx = [k for k, p in enumerate(phones) if p[0] in "aiu"]
    if vowel_idx:
        long_idx = [k for k in vowel_idx if "ː" in phones[k] or phones[k] in ("au", "ai")]
        target = long_idx[-1] if long_idx else (vowel_idx[-2] if len(vowel_idx) > 1 else vowel_idx[0])
        phones.insert(target, "ˈ")
    return phones


def text_to_sentences(text):
    """يُرجع قائمة جُمَل، كل جملة قائمة رموز IPA (مع ',' للفواصل)."""
    text = text.replace("\n", " ")
    tokens = re.findall(r"[؀-ۿ]+|[،,؛;:.؟?!…]", text)
    sentences, cur = [], []
    utter_initial = True
    for k, tok in enumerate(tokens):
        if tok in PUNCT_MAP:
            p = PUNCT_MAP[tok]
            if p == ".":
                if cur:
                    sentences.append(cur); cur = []
                utter_initial = True
            else:
                if cur:
                    cur.append(",")
                utter_initial = True  # بعد الفاصلة تُنطق همزة القطع بوضوح
            continue
        nxt = tokens[k + 1] if k + 1 < len(tokens) else None
        pausal = nxt is None or nxt in PUNCT_MAP
        phones = word_to_phones(tok, utter_initial, pausal)
        if cur and cur[-1] != ",":
            cur.append(" ")
        elif cur and cur[-1] == ",":
            cur.append(" ")
        cur.extend(phones)
        utter_initial = False
    if cur:
        sentences.append(cur)
    return sentences


class PiperArabic:
    def __init__(self, model_dir, length_scale=1.1, noise_scale=0.667, noise_w=0.8):
        import glob, os
        onnx = glob.glob(os.path.join(model_dir, "*.onnx"))[0]
        self.cfg = json.load(open(onnx + ".json", encoding="utf-8"))
        self.id_map = self.cfg["phoneme_id_map"]
        self.sr = self.cfg["audio"]["sample_rate"]
        self.sess = ort.InferenceSession(onnx, providers=["CPUExecutionProvider"])
        self.scales = np.array([noise_scale, length_scale, noise_w], dtype=np.float32)

    def ids(self, phones):
        ids = [self.id_map["^"][0]]
        for p in phones:
            for ch in p:                       # الرموز المركبة (dʒ, s̪, aː) تُفكّ إلى رموز مفردة
                if ch in self.id_map:
                    ids.append(self.id_map[ch][0])
                    ids.append(self.id_map["_"][0])
        ids.append(self.id_map["$"][0])
        return np.array([ids], dtype=np.int64)

    def synth(self, text, gap=0.45):
        chunks = []
        for sent in text_to_sentences(text):
            x = self.ids(sent)
            audio = self.sess.run(None, {"input": x, "input_lengths": np.array([x.shape[1]], dtype=np.int64),
                                         "scales": self.scales})[0].squeeze()
            chunks.append(audio.astype(np.float32))
            chunks.append(np.zeros(int(gap * self.sr), dtype=np.float32))
        return np.concatenate(chunks[:-1]) if chunks else np.zeros(0, dtype=np.float32)


if __name__ == "__main__":
    import sys
    for s in text_to_sentences(sys.argv[1] if len(sys.argv) > 1 else "الهَواءُ الَّذِي نَتَنَفَّسُهُ خَلِيطٌ مِنَ الغازاتِ، وَنَقاوَةُ الهَواءِ."):
        print("".join(s))

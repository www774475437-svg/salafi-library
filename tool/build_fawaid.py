#!/usr/bin/env python3
"""Ties every channel post to its exact place in the library's own books.

  python3 tool/build_fawaid.py <dir holding books/<id>/...>

Reads tool/fawaid_src/*.txt, lines of
  post id|first words|last words|book code|volume|page
and rewrites the channel's part of assets/data/fawaid.json. The text of each
saying is taken from the book itself, never from the channel. A post whose
words are not found in the book goes to "pending", which only the developer
page shows.
"""
import glob, html, json, re, sys
from bisect import bisect_right

ROOT = sys.argv[1]
URL = "https://t.me/Ebn_taymeah"
BOOKS = {  # code -> (book id, name written in the source line)
    "J": (145376, "جامع المسائل"),
    "U": (151, "شرح عمدة الفقه"),
    "F": (7289, "مجموع الفتاوى"),
    "M": (147665, "مناسك الحج"),
    "Q": (11620, "اقتضاء الصراط المستقيم"),
}
EAST = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")
LETTER = re.compile("[ء-غف-ي]")
FOLD = {"أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ى": "ي", "ة": "ه", "ؤ": "و", "ئ": "ي"}


def clean(text):
    """Main text of a page: no footnotes, no markers, no tags."""
    text = re.split(r"\n_{5,}", text)[0]
    text = re.sub(r"<[^>]+>", "", html.unescape(text))
    text = re.sub(r"\(\^[^)]*\)", "", text)
    text = re.sub(r"\[ق\s*[^\]]*\]", "", text)
    text = re.sub(r"\[(?:\d+/)?[\d٠-٩]+\s*[أب]?\]", "", text)
    return re.sub(r"[ \t]+", " ", text).strip()


def norm_map(text):
    """Letters only, folded; with the place of each kept letter in `text`."""
    out, at = [], []
    space = True
    for i, ch in enumerate(text):
        if LETTER.match(ch):
            out.append(FOLD.get(ch, ch))
            at.append(i)
            space = False
        elif not space and (ch.isspace() or ch in "،.؛:؟!«»\"()[]{}-ـ—﴿﴾*=/"):
            out.append(" ")
            at.append(i)
            space = True
    return "".join(out), at


def norm(text):
    return norm_map(text)[0].strip()


class Book:
    def __init__(self, bid):
        d = f"{ROOT}/books/{bid}"
        ix = json.load(open(f"{d}/i.json", encoding="utf-8"))
        self.page_map = ix["page_map"]
        parts, self.starts, pos = [], [], 0
        k = 0
        while True:
            try:
                rows = json.load(open(f"{d}/p{k}.json", encoding="utf-8"))
            except FileNotFoundError:
                break
            for r in rows:
                t = clean(r[2] or "") + "\n"
                self.starts.append(pos)
                parts.append(t)
                pos += len(t)
            k += 1
        self.text = "".join(parts)
        self.n, self.at = norm_map(self.text)
        # place in the folded text where each page begins
        self.nstart = []
        j = 0
        for s in self.starts:
            while j < len(self.at) and self.at[j] < s:
                j += 1
            self.nstart.append(j)

    def page_of(self, npos):  # 0-based page index
        return max(0, bisect_right(self.nstart, npos) - 1)

    def index_of(self, vol, page):
        key = f"{vol},{page}"
        for i, v in enumerate(self.page_map):
            if v == key:
                return i
        return None

    def find_all(self, q):
        res, i = [], self.n.find(q)
        while i >= 0:
            res.append(i)
            i = self.n.find(q, i + 1)
        return res

    def label(self, pidx):
        v = self.page_map[pidx] or ""
        vol, _, page = v.partition(",")
        return vol, page


def loose(book, q, lo, hi, last=False):
    """Words of q in order, a few other words allowed between them."""
    w = [re.escape(x) for x in norm(q).split()]
    if len(w) < 2:
        return None
    m = list(re.finditer(r"(?<![^ ])" + r"\S*(?: \S+){0,4}? \S*".join(w), book.n[lo:hi]))
    if not m:
        return None
    m = m[-1] if last else m[0]
    return lo + m.start(), lo + m.end()


def locate(book, a, z, want):
    got = strict(book, a, z, want)
    if got or want is None:
        return got
    # near the cited page only: the channel shortens and trims
    lo = book.nstart[max(0, want - 2)]
    hi = book.nstart[min(len(book.nstart) - 1, want + 3)]
    sa = loose(book, a, lo, hi) if a else None
    if not sa:
        return runs(book, a, z, want)
    sz = loose(book, z, sa[0], min(hi + 4000, sa[0] + 7000), last=False) if z else None
    if sz:
        return sa[0], sz[1]
    return strict_end(book, sa[0], a)


def run(book, q, lo, hi):
    """The longest stretch of q's words found as they stand: (start, end)."""
    w = norm(q).split()
    least = 3 if len(w) > 3 else 2
    for n in range(len(w), least - 1, -1):
        for i in range(0, len(w) - n + 1):
            part = " ".join(w[i:i + n])
            if len(part) < 9:
                continue
            j = book.n.find(part, lo, hi)
            if j >= 0:
                return j, j + len(part)
    return None


def runs(book, a, z, want):
    """The channel reworded the opening: settle for the cited page itself."""
    lo = book.nstart[max(0, want - 1)]
    hi = book.nstart[min(len(book.nstart) - 1, want + 2)]
    ra = run(book, a, lo, hi) if a else None
    if not ra:
        return None
    # back to where the clause begins
    o = book.at[ra[0]]
    cut = max(book.text.rfind(c, max(0, o - 160), o) for c in "،.؛:\n؟!")
    start = bisect_right(book.at, cut) if cut >= 0 else ra[0]
    # "فإنه ..." alone says nothing: take the clause before it too
    if re.match(r"(فإن|وهو |فهو |وهي |فهي |وذلك )", book.text[book.at[start]:book.at[start] + 6]) and cut > 0:
        c2 = max(book.text.rfind(c, max(0, cut - 200), cut) for c in ".؛\n؟!")
        if c2 >= 0:
            start = bisect_right(book.at, c2)
    rz = run(book, z, ra[1] - 1, min(len(book.n), ra[1] + 7000)) if z and norm(z) != norm(a) else None
    if rz:
        return start, rz[1]
    oe = book.at[ra[1] - 1]
    m = re.search(r"[.!؟\n]", book.text[oe:oe + 700])
    return start, bisect_right(book.at, oe + (m.start() if m else 0))


def strict_end(book, start, a):
    o = book.at[start]
    m = re.search(r"[.!؟\n]", book.text[o + len(a) // 2:o + 900])
    oe = o + len(a) // 2 + m.start() if m else o + 300
    return start, bisect_right(book.at, oe)


def strict(book, a, z, want):
    """(start, end) in the folded text, or None."""
    na, nz = norm(a), norm(z)
    near = lambda hits: min(hits, key=lambda h: abs(book.page_of(h) - (want if want is not None else book.page_of(h))))
    start = None
    if len(na.split()) >= 3:
        hits = book.find_all(na)
        if hits:
            start = near(hits)
    if start is None and nz:
        # anchor on the ending, then walk back to the opening words
        hz = book.find_all(nz)
        if not hz:
            return None
        e = near(hz)
        if na:
            s = book.n.rfind(na, max(0, e - 2500), e + len(nz))
            if s < 0:
                return None
            return s, e + len(nz)
        return None
    if start is None:
        return None
    if nz:
        e = book.n.find(nz, start, start + 7000)
        if e >= 0:
            return start, e + len(nz)
    # no ending given, or it differs: stop at the end of the sentence
    o = book.at[start]
    m = re.search(r"[.!؟\n]", book.text[o + len(a) // 2:o + 900])
    oe = o + len(a) // 2 + m.start() if m else o + 300
    e = bisect_right(book.at, oe)
    return start, e


def main():
    posts = []
    for f in sorted(glob.glob("tool/fawaid_src/ebn_taymeah_*.txt")):
        for line in open(f, encoding="utf-8"):
            p = line.rstrip("\n").split("|")
            if len(p) == 6 and p[0].isdigit():
                posts.append((int(p[0]), p[1].strip(), p[2].strip(), p[3], p[4], p[5]))
    posts.sort()
    books = {}
    items, pending, seen = [], [], set()
    fixed = 0
    for pid, a, z, code, vol, page in posts:
        bid, name = BOOKS[code]
        if bid not in books:
            books[bid] = Book(bid)
        b = books[bid]
        want = b.index_of(vol, page)
        cited = f"{name} جـ{vol} صـ{page}".translate(EAST) if code != "M" else f"{name} صـ{page}".translate(EAST)
        got = locate(b, a, z, want) if (a or z) else None
        if got is None or (not a):
            pending.append({"id": pid, "a": a or z, "s": cited})
            continue
        s, e = got
        key = (bid, s)
        if key in seen:
            continue  # the channel posted it again
        seen.add(key)
        pidx = b.page_of(s)
        text = b.text[b.at[s]:b.at[min(e, len(b.at)) - 1] + 1]
        text = re.sub(r"\s*\n\s*", " ", text).strip(" ،؛:\"«»-")
        text = re.sub(r"\s*-\s*([ﷺ﵁﵂﵃﵄﵀])\s*-\s*", r" \1 ", text)
        text = re.sub(r"\s+([،.؛:؟!»﴾])", r"\1", text)
        for o, c in ("﴿﴾", "«»", "()"):
            if text.count(c) > text.count(o):
                text = o + text
            elif text.count(o) > text.count(c):
                text = text + c
        if len(text) > 1800 or len(text) < 8:
            pending.append({"id": pid, "a": a, "s": cited})
            seen.discard(key)
            continue
        v, pg = b.label(pidx)
        src = (f"{name} جـ{v} صـ{pg}" if len(b.page_map) and code != "M" else f"{name} صـ{pg}").translate(EAST)
        it = {"t": text, "s": src, "b": bid, "p": pidx + 1, "n": pid}
        if want is None or abs(pidx - want) > 1:
            it["was"] = cited  # the channel wrote another page
            fixed += 1
        items.append(it)
    path = "assets/data/fawaid.json"
    data = json.load(open(path, encoding="utf-8"))
    data["accounts"] = [x for x in data["accounts"] if x.get("url") != URL]
    data["accounts"].append({
        "scholar": "ibn-taymiyya",
        "by": "قناة «ابن تيمية» في تيليجرام: t.me/Ebn_taymeah",
        "url": URL,
        "items": items,
    })
    data["pending"] = pending
    json.dump(data, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"posts {len(posts)}  tied {len(items)}  page corrected {fixed}  pending {len(pending)}")
    print("pending ids:", [p["id"] for p in pending])


main()

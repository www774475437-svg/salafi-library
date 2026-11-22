"""Runs on GitHub before every build: makes assets/data/catalog.json, the list
of the scholars' books in «تراث» (turath.io) with each book's name, pages,
volumes and section. The texts themselves are read from «تراث» inside the app
(page by page online, or the whole book downloaded for offline reading).

If «تراث» cannot be reached, the catalog already in the repository is kept."""
import json
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

OUT = Path("assets/data/catalog.json")
UA = {"User-Agent": "salafi-library-catalog/1.0"}

# key, full name, short name, honorific, death (Hijri, None = alive),
# turath author id (None = find by name), words to find the author by name
SCHOLARS = [
    ("ibn-taymiyya", "شيخ الإسلام ابن تيمية", "ابن تيمية", "رَحِمَهُ الله", 728, 54, ["ابن تيمية"]),
    ("ibn-alqayyim", "الإمام ابن قيم الجوزية", "ابن القيم", "رَحِمَهُ الله", 751, 14, ["ابن القيم", "ابن قيم"]),
    ("ibn-rajab", "الحافظ ابن رجب الحنبلي", "ابن رجب", "رَحِمَهُ الله", 795, 184, ["ابن رجب"]),
    ("ibn-baz", "الشيخ عبد العزيز بن باز", "ابن باز", "رَحِمَهُ الله", 1420, 67, ["ابن باز"]),
    ("albani", "الشيخ محمد ناصر الدين الألباني", "الألباني", "رَحِمَهُ الله", 1420, 414, ["الألباني"]),
    ("ibn-uthaymeen", "الشيخ محمد بن صالح العثيمين", "ابن عثيمين", "رَحِمَهُ الله", 1421, 57, ["ابن عثيمين", "العثيمين"]),
    ("alwadii", "الشيخ مقبل بن هادي الوادعي", "مقبل الوادعي", "رَحِمَهُ الله", 1422, None, ["الوادعي", "مقبل بن هادي"]),
    ("alfawzan", "الشيخ صالح بن فوزان الفوزان", "صالح الفوزان", "حفظه الله", None, 62, ["الفوزان"]),
]


def get(url, tries=4):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            if i == tries - 1:
                raise
            print("retry", url, e)
            time.sleep(2 + i * 3)


def book_meta(bid):
    try:
        j = get(f"https://api.turath.io/book?id={bid}&include=indexes&ver=3")
    except Exception as e:  # noqa: BLE001
        print("skip book", bid, e)
        return None
    m = j.get("meta") or {}
    ix = j.get("indexes") or {}
    pages = len(ix.get("page_map") or [])
    if not m.get("name") or pages == 0:
        return None
    return {
        "id": bid,
        "name": m["name"].strip(),
        "pages": pages,
        "vols": len(ix.get("volumes") or []) or 1,
        "cat": m.get("cat_id") or 0,
        "heads": len(ix.get("headings") or []),
        "info": (m.get("info") or "").strip()[:600],
    }


def main():
    try:
        data = get("https://files.turath.io/data-v3.json")
    except Exception as e:  # noqa: BLE001
        print("turath not reachable, keeping the old catalog:", e)
        return
    authors = data.get("authors") or {}
    cats = {int(k): v.get("name", "") for k, v in (data.get("cats") or {}).items()}

    out = []
    for key, name, short, hon, death, aid, words in SCHOLARS:
        a = authors.get(str(aid)) if aid else None
        if a is None or not any(w in a.get("name", "") for w in words):
            found = [x for x in authors.values() if any(w in x.get("name", "") for w in words)]
            found.sort(key=lambda x: -len(x.get("books") or []))
            a = found[0] if found else None
        if a is None:
            print("author not found:", short)
            out.append({"key": key, "name": name, "short": short, "honorific": hon, "death": death, "authorId": 0, "books": []})
            continue
        ids = list(dict.fromkeys(a.get("books") or []))
        with ThreadPoolExecutor(8) as ex:
            books = [b for b in ex.map(book_meta, ids) if b]
        for b in books:
            b["catName"] = cats.get(b["cat"], "")
        books.sort(key=lambda b: b["name"])
        print(short, a.get("id"), len(books), "books")
        out.append({"key": key, "name": name, "short": short, "honorific": hon, "death": death,
                    "authorId": a.get("id"), "books": books})

    if sum(len(s["books"]) for s in out) == 0:
        print("no books found, keeping the old catalog")
        return
    OUT.write_text(json.dumps({"made": int(time.time()), "scholars": out}, ensure_ascii=False, separators=(",", ":")),
                   encoding="utf-8")
    print("catalog written", OUT.stat().st_size, "bytes")


if __name__ == "__main__":
    sys.exit(main())

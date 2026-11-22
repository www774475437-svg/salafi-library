"""Runs on GitHub: keeps a full copy of the chosen scholars' books inside the
library itself, so the website and the app read them from our own site
(https://www774475437-svg.github.io/salafi-library/books/...) and not from «تراث».

Downloaded files are kept in bookcache/ between builds (GitHub cache), so each
book is fetched from «تراث» only once.

Output, in site_books/:
  hosted.json          [book ids]
  <id>/i.json          {"headings", "page_map", "volumes"}
  <id>/p<k>.json       pages k*CHUNK+1 .. (k+1)*CHUNK as [[vol, page, text], ...]
"""
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HOSTED = ["ibn-alqayyim", "ibn-taymiyya"]  # scholars whose books are kept in the library (more later)
CHUNK = 40
CACHE = Path("bookcache")
OUT = Path("site_books")
UA = {"User-Agent": "salafi-library-books/1.0"}
TIME_LIMIT = 75 * 60  # stop fetching after this; the rest come in the next build


def fetch(url, tries=8):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if i == tries - 1 or e.code not in (429, 500, 502, 503, 504):
                raise
            wait = int(e.headers.get("Retry-After") or 0) or (10 + i * 10)
            print("  wait", wait, "s for", url)
            time.sleep(min(wait, 90))
        except Exception:  # noqa: BLE001
            if i == tries - 1:
                raise
            time.sleep(5 + i * 5)


HARAKAT = re.compile("[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]")
TAGS = re.compile(r"<[^>]+>")
SPACES = re.compile(r"\s+")
FOLD = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا", "ى": "ي", "ة": "ه", "ؤ": "و", "ئ": "ي"})


def norm(text):
    """Search form of a page, the same as norm() in lib/text.dart."""
    t = TAGS.sub(" ", text).replace("&nbsp;", " ")
    t = HARAKAT.sub("", t).translate(FOLD)
    return SPACES.sub(" ", t).strip()


def main():
    start = time.time()
    cat = json.loads(Path("assets/data/catalog.json").read_text(encoding="utf-8"))
    CACHE.mkdir(exist_ok=True)
    OUT.mkdir(exist_ok=True)
    hosted = []
    for s in cat["scholars"]:
        if s["key"] not in HOSTED:
            continue
        for b in s["books"]:
            bid = b["id"]
            raw_f, idx_f = CACHE / f"{bid}.json", CACHE / f"{bid}.idx.json"
            if not (raw_f.exists() and idx_f.exists()):
                if time.time() - start > TIME_LIMIT:
                    print("time limit reached, the rest next build")
                    break
                try:
                    idx = fetch(f"https://api.turath.io/book?id={bid}&include=indexes&ver=3")
                    time.sleep(1)
                    raw = fetch(f"https://files.turath.io/books-v3/{bid}.json")
                    json.loads(raw)  # must be a whole book
                    idx_f.write_bytes(idx)
                    raw_f.write_bytes(raw)
                    print("got", bid, b["name"], len(raw) // 1024, "KB")
                    time.sleep(1.5)
                except Exception as e:  # noqa: BLE001
                    print("skip", bid, e)
                    continue
            try:
                idx_all = json.loads(idx_f.read_text(encoding="utf-8"))
                ix = idx_all.get("indexes") or {}
                pdf = (idx_all.get("meta") or {}).get("pdf_links") or None
                pages = json.loads(raw_f.read_text(encoding="utf-8")).get("pages") or []
            except Exception as e:  # noqa: BLE001
                print("bad cache", bid, e)
                raw_f.unlink(missing_ok=True)
                continue
            d = OUT / str(bid)
            d.mkdir(exist_ok=True)
            (d / "i.json").write_text(json.dumps({
                "headings": ix.get("headings") or [],
                "page_map": ix.get("page_map") or [],
                "volumes": ix.get("volumes") or [],
                "count": len(pages),
                "chunk": CHUNK,
                "pdf": pdf,
            }, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
            rows = [[str(p.get("vol") or ""), int(p.get("page") or 0), p.get("text") or ""] for p in pages]
            for k in range(0, len(rows), CHUNK):
                (d / f"p{k // CHUNK}.json").write_text(json.dumps(rows[k:k + CHUNK], ensure_ascii=False, separators=(",", ":")),
                                                      encoding="utf-8")
            # light text for searching (no harakat), one page per line, for the website search
            (d / "s.txt").write_text("\n".join(norm(r[2]).replace("\n", " ") for r in rows), encoding="utf-8")
            hosted.append(bid)
    (OUT / "hosted.json").write_text(json.dumps(hosted), encoding="utf-8")
    size = sum(f.stat().st_size for f in OUT.rglob("*") if f.is_file())
    print(len(hosted), "books kept in the library,", size // (1024 * 1024), "MB")


if __name__ == "__main__":
    sys.exit(main())

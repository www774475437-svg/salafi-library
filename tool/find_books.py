"""One-off helper: lists the books of «تراث» that match some names, to choose from."""
import json, sys, urllib.request
d = json.loads(urllib.request.urlopen(urllib.request.Request("https://files.turath.io/data-v3.json", headers={"User-Agent": "salafi-library-catalog/1.0"}), timeout=90).read())
print("KEYS", {k: (len(v) if hasattr(v, "__len__") else v) for k, v in d.items()})
books = d.get("books") or {}
if isinstance(books, list):
    books = {str(b.get("id")): b for b in books}
one = next(iter(books.values()))
print("BOOK SAMPLE", json.dumps(one, ensure_ascii=False)[:400])
cats = d.get("cats") or {}
print("CATS", json.dumps({k: v.get("name") for k, v in cats.items()}, ensure_ascii=False))
authors = d.get("authors") or {}
def aname(b):
    a = authors.get(str(b.get("author_id") or b.get("author") or ""), {})
    return a.get("name", "")
tafsir_cats = [k for k, v in cats.items() if "تفسير" in (v.get("name") or "")]
pats = ["صحيح البخاري", "صحيح مسلم", "سنن أبي داود", "سنن الترمذي", "سنن النسائي", "المجتبى", "سنن ابن ماجه", "الجامع الكبير", "الجامع المسند الصحيح", "المسند الصحيح المختصر"]
for bid, b in books.items():
    n = b.get("name", "")
    if any(p in n for p in pats) and len(n) < 70:
        print("H", bid, "|", n, "|", aname(b), "|", b.get("cat_id"))
for bid, b in books.items():
    if str(b.get("cat_id")) in tafsir_cats:
        print("T", bid, "|", b.get("name", ""), "|", aname(b))

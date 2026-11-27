"""Builds assets/data/masail.json: the chapters that carry the same title in different books.

Usage: python3 tool/build_masail.py <dir with {id}.gz indexes> <full catalog.json>
The match is on the whole title (after its opening word and number), never on a word inside it,
so a chapter is listed only where another book has a chapter of the same name.
"""
import collections, glob, gzip, json, os, re, sys

HAR = re.compile('[ً-ٰٟـ]')


def norm(t):
    t = HAR.sub('', t)
    # the hamza is kept as written: «الأيمان» (oaths) and «الإيمان» (faith) are two subjects
    t = re.sub('[آٱ]', 'ا', t).replace('ى', 'ي').replace('ة', 'ه')
    t = re.sub(r'[^ء-ي ]', ' ', t)
    return re.sub(' +', ' ', t).strip()


def work(book_name):
    """The work without its edition: «جامع العلوم والحكم - ت الفحل» and «… - ت الأرنؤوط» are one work."""
    n = book_name.split(' - ')[0]
    n = re.sub(r'\s+(ت|ط)\s.*$', '', n)
    return norm(n)


# words that open a heading without naming its subject
LEAD = set('مسألة مسائل المسألة فائدة فوائد قاعدة سؤال أحكام إلى أن أو إذا باب فصل كتاب مساله مسايل المساله فرع مبحث مطلب المبحث المطلب الفصل الباب القول ذكر بيان حكم احكام ما جاء ورد في من عن علي تتمه تنبيه فايده فوايد قاعده سوال جواب س ج شرح تفسير قوله تعالي'.split())
STOP = set('إلى أن أو إذا إن أنه في من عن علي الي ان او و ما لا هل هو هي ذلك هذا التي الذي به له فيه بين عند كل اذا ثم قد لم لن'.split())
# a title made of these alone names a place in its own book, not a subject («الحديث السادس والعشرون»)
ORD = set('أول أولى مائة مئة ألف أربعون اول اولي ثاني ثانيه ثالث ثالثه رابع رابعه خامس خامسه سادس سادسه سابع سابعه ثامن ثامنه تاسع تاسعه عاشر عاشره حادي حاديه عشر عشره عشرون ثلاثون اربعون خمسون ستون سبعون ثمانون تسعون مايه مايتان الف بعد واحد واحده اثنان اثنتان'.split())
GENERIC = set('آية آيات مسألة سؤال فتوى فائدة قاعدة أمر حديث ايه ايات درس مجلس جزء مجلد شريط لقاء خطبه وجه دليل قسم نوع امر مقدمه خاتمه فهرس مساله سوال جواب فتوي فايده قاعده تنبيه فصل باب كتاب مقاله رساله وصيه شرط ركن حال مثال فرق طبقه مرتبه درجه صفه قول موضع مطلب مبحث تمهيد ملحق تتمه بقيه تابع'.split())


def stem(x):
    for p in ('وال', 'بال', 'كال', 'فال'):
        if x.startswith(p) and len(x) > 5:
            return x[3:]
    if (x.startswith('ال') or x.startswith('لل')) and len(x) > 4:
        return x[2:]
    return x


def key(title):
    w = norm(title).split()
    while w and (w[0] in LEAD or w[0].isdigit()):
        w = w[1:]
    w = [stem(x) for x in w if x not in STOP]
    w = [x for x in w if len(x) > 1]
    solid = [x for x in w if x not in ORD and x not in GENERIC and stem('ال' + x) not in ORD]
    if len(solid) < 2 or not 2 <= len(w) <= 7:
        return None
    return ' '.join(w)


def main(idx_dir, catalog, out):
    cat = json.load(open(catalog, encoding='utf-8'))
    name = {}
    for s in cat['scholars']:
        for b in s['books']:
            name.setdefault(b['id'], work(b['name']))
    groups = collections.defaultdict(list)
    for f in sorted(glob.glob(os.path.join(idx_dir, '*.gz'))):
        i = int(os.path.basename(f)[:-3])
        if i not in name:
            continue
        j = json.loads(gzip.open(f).read())
        seen = set()
        for n, h in enumerate((j.get('indexes') or j).get('headings', [])):
            k = key(h.get('title') or '')
            if k is None or k in seen:
                continue  # a title repeated inside one book says nothing about other books
            seen.add(k)
            groups[k].append([i, int(h.get('page') or 1), n])
    # only what is found in two different works (the same work in two editions does not count)
    kept = [v for v in groups.values() if len({name[i] for i, _, _ in v}) >= 2 and len(v) <= 40]
    kept.sort(key=lambda v: v[0])
    json.dump({'v': 1, 'groups': kept}, open(out, 'w', encoding='utf-8'), separators=(',', ':'))
    print('groups', len(kept), 'entries', sum(len(v) for v in kept), 'bytes', os.path.getsize(out))
    return groups, kept, name


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else 'assets/data/masail.json')

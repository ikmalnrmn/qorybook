"""Pengumpul katalog Qorybook.

Menggabungkan buku bacaan anak (PAUD - SD) yang disediakan gratis oleh
Kemendikdasmen dari dua sumber:

* SIBI  (buku.kemendikdasmen.go.id) - API JSON publik.
* BUDI  (budi.kemendikdasmen.go.id) - tidak punya API, dibaca dari endpoint
  "load-more" dan halaman detail buku.

Hasilnya satu berkas catalog.json yang diunduh aplikasi. File buku (PDF/audio/
video) TIDAK disalin; aplikasi mengambilnya langsung dari server pemerintah.

Hanya memakai pustaka standar Python supaya mudah dijalankan di GitHub Actions.

Pemakaian:
    python build_catalog.py --out dist/catalog.json [--prev dist/catalog.json]

--prev (berkas atau URL) dipakai ulang supaya halaman detail BUDI yang sudah
pernah dibaca tidak diambil lagi; jumlah dilihat & rating tetap diperbarui
dari daftar.
"""

from __future__ import annotations

import argparse
import concurrent.futures as cf
import datetime as dt
import html
import json
import re
import ssl
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

SCHEMA_VERSION = 1

SIBI_API = "https://api.buku.kemendikdasmen.go.id/api/catalogue"
SIBI_WEB = "https://buku.kemendikdasmen.go.id"
BUDI_WEB = "https://budi.kemendikdasmen.go.id"

# Identitas jujur tanpa menyamar sebagai browser. BUDI menolak User-Agent yang
# mengandung "bot"/"python", jadi kata itu sengaja tidak dipakai.
USER_AGENT = "Qorybook-Katalog/1.0 (pengumpul katalog buku bacaan anak)"

# Jenjang yang disertakan. Kunci internal dipakai aplikasi untuk filter profil.
LEVELS = {
    "paud": "PAUD / TK",
    "sd_awal": "SD Kelas 1-3",
    "sd_tinggi": "SD Kelas 4-6",
}

# Perjenjangan buku Pusat Perbukuan -> jenjang aplikasi.
SIBI_LEVEL_MAP = {
    "A": ["paud"],
    "PAUD": ["paud"],
    "B1": ["sd_awal"],
    "B2": ["sd_awal"],
    "B3": ["sd_awal"],
    "C": ["sd_tinggi"],
}
SIBI_LEVEL_LABEL = {
    "A": "Pembaca Dini",
    "PAUD": "Pembaca Dini",
    "B1": "Pembaca Awal",
    "B2": "Pembaca Awal",
    "B3": "Pembaca Awal",
    "C": "Pembaca Semenjana",
}

BUDI_LEVEL_IDS = {
    "014453da-54e6-41b5-be05-952bc233f144": ("PAUD", ["paud"]),
    "0207580f-6a98-477b-a19f-35bfc0f938e9": ("SD", ["sd_awal", "sd_tinggi"]),
}

# Jenis konten BUDI yang didukung aplikasi. Braille (.brf) tidak bisa
# ditampilkan di layar sehingga dilewati.
BUDI_KINDS = {
    "digital": ("buku", "pdf"),
    "komik": ("komik", "pdf"),
    "audio": ("audio", "audio"),
    "video": ("video", "video"),
}

KIND_LABELS = {
    "buku": "Buku Bergambar",
    "komik": "Komik",
    "audio": "Buku Audio",
    "video": "Buku Video",
}

# SIBI tidak punya tema; tema ditebak dari judul dengan kata kunci sederhana.
THEME_KEYWORDS = [
    ("Hewan dan Tumbuhan", r"kucing|anjing|ayam|bebek|gajah|harimau|kancil|kura|kelinci|burung|ikan|kupu|semut|lebah|monyet|beruang|katak|ular|sapi|kambing|kuda|singa|rusa|badak|komodo|orang ?utan|rangkong|cicak|tikus|domba|bunga|pohon|daun|benih|biji|pisang|kelapa|padi|jamur|tanam|kebun|hewan|binatang"),
    ("Alam dan Lingkungan", r"hutan|sungai|laut|pantai|gunung|hujan|awan|angin|pelangi|sampah|plastik|banjir|air\b|bumi|alam|lingkungan|musim"),
    ("Tata Surya", r"bulan|bintang|matahari|planet|langit|antariksa|roket"),
    ("Cerita Rakyat", r"legenda|hikayat|asal ?usul|dongeng|cerita rakyat|raja|putri|ratu|pangeran|kerajaan"),
    ("Kesehatan", r"sehat|sakit|dokter|gigi|cuci tangan|makan|sayur|buah|tidur|mandi|olahraga"),
    ("Kuliner", r"kue|masak|makanan|nasi|sambal|soto|rendang|resep|jajan"),
    ("Seni dan Budaya", r"tari|batik|wayang|musik|lagu|gamelan|angklung|rumah adat|budaya|layang"),
    ("Pendekatan Sains dalam Kehidupan", r"sains|eksperimen|percobaan|mengapa|bagaimana|robot|mesin|listrik|magnet"),
    ("Petualangan", r"petualang|misteri|jelajah|perjalanan|tersesat|harta"),
]

# Domain lama SIBI sudah tidak aktif; path yang sama dilayani mirror resminya.
HOST_REWRITES = {
    "https://static.buku.kemdikbud.go.id/": "https://static.sc.cloudapp.web.id/",
    "http://static.buku.kemdikbud.go.id/": "https://static.sc.cloudapp.web.id/",
    "https://static-sc.cloudapp.web.id/": "https://static.sc.cloudapp.web.id/",
}

HTTP_TIMEOUT = 45
_SSL = ssl.create_default_context()


def log(msg: str) -> None:
    print(f"[{dt.datetime.now():%H:%M:%S}] {msg}", flush=True)


def fetch(url: str, *, retries: int = 4, accept: str = "*/*") -> bytes:
    """GET dengan retry + jeda eksponensial."""
    last: Exception | None = None
    for attempt in range(retries):
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": accept})
        try:
            with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT, context=_SSL) as r:
                return r.read()
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            last = e
            time.sleep(2 ** attempt)
    raise RuntimeError(f"Gagal mengambil {url}: {last}")


def fetch_json(url: str):
    return json.loads(fetch(url, accept="application/json").decode("utf-8"))


def fix_url(url: str) -> str:
    url = (url or "").strip()
    for old, new in HOST_REWRITES.items():
        if url.startswith(old):
            return new + url[len(old):]
    return url


def is_reachable(url: str) -> bool:
    """Cek file ada dengan meminta 1 byte pertama saja."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Range": "bytes=0-0"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT, context=_SSL) as r:
                return r.status in (200, 206)
        except urllib.error.HTTPError as e:
            if e.code in (403, 404, 410):
                return False
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            pass
        time.sleep(2 ** attempt)
    return False


def clean(text: str | None) -> str:
    if not text:
        return ""
    text = html.unescape(html.unescape(text))  # BUDI kadang meng-escape dua kali
    text = text.replace("\xa0", " ")
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", text).strip().strip('"').strip()
    return "" if text in {"-", "–", "—", ".", "0"} else text


def norm_title(title: str) -> str:
    t = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "", t)


def guess_themes(title: str) -> list[str]:
    t = title.lower()
    return [name for name, pat in THEME_KEYWORDS if re.search(pat, t)][:2]


def split_people(value: str) -> str:
    return re.sub(r"\s*\n\s*", " ", clean(value))


# --------------------------------------------------------------------------
# SIBI
# --------------------------------------------------------------------------

def collect_sibi(workers: int) -> list[dict]:
    log("SIBI: mengambil daftar buku nonteks")
    data = fetch_json(f"{SIBI_API}/getNonTextBooks?limit=5000")
    rows = data.get("results") or []
    books: list[dict] = []
    for x in rows:
        level = (x.get("level") or "").strip()
        attachment = (x.get("attachment") or "").strip()
        if level not in SIBI_LEVEL_MAP:
            continue
        if (x.get("book_type") or "").lower() == "buku_guru":
            continue
        if x.get("status") not in (None, "publish") or x.get("deleted_at"):
            continue
        # Hanya PDF; tautan ke situs lain (mis. letsreadasia.org) bisa
        # membuka jalan keluar dari aplikasi.
        if not attachment.lower().endswith(".pdf"):
            continue
        title = clean(x.get("title"))
        if not title:
            continue
        lang = clean(x.get("language")) or "Indonesia"
        books.append({
            "id": f"sibi-{x['id']}",
            "source": "sibi",
            "title": title,
            "authors": split_people(x.get("writer")),
            "illustrators": split_people(x.get("ilustrator")),
            "publisher": clean(x.get("publisher")),
            "levels": SIBI_LEVEL_MAP[level],
            "readingLevel": level if level != "PAUD" else "A",
            "readingLevelLabel": SIBI_LEVEL_LABEL[level],
            "kind": "buku",
            "format": "pdf",
            "language": lang,
            "themes": guess_themes(title),
            "themesInferred": True,
            "cover": fix_url(x.get("image")),
            "media": fix_url(attachment),
            "pageUrl": f"{SIBI_WEB}/katalog/{x.get('slug')}",
            "pages": None,
            "synopsis": clean(x.get("description")),
            "isbn": clean(x.get("isbn")),
            "rating": None,
            "views": 0,
            "updatedAt": x.get("updated_at") or x.get("created_at"),
        })
    log(f"SIBI: {len(books)} buku lolos filter dari {len(rows)}, memeriksa file PDF")
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        ok = list(ex.map(lambda b: is_reachable(b["media"]), books))
    dead = [b["title"] for b, good in zip(books, ok) if not good]
    if dead:
        log(f"SIBI: {len(dead)} PDF tidak bisa diakses, dilewati (mis. {dead[:3]})")
    books = [b for b, good in zip(books, ok) if good]
    log(f"SIBI: {len(books)} buku siap")
    return books


# --------------------------------------------------------------------------
# BUDI
# --------------------------------------------------------------------------

CARD_RE = re.compile(r'<div class="col-lg-2[^"]*">(.*?)</a>\s*</div>', re.S)


def parse_card(chunk: str) -> dict | None:
    m = re.search(r'href="https://budi\.kemendikdasmen\.go\.id/baca/([a-z]+)/([^"]+)"', chunk)
    if not m:
        return None
    kind, slug = m.group(1), m.group(2)

    def grab(pattern: str) -> str:
        mm = re.search(pattern, chunk, re.S)
        return clean(mm.group(1)) if mm else ""

    try:
        rating = float(grab(r'book-rating">.*?</i>\s*([\d.,]+)').replace(",", "."))
    except ValueError:
        rating = None
    views = re.sub(r"\D", "", grab(r'book-views">.*?</i>\s*([\d.,]+)'))
    return {
        "kind_raw": kind,
        "slug": slug,
        "cover": grab(r'<img\s+src="([^"]+)"'),
        "rating": rating,
        "views": int(views or 0),
        "jenjang": grab(r'book-jenjang">.*?</i>\s*([^<]+)'),
        "title": grab(r'book-title[^>]*>(.*?)</h5>'),
        "authors": grab(r"Penulis:</b><br>(.*?)</p>"),
        "illustrators": grab(r"Ilustrator:</b><br>(.*?)</p>"),
        "theme": grab(r"Tema:</b><br>(.*?)</p>"),
    }


def budi_list(level_id: str, page_size: int = 6, max_pages: int = 1000) -> list[dict]:
    cards: dict[str, dict] = {}
    offset = 0
    for _ in range(max_pages):
        q = urllib.parse.urlencode({"offset": offset, "level": level_id, "theme": "",
                                    "language": "", "tipe": "", "katakunci": ""})
        payload = fetch_json(f"{BUDI_WEB}/buku/load-more?{q}")
        chunk = payload.get("html") or ""
        found = [c for c in (parse_card(p) for p in CARD_RE.findall(chunk)) if c]
        if not found:
            break
        for c in found:
            cards[f"{c['kind_raw']}/{c['slug']}"] = c
        offset += page_size
        time.sleep(0.3)
    return list(cards.values())


def budi_detail(kind_raw: str, slug: str) -> dict:
    url = f"{BUDI_WEB}/baca/{kind_raw}/{slug}"
    page = fetch(url).decode("utf-8", "ignore")
    meta: dict[str, str] = {}
    for label, value in re.findall(r"<tr>\s*<td>([^<]+)</td>\s*<td>:</td>\s*<td>(.*?)</td>\s*</tr>", page, re.S):
        meta[clean(label).lower()] = clean(value)
    media = ""
    # Nama file kadang berisi spasi, jadi hanya kutip yang menjadi batas.
    patterns = {
        "digital": r"/storage/(?:book|content)/[^\"'<>]+?\.pdf",
        "komik": r"/storage/(?:book|content)/[^\"'<>]+?\.pdf",
        "audio": r"/storage/audio/[^\"'<>]+?\.(?:wav|mp3|m4a|ogg|aac)",
        "video": r"/storage/video/[^\"'<>]+?\.(?:mp4|m4v|mov|webm)",
    }
    m = re.search(patterns.get(kind_raw, r"$^"), page, re.I)
    if m:
        media = BUDI_WEB + urllib.parse.quote(html.unescape(m.group(0)), safe="/%")
    syn = re.search(r"Sinopsis</h6>\s*<p[^>]*>(.*?)</p>", page, re.S)
    title = re.search(r'<h4 class="fw-bold mb-1">(.*?)</h4>', page, re.S)
    pages = re.search(r"(\d+)", meta.get("halaman", ""))
    return {
        "title": clean(title.group(1)) if title else "",
        "authors": meta.get("penulis", ""),
        "illustrators": meta.get("ilustrator", ""),
        "jenjang": meta.get("jenjang", ""),
        "pages": int(pages.group(1)) if pages else None,
        "language": meta.get("bahasa", ""),
        "theme": meta.get("tema", ""),
        "synopsis": clean(syn.group(1)) if syn else "",
        "media": media,
        "pageUrl": url,
    }


def load_prev(prev: str | None) -> dict[str, dict]:
    if not prev:
        return {}
    try:
        if re.match(r"https?://", prev):
            data = fetch_json(prev)
        else:
            p = Path(prev)
            if not p.exists():
                return {}
            data = json.loads(p.read_text(encoding="utf-8"))
        return {b["id"]: b for b in data.get("books", []) if b.get("source") == "budi"}
    except Exception as e:  # katalog lama rusak/tidak ada: ambil ulang semuanya
        log(f"Katalog sebelumnya tidak dipakai: {e}")
        return {}


def collect_budi(prev: dict[str, dict], workers: int) -> list[dict]:
    cards: dict[str, tuple[dict, list[str]]] = {}
    for level_id, (label, levels) in BUDI_LEVEL_IDS.items():
        log(f"BUDI: membaca daftar jenjang {label}")
        found = budi_list(level_id)
        log(f"BUDI: {len(found)} judul jenjang {label}")
        for c in found:
            key = f"{c['kind_raw']}/{c['slug']}"
            if key in cards:
                merged = sorted(set(cards[key][1]) | set(levels))
                cards[key] = (cards[key][0], merged)
            else:
                cards[key] = (c, levels)

    wanted = {k: v for k, v in cards.items() if v[0]["kind_raw"] in BUDI_KINDS}
    log(f"BUDI: {len(wanted)} judul didukung (braille dilewati)")

    def book_id(card: dict) -> str:
        return f"budi-{card['kind_raw']}-{card['slug']}"

    todo = [c for c, _ in wanted.values()
            if not (prev.get(book_id(c)) or {}).get("media")]
    log(f"BUDI: {len(todo)} halaman detail perlu diambil ({len(wanted) - len(todo)} dari cache)")

    details: dict[str, dict] = {}

    def work(card: dict):
        time.sleep(0.2)
        return book_id(card), budi_detail(card["kind_raw"], card["slug"])

    failures = 0
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        futures = [ex.submit(work, c) for c in todo]
        for i, fut in enumerate(cf.as_completed(futures), 1):
            try:
                bid, d = fut.result()
                details[bid] = d
            except Exception as e:
                failures += 1
                log(f"  gagal: {e}")
            if i % 100 == 0:
                log(f"  {i}/{len(todo)} detail")
    if failures:
        log(f"BUDI: {failures} halaman detail gagal diambil")

    books: list[dict] = []
    for card, levels in wanted.values():
        bid = book_id(card)
        old = prev.get(bid) or {}
        d = details.get(bid)
        if d is None and not old:
            continue
        kind, fmt = BUDI_KINDS[card["kind_raw"]]
        media = (d or {}).get("media") or old.get("media", "")
        if not media:
            continue
        theme = (d or {}).get("theme") or card["theme"] or ""
        book = {
            "id": bid,
            "source": "budi",
            "title": (d or {}).get("title") or card["title"] or old.get("title", ""),
            "authors": (d or {}).get("authors") or card["authors"] or old.get("authors", ""),
            "illustrators": card["illustrators"] or (d or {}).get("illustrators") or old.get("illustrators", ""),
            "publisher": "Badan Pengembangan dan Pembinaan Bahasa",
            "levels": levels,
            "readingLevel": None,
            "readingLevelLabel": None,
            "kind": kind,
            "format": fmt,
            "language": (d or {}).get("language") or old.get("language") or "Indonesia",
            "themes": [theme] if theme else old.get("themes", []),
            "themesInferred": False,
            "cover": card["cover"] or old.get("cover", ""),
            "media": media,
            "pageUrl": f"{BUDI_WEB}/baca/{card['kind_raw']}/{card['slug']}",
            "pages": (d or {}).get("pages") if d else old.get("pages"),
            "synopsis": (d or {}).get("synopsis") if d else old.get("synopsis", ""),
            "isbn": "",
            "rating": card["rating"],
            "views": card["views"],
            "updatedAt": old.get("updatedAt") or dt.date.today().isoformat(),
        }
        if book["title"]:
            books.append(book)
    log(f"BUDI: {len(books)} buku siap")
    return books


# --------------------------------------------------------------------------
# Gabung
# --------------------------------------------------------------------------

def merge(sibi: list[dict], budi: list[dict]) -> list[dict]:
    """Buang judul ganda. BUDI diutamakan karena punya sinopsis & data dilihat."""
    out: dict[str, dict] = {}
    for b in budi + sibi:
        key = norm_title(b["title"]) + "|" + b["format"]
        if key in out:
            kept = out[key]
            kept["levels"] = sorted(set(kept["levels"]) | set(b["levels"]),
                                    key=list(LEVELS).index)
            if not kept.get("readingLevel") and b.get("readingLevel"):
                kept["readingLevel"] = b["readingLevel"]
                kept["readingLevelLabel"] = b["readingLevelLabel"]
            continue
        out[key] = b
    return sorted(out.values(), key=lambda b: (-b["views"], b["title"].lower()))


def build(prev: str | None, workers: int) -> dict:
    sibi = collect_sibi(workers)
    budi = collect_budi(load_prev(prev), workers)
    books = merge(sibi, budi)

    themes: dict[str, int] = {}
    for b in books:
        for t in b["themes"]:
            themes[t] = themes.get(t, 0) + 1
    languages: dict[str, int] = {}
    for b in books:
        languages[b["language"]] = languages.get(b["language"], 0) + 1

    return {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "sources": [
            {"id": "sibi", "name": "SIBI - Sistem Informasi Perbukuan Indonesia", "url": SIBI_WEB},
            {"id": "budi", "name": "BUDI - Buku Digital, Gerakan Literasi Nasional", "url": BUDI_WEB},
        ],
        "taxonomy": {
            "levels": [{"id": k, "label": v} for k, v in LEVELS.items()],
            "kinds": [{"id": k, "label": v} for k, v in KIND_LABELS.items()],
            "themes": [{"id": t, "label": t, "count": n}
                       for t, n in sorted(themes.items(), key=lambda kv: -kv[1])],
            "languages": [{"id": l, "label": l, "count": n}
                          for l, n in sorted(languages.items(), key=lambda kv: -kv[1])],
        },
        "counts": {
            "total": len(books),
            "sibi": sum(b["source"] == "sibi" for b in books),
            "budi": sum(b["source"] == "budi" for b in books),
        },
        "books": books,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="dist/catalog.json")
    ap.add_argument("--prev", help="catalog.json sebelumnya (path atau URL)")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--min-books", type=int, default=300,
                    help="gagal jika hasil lebih sedikit (melindungi dari situs yang berubah)")
    args = ap.parse_args()

    catalog = build(args.prev, args.workers)
    total = catalog["counts"]["total"]
    if total < args.min_books:
        log(f"Hanya {total} buku (< {args.min_books}). Katalog TIDAK ditulis.")
        return 1

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    log(f"Selesai: {total} buku -> {out} ({out.stat().st_size / 1024:.0f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
Mempublikasikan kamus (CSV) ke Firestore dalam bentuk paket, untuk dibaca
aplikasi lewat SyncedDictionaryRepository.

Tata letak di Firestore:
    dictionary_meta/current             { version, packCount, entryCount, updatedAt }
    dictionary_packs/{version}_{000..}  { version, index, entries: [ {id,h,d,p,c,s}, ... ] }

Satu pemasangan aplikasi baru hanya membaca packCount + 1 dokumen (sekitar 11),
bukan 14 ribu dokumen satu per satu.

Pemakaian:
    python tools/publish_dictionary.py --csv assets/data/dict_entries.csv --dry-run
    python tools/publish_dictionary.py --csv assets/data/dict_entries.csv --key serviceAccountKey.json

Memperbarui kamus: ubah CSV, jalankan ulang skrip ini. Versi baru dipakai
aplikasi pada pembukaan berikutnya. Paket diunggah dulu, meta terakhir, sehingga
aplikasi tidak pernah membaca versi yang setengah jadi.
"""
import argparse
import csv
import json
import sys
import time

META_COLLECTION = "dictionary_meta"
META_DOC = "current"
PACK_COLLECTION = "dictionary_packs"
MAX_PACK_BYTES = 400_000  # batas dokumen Firestore 1 MiB; ini memberi ruang aman


def load_entries(path):
    """Membaca CSV dengan modul csv (bukan pandas: kata 'nan' harus tetap 'nan')."""
    entries, skipped = [], 0
    with open(path, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            if (row.get("deletedAt") or "").strip():
                continue  # entri yang dihapus (soft delete) tidak dipublikasikan
            entry = {
                "id": (row.get("id") or "").strip(),
                "h": (row.get("headword") or "").strip(),
                "d": (row.get("definitions") or "").strip(),
                "p": (row.get("partOfSpeech") or "").strip(),
            }
            category = (row.get("semanticCategories") or "").strip()
            dialect = (row.get("sourceDialect") or "").strip()
            if category:
                entry["c"] = category
            if dialect:
                entry["s"] = dialect
            if not (entry["id"] and entry["h"] and entry["d"]):
                skipped += 1
                continue
            entries.append(entry)
    return entries, skipped


def split_packs(entries, max_bytes=MAX_PACK_BYTES):
    packs, current, size = [], [], 0
    for entry in entries:
        entry_bytes = len(json.dumps(entry, ensure_ascii=False).encode("utf-8")) + 2
        if current and size + entry_bytes > max_bytes:
            packs.append(current)
            current, size = [], 0
        current.append(entry)
        size += entry_bytes
    if current:
        packs.append(current)
    return packs


def pack_id(version, index):
    return f"{version}_{index:03d}"  # harus sama dengan FirestoreDictionarySource.packId


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="assets/data/dict_entries.csv")
    ap.add_argument("--key", help="Path service account JSON (atau set GOOGLE_APPLICATION_CREDENTIALS)")
    ap.add_argument("--version", type=int, help="Nomor versi (default: waktu sekarang dalam detik)")
    ap.add_argument("--dry-run", action="store_true", help="Hanya hitung dan tampilkan ringkasan")
    args = ap.parse_args()

    entries, skipped = load_entries(args.csv)
    if not entries:
        sys.exit("Tidak ada entri yang bisa dipublikasikan.")
    packs = split_packs(entries)
    version = args.version or int(time.time())

    print(f"Entri: {len(entries)} (dilewati karena tidak lengkap: {skipped})")
    print(f"Paket: {len(packs)}, ukuran terbesar ~{max(len(json.dumps(p, ensure_ascii=False).encode()) for p in packs) // 1000} KB")
    print(f"Versi: {version}")
    print(f"Baca per pemasangan baru: {len(packs) + 1} dokumen")
    if args.dry_run:
        print("Dry-run selesai, tidak ada yang ditulis.")
        return

    import firebase_admin
    from firebase_admin import credentials, firestore

    cred = credentials.Certificate(args.key) if args.key else credentials.ApplicationDefault()
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    # 1) paket dulu (id memuat versi, jadi tidak menimpa versi yang sedang dipakai)
    for index, pack in enumerate(packs):
        db.collection(PACK_COLLECTION).document(pack_id(version, index)).set(
            {"version": version, "index": index, "entries": pack}
        )
        print(f"  paket {index + 1}/{len(packs)} terunggah")

    # 2) meta terakhir: inilah yang "menyalakan" versi baru
    db.collection(META_COLLECTION).document(META_DOC).set(
        {
            "version": version,
            "packCount": len(packs),
            "entryCount": len(entries),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
    )

    # 3) bersihkan paket versi lama
    prefix = f"{version}_"
    removed = 0
    for ref in db.collection(PACK_COLLECTION).list_documents():
        if not ref.id.startswith(prefix):
            ref.delete()
            removed += 1
    print(f"Selesai. Versi {version} aktif. Paket lama dihapus: {removed}")


if __name__ == "__main__":
    main()

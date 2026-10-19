#!/usr/bin/env python3
"""
Mempublikasikan soal kuis (CSV) ke Firestore.

Format CSV (satu soal per baris):
    kata_bahasa_batak, jawaban_bahasa_indonesia, opsi_salah_1, opsi_salah_2, opsi_salah_3

Tata letak di Firestore (sama polanya dengan kamus):
    quiz_meta/current             { version, packCount, questionCount, updatedAt }
    quiz_packs/{version}_{000..}  { version, index, questions: [ {id, word, answer, wrong:[3]} ] }

Pemakaian:
    python tools/publish_quiz.py --csv database_bahasa_batak.csv --dry-run
    python tools/publish_quiz.py --csv database_bahasa_batak.csv --dictionary assets/data/dict_entries.csv --dry-run
    python tools/publish_quiz.py --csv database_bahasa_batak.csv --key serviceAccountKey.json

Memperbarui soal: ubah CSV, jalankan ulang. Paket diunggah dulu, meta terakhir,
jadi aplikasi tidak pernah membaca versi yang setengah jadi.
"""
import argparse
import csv
import hashlib
import json
import re
import sys
import time

META_COLLECTION = "quiz_meta"
META_DOC = "current"
PACK_COLLECTION = "quiz_packs"
MAX_PACK_BYTES = 400_000  # batas dokumen Firestore 1 MiB; ini memberi ruang aman

WORD_COL = "kata_bahasa_batak"
ANSWER_COL = "jawaban_bahasa_indonesia"
WRONG_COLS = ["opsi_salah_1", "opsi_salah_2", "opsi_salah_3"]


def clean(value):
    return (value or "").strip()


def question_id(word, answer):
    """ID stabil dari isi soal: tidak berubah walau urutan baris di CSV berubah."""
    return hashlib.sha1(f"{word.lower()}|{answer.lower()}".encode("utf-8")).hexdigest()[:10]


def load_questions(path, keep_case=False):
    """Mengembalikan (soal, kesalahan, catatan). Kesalahan menghentikan publikasi."""
    errors, notes, questions = [], [], []
    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        missing = [c for c in [WORD_COL, ANSWER_COL, *WRONG_COLS] if c not in (reader.fieldnames or [])]
        if missing:
            return [], [f"kolom tidak ditemukan di CSV: {', '.join(missing)}"], []
        seen = {}
        for line, row in enumerate(reader, start=2):
            word, answer = clean(row[WORD_COL]), clean(row[ANSWER_COL])
            wrong = [clean(row[c]) for c in WRONG_COLS]
            if not word or not answer or not all(wrong):
                errors.append(f"baris {line}: ada kolom yang kosong")
                continue
            if answer.lower() in (w.lower() for w in wrong):
                errors.append(f"baris {line} ({word}): salah satu opsi salah sama dengan jawaban benar")
                continue
            if len({w.lower() for w in wrong}) < len(wrong):
                errors.append(f"baris {line} ({word}): opsi salah ada yang kembar")
                continue
            if not keep_case and word != word.lower():
                notes.append(f"baris {line}: kata '{word}' diubah menjadi huruf kecil '{word.lower()}'")
                word = word.lower()
            key = (word.lower(), answer.lower())
            if key in seen:
                notes.append(f"baris {line}: soal '{word}' = '{answer}' sudah ada di baris {seen[key]}, dilewati")
                continue
            seen[key] = line
            questions.append({"id": question_id(word, answer), "word": word, "answer": answer, "wrong": wrong})

    by_word = {}
    for q in questions:
        by_word.setdefault(q["word"].lower(), set()).add(q["answer"].lower())
    for word, answers in by_word.items():
        if len(answers) > 1:
            notes.append(f"kata '{word}' punya beberapa jawaban berbeda: {sorted(answers)}")
    return questions, errors, notes


def check_against_dictionary(questions, dictionary_csv):
    """Peringatan saja (tidak menghentikan publikasi): cocokkan soal dengan kamus."""
    by_word = {}
    with open(dictionary_csv, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            if clean(row.get("deletedAt")):
                continue
            by_word.setdefault(clean(row["headword"]).lower(), []).append(clean(row["definitions"]))
    absent, mismatch = [], []
    for q in questions:
        definitions = by_word.get(q["word"].lower())
        if not definitions:
            absent.append(q["word"])
        elif not re.search(r"\b" + re.escape(q["answer"].lower()) + r"\b", " ".join(definitions).lower()):
            mismatch.append((q["word"], q["answer"], definitions[0][:60]))
    return absent, mismatch


def split_packs(questions, max_bytes=MAX_PACK_BYTES):
    packs, current, size = [], [], 0
    for q in questions:
        q_bytes = len(json.dumps(q, ensure_ascii=False).encode("utf-8")) + 2
        if current and size + q_bytes > max_bytes:
            packs.append(current)
            current, size = [], 0
        current.append(q)
        size += q_bytes
    if current:
        packs.append(current)
    return packs


def pack_id(version, index):
    return f"{version}_{index:03d}"


def publish(db, packs, question_count, version, server_timestamp):
    """Urutan penting: paket dulu, meta terakhir ("menyalakan" versi baru), lalu bersih-bersih."""
    for index, pack in enumerate(packs):
        db.collection(PACK_COLLECTION).document(pack_id(version, index)).set(
            {"version": version, "index": index, "questions": pack}
        )
        print(f"  paket {index + 1}/{len(packs)} terunggah")
    db.collection(META_COLLECTION).document(META_DOC).set(
        {
            "version": version,
            "packCount": len(packs),
            "questionCount": question_count,
            "updatedAt": server_timestamp,
        }
    )
    removed = 0
    for ref in db.collection(PACK_COLLECTION).list_documents():
        if not ref.id.startswith(f"{version}_"):
            ref.delete()
            removed += 1
    return removed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default="database_bahasa_batak.csv")
    ap.add_argument("--dictionary", help="CSV kamus (opsional) untuk mencocokkan jawaban; hanya memberi peringatan")
    ap.add_argument("--key", help="Path service account JSON (atau set GOOGLE_APPLICATION_CREDENTIALS)")
    ap.add_argument("--version", type=int, help="Nomor versi (default: waktu sekarang dalam detik)")
    ap.add_argument("--keep-case", action="store_true", help="Jangan ubah kata Batak menjadi huruf kecil")
    ap.add_argument("--dry-run", action="store_true", help="Hanya periksa dan tampilkan ringkasan")
    args = ap.parse_args()

    questions, errors, notes = load_questions(args.csv, keep_case=args.keep_case)
    for note in notes:
        print("catatan:", note)
    if args.dictionary and questions:
        absent, mismatch = check_against_dictionary(questions, args.dictionary)
        if absent:
            print(f"\nPERINGATAN: {len(absent)} kata tidak ada di kamus (mungkin beda ejaan): {', '.join(absent)}")
        if mismatch:
            print(f"\nPERINGATAN: {len(mismatch)} jawaban tidak ditemukan di arti kamus, mohon dicek manual:")
            for word, answer, definition in mismatch:
                print(f"  {word:14} jawaban={answer:12} kamus: {definition}")
    if errors:
        print("\nKESALAHAN (publikasi dibatalkan):")
        for error in errors:
            print("  -", error)
        sys.exit(1)
    if not questions:
        sys.exit("Tidak ada soal yang bisa dipublikasikan.")

    packs = split_packs(questions)
    version = args.version or int(time.time())
    print(f"\nSoal: {len(questions)} | paket: {len(packs)} | versi: {version}")
    print(f"Baca per pemasangan baru: {len(packs) + 1} dokumen")
    if args.dry_run:
        print("Dry-run selesai, tidak ada yang ditulis.")
        return

    import firebase_admin
    from firebase_admin import credentials, firestore

    cred = credentials.Certificate(args.key) if args.key else credentials.ApplicationDefault()
    firebase_admin.initialize_app(cred)
    removed = publish(firestore.client(), packs, len(questions), version, firestore.SERVER_TIMESTAMP)
    print(f"Selesai. Versi {version} aktif. Paket lama dihapus: {removed}")


if __name__ == "__main__":
    main()

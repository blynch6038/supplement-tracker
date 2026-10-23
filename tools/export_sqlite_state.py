#!/usr/bin/env python3
"""Export V4.2 state JSON from an OFFLINE COPY of your Synology SQLite database.
Never commit the generated JSON to GitHub (it contains personal health history).
"""
import sqlite3,json,sys,pathlib
if len(sys.argv)!=3:
  raise SystemExit('Usage: python3 export_sqlite_state.py path/to/ledger.sqlite3 path/to/state-backup.json')
src=pathlib.Path(sys.argv[1]);dst=pathlib.Path(sys.argv[2]);
if not src.is_file():raise SystemExit('SQLite source not found')
with sqlite3.connect(f'file:{src.resolve()}?mode=ro',uri=True) as con:
 row=con.execute('SELECT payload FROM state WHERE id=1').fetchone()
if not row:raise SystemExit('No tracker state in this database')
payload=json.loads(row[0]);
if not isinstance(payload.get('supplements'),list) or not isinstance(payload.get('logs'),dict):raise SystemExit('Invalid tracker state')
payload.setdefault('snapshots',{});payload.setdefault('favorites',[]);payload.setdefault('routines',[])
dst.write_text(json.dumps(payload,ensure_ascii=False,indent=2));
print(f'Exported {len(payload["supplements"])} products and {len(payload["logs"])} history dates to {dst} (KEEP PRIVATE)')

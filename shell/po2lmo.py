#!/usr/bin/env python3
"""po -> LuCI lmo converter (pure python).

Compatible with luci's po2lmo.c output format, so the result can be dropped into
/usr/lib/lua/luci/i18n/<domain>.<lang>.lmo.

用法: python3 shell/po2lmo.py input.po output.lmo
"""
import struct
import sys


def sfh_hash(data: bytes) -> int:
    """Paul Hsieh's SuperFastHash, as used by luci (sfh_hash)."""
    ln = len(data)
    if ln <= 0:
        return 0

    def get16(d, o):
        return d[o] | (d[o + 1] << 8)

    hashv = ln
    rem = ln & 3
    n = ln >> 2
    i = 0
    for _ in range(n):
        hashv = (hashv + get16(data, i)) & 0xFFFFFFFF
        tmp = ((get16(data, i + 2) << 11) ^ hashv) & 0xFFFFFFFF
        hashv = ((hashv << 16) ^ tmp) & 0xFFFFFFFF
        i += 4
        hashv = (hashv + (hashv >> 11)) & 0xFFFFFFFF
    if rem == 3:
        hashv = (hashv + get16(data, i)) & 0xFFFFFFFF
        hashv ^= (hashv << 16) & 0xFFFFFFFF
        sc = data[i + 2]
        sc = sc - 256 if sc >= 128 else sc
        hashv ^= (sc << 18) & 0xFFFFFFFF
        hashv = (hashv + (hashv >> 11)) & 0xFFFFFFFF
    elif rem == 2:
        hashv = (hashv + get16(data, i)) & 0xFFFFFFFF
        hashv ^= (hashv << 11) & 0xFFFFFFFF
        hashv = (hashv + (hashv >> 17)) & 0xFFFFFFFF
    elif rem == 1:
        sc = data[i]
        sc = sc - 256 if sc >= 128 else sc
        hashv = (hashv + sc) & 0xFFFFFFFF
        hashv ^= (hashv << 10) & 0xFFFFFFFF
        hashv = (hashv + (hashv >> 1)) & 0xFFFFFFFF
    hashv ^= (hashv << 3) & 0xFFFFFFFF
    hashv = (hashv + (hashv >> 5)) & 0xFFFFFFFF
    hashv ^= (hashv << 4) & 0xFFFFFFFF
    hashv = (hashv + (hashv >> 17)) & 0xFFFFFFFF
    hashv ^= (hashv << 25) & 0xFFFFFFFF
    hashv = (hashv + (hashv >> 6)) & 0xFFFFFFFF
    return hashv & 0xFFFFFFFF


def _unescape(s: str) -> str:
    out = []
    i = 0
    table = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\"}
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            out.append(table.get(s[i + 1], s[i + 1]))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def parse_po(text: str):
    """Return a list of (msgid, msgstr) in file order (header skipped)."""
    entries = []
    cur = None  # 'id' | 'str'
    buf = {"id": "", "str": ""}
    have = False

    def flush():
        nonlocal buf, have
        if have and buf["id"]:
            entries.append((buf["id"], buf["str"]))
        buf = {"id": "", "str": ""}
        have = False

    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("msgid "):
            flush()
            buf["id"] = _unescape(line[6:].strip()[1:-1])
            cur = "id"
            have = True
        elif line.startswith("msgstr "):
            buf["str"] = _unescape(line[7:].strip()[1:-1])
            cur = "str"
        elif line.startswith("msgid_plural ") or line.startswith("msgstr["):
            # plural forms are not needed for these LuCI apps; skip value
            cur = None
        elif line.startswith('"'):
            if cur:
                buf[cur] += _unescape(line[1:-1])
    flush()
    return entries


def build_lmo(entries) -> bytes:
    blob = bytearray()
    index = []
    for msgid, msgstr in entries:
        if not msgid or not msgstr:
            continue
        kb = msgid.encode("utf-8")
        vb = msgstr.encode("utf-8")
        key_id = sfh_hash(kb)
        val_id = sfh_hash(vb)
        if key_id == val_id:
            continue
        offset = len(blob)
        blob += vb
        blob += b"\x00" * ((4 - (len(vb) % 4)) % 4)
        index.append((key_id, 1, offset, len(vb)))
    index.sort(key=lambda e: e[0])
    out = bytearray(blob)
    for key_id, val_id, offset, length in index:
        out += struct.pack(">IIII", key_id, val_id, offset, length)
    out += struct.pack(">I", len(blob))
    return bytes(out)


def main(argv):
    if len(argv) != 3:
        sys.stderr.write("用法: %s input.po output.lmo\n" % argv[0])
        return 1
    with open(argv[1], "r", encoding="utf-8") as f:
        entries = parse_po(f.read())
    data = build_lmo(entries)
    with open(argv[2], "wb") as f:
        f.write(data)
    sys.stderr.write("已生成 %s (%d 条)\n" % (argv[2], len(entries)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

import time
from wonder_fetch import build2, send, TEN55
Q = [("all_cvd", "V2", "I00-I99"), ("heart_disease", "V4", "GR113-054")]
def grp55(db, ucd, code):
    x = build2(db, ucd, code, "val55")  # ten-year groups <1..45-54, WONDER age-adjusted rate
    return x
def grp55_byage(db, ucd, code):
    x = build2(db, ucd, code, "val55")
    x = x.replace("<name>B_3</name><value>*None*</value>", f"<name>B_3</name><value>{db}.V5</value>")
    x = x.replace("<name>O_aar</name><value>aar_std</value>", "<name>O_aar</name><value>aar_none</value>")
    x = x.replace(f"<parameter><name>M_41</name><value>{db}.M41</value></parameter>", "")
    x = x.replace(f"<parameter><name>M_42</name><value>{db}.M42</value></parameter>", "")
    return x
for c, u, k in Q:
    for db in ("D76", "D158"):
        for m, f in (("aar55", grp55), ("byage55", grp55_byage)):
            tag = f"{c}_{db}_{m}"; xml = f(db, u, k)
            open(f"raw/{tag}_request.xml", "w").write(xml)
            x = send(db, xml); open(f"raw/{tag}_response.xml", "w").write(x)
            print(tag, "ERROR " + x[:300] if x.startswith("HTTPERROR") else "ok", flush=True)
            time.sleep(16)

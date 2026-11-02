"""Query CDC WONDER Underlying Cause of Death (D76 2013-2017, D158 2018-2024) for women's
age-adjusted CVD and heart-disease death rates, optionally restricted to ages <60
(five-year age groups <1 through 55-59). Mirrors the request built by R/01b_mortality.R."""
import sys, re, time, json, urllib.parse, urllib.request
AGES60 = ["1", "1-4", "5-9", "10-14", "15-19", "20-24", "25-29", "30-34", "35-39", "40-44", "45-49", "50-54", "55-59"]
def build(db, ucd, code, ages=None):
    V = lambda v: f"{db}.{v}"
    p = {"B_1": V("V1-level1"), "B_2": V("V7"), "B_3": "*None*", "B_4": "*None*", "B_5": "*None*",
         "M_1": V("M1"), "M_2": V("M2"), "M_3": V("M3"), "M_41": V("M41"), "M_42": V("M42"),
         "O_aar": "aar_std", "O_aar_pop": "0000", "O_age": V("V51") if ages else V("V5"), "O_javascript": "on",
         "O_location": V("V9"), "O_precision": "1", "O_rate_per": "100000", "O_show_totals": "false",
         "O_timeout": "600", "O_title": "", "O_ucd": V(ucd), "O_urban": V("V19"),
         "action-Send": "Send", "stage": "request"}
    for v in ["V1", "V10", "V27", "V9"]:
        p[f"F_{V(v)}"] = "*All*"; p[f"O_{v}_fmode"] = "freg"; p[f"V_{V(v)}"] = ""
        if v != "V10": p[f"finder-stage-{V(v)}"] = "codeset"
    p[f"F_{V('V2')}"] = code if ucd == "V2" else "*All*"; p["O_V2_fmode"] = "freg"
    p[f"V_{V('V2')}"] = ""; p[f"finder-stage-{V('V2')}"] = "codeset"
    p[f"I_{V('V1')}"] = "*All* (All Dates)"
    for v in ["V10", "V27", "V9"]: p[f"I_{V(v)}"] = "*All* (The United States)"
    p[f"I_{V('V2')}"] = code if ucd == "V2" else "*All* (All Causes of Death)"
    for v in ["V11", "V12", "V17", "V19", "V20", "V21", "V22", "V23", "V24", "V25", "V5", "V51", "V52", "V7"]:
        p[f"V_{V(v)}"] = "*All*"
    if ages: p[f"V_{V('V51')}"] = ages
    p[f"V_{V('V4')}"] = code if ucd == "V4" else "*All*"; p[f"V_{V('V6')}"] = "00"
    for v in ["V10", "V17", "V1_S", "V7"]: p[f"VM_{V('M6')}_{V(v)}"] = "*All*"
    p[f"VM_{V('M6')}_{V('V10')}"] = ""
    if db == "D76": p[f"V_{V('V8')}"] = "*All*"; p[f"VM_{V('M6')}_{V('V8')}"] = "*All*"
    if db == "D158":
        for v in ["V42", "V43", "V44", "V45", "V18"]: p[f"V_{V(v)}"] = "*All*"
        for v in ["V25", "V30", "V31"]:
            p[f"F_{V(v)}"] = "*All*"; p[f"O_{v}_fmode"] = "freg"; p[f"V_{V(v)}"] = ""
        p["O_race"] = V("V42"); p[f"VM_{V('M6')}_{V('V42')}"] = "*All*"
    def vals(x): return "".join(f"<value>{i}</value>" for i in (x if isinstance(x, list) else [x]))
    return "<request-parameters>" + "".join(f"<parameter><name>{k}</name>{vals(v)}</parameter>" for k, v in p.items()) + "</request-parameters>"
def fetch(db, ucd, code, ages=None):
    xml = build(db, ucd, code, ages)
    body = urllib.parse.urlencode({"request_xml": xml, "accept_datause_restrictions": "true"}).encode()
    req = urllib.request.Request(f"https://wonder.cdc.gov/controller/datarequest/{db}", data=body,
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    x = urllib.request.urlopen(req, timeout=600).read().decode("utf-8")
    return xml, x
def parse(x):
    out = []; yr = None
    for r in re.findall(r"<r>.*?</r>", x, re.S):
        cell = [c.strip() for c in re.findall(r'<c (?:l|v)="([^"]*)', r)]
        if re.fullmatch(r"\d{4}", cell[0]): yr = int(cell[0]); cell = cell[1:]
        out.append(dict(year=yr, sex=cell[0], deaths=cell[1], population=cell[2], crude=cell[3], aar=cell[4]))
    return out
if __name__ == "__main__":
    db, ucd, code, mode, tag = sys.argv[1:6]
    xml, x = fetch(db, ucd, code, AGES60 if mode == "u60" else None)
    open(f"raw/{tag}_request.xml", "w").write(xml); open(f"raw/{tag}_response.xml", "w").write(x)
    rows = parse(x); print(json.dumps([r for r in rows if r["sex"] == "Female"]))
    if not rows: print(x[:3000])

TEN55 = ["1", "1-4", "5-14", "15-24", "25-34", "35-44", "45-54"]
def build2(db, ucd, code, mode):
    """mode 'grp60': group by Year, Sex, five-year age group (<1..55-59); deaths/population/crude only.
       mode 'val55': ten-year groups <1..45-54, WONDER's own age-adjusted rate (validation)."""
    x = build(db, ucd, code, None)
    if mode == "grp60":
        x = x.replace(f"<name>B_3</name><value>*None*</value>", f"<name>B_3</name><value>{db}.V51</value>")
        x = x.replace(f"<name>O_age</name><value>{db}.V5</value>", f"<name>O_age</name><value>{db}.V51</value>")
        x = x.replace(f"<name>V_{db}.V51</name><value>*All*</value>", f"<name>V_{db}.V51</name>" + "".join(f"<value>{a}</value>" for a in AGES60))
        x = x.replace(f"<parameter><name>M_41</name><value>{db}.M41</value></parameter>", "")
        x = x.replace(f"<parameter><name>M_42</name><value>{db}.M42</value></parameter>", "")
        x = x.replace("<name>O_aar</name><value>aar_std</value>", "<name>O_aar</name><value>aar_none</value>")
    elif mode == "val55":
        x = x.replace(f"<name>V_{db}.V5</name><value>*All*</value>", f"<name>V_{db}.V5</name>" + "".join(f"<value>{a}</value>" for a in TEN55))
    return x
def send(db, xml):
    body = urllib.parse.urlencode({"request_xml": xml, "accept_datause_restrictions": "true"}).encode()
    req = urllib.request.Request(f"https://wonder.cdc.gov/controller/datarequest/{db}", data=body,
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    try: return urllib.request.urlopen(req, timeout=600).read().decode("utf-8")
    except urllib.error.HTTPError as e: return "HTTPERROR " + e.read().decode()
def parse_grp(x):
    out = []; yr = sex = None
    for r in re.findall(r"<r>.*?</r>", x, re.S):
        labs = [c.strip() for c in re.findall(r'<c l="([^"]*)', r)]
        vals = [c.strip() for c in re.findall(r'<c v="([^"]*)', r)]
        for l in labs:
            if re.fullmatch(r"\d{4}", l): yr = int(l)
            elif l in ("Female", "Male"): sex = l
            else: age = l
        out.append(dict(year=yr, sex=sex, age=age, deaths=vals[0], population=vals[1], crude=vals[2]))
    return out

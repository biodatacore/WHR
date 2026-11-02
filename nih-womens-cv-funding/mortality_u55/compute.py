"""Women aged <55: WONDER's own age-adjusted rates (2000 U.S. standard, ten-year age groups <1 to 45-54),
plus death counts/populations by ten-year group and an independent direct-standardization check."""
import csv
from wonder_fetch import parse, parse_grp
STD10 = {"< 1 year": 3794901, "1-4 years": 15191619, "5-14 years": 19919840 + 20056779, "15-24 years": 19819518 + 18257225,
         "25-34 years": 17722067 + 19511370, "35-44 years": 22179956 + 22479229, "45-54 years": 19805793 + 17224359}
num = lambda s: float(s.replace(",", ""))
ICD = {"all_cvd": "I00-I99", "heart_disease": "I00-I09,I11,I13,I20-I51"}
rows, cells = [], []
for c in ICD:
    for db, yrs in (("D76", range(2013, 2018)), ("D158", range(2018, 2025))):
        A = {r["year"]: r for r in parse(open(f"raw/{c}_{db}_aar55_response.xml").read()) if r["sex"] == "Female"}
        G = [g for g in parse_grp(open(f"raw/{c}_{db}_byage55_response.xml").read().replace("&lt;", "<")) if g["sex"] == "Female"]
        for y in yrs:
            g = {x["age"]: x for x in G if x["year"] == y}; assert set(g) == set(STD10), (c, y, set(g) ^ set(STD10))
            W = sum(STD10.values())
            mine = sum(STD10[a] / W * num(g[a]["deaths"]) / num(g[a]["population"]) for a in STD10) * 1e5
            for a in STD10: cells.append(dict(year=y, cause=c, database=db, age_group=a, deaths=int(num(g[a]["deaths"])), population=int(num(g[a]["population"])), std_pop_2000=STD10[a]))
            r = A[y]
            rows.append(dict(year=y, sex="Female", ages="<55 (<1 to 45-54)", cause=c, icd10=ICD[c], age_adjusted_rate_per_100k=num(r["aar"]),
                             computed_check_unrounded=round(mine, 4), diff_check=round(round(mine, 1) - num(r["aar"]), 1),
                             deaths=int(num(r["deaths"])), population=int(num(r["population"])), crude_rate_per_100k=num(r["crude"]),
                             database=db, standard_population="2000 U.S. standard (WONDER, ten-year groups <1 to 45-54)", status="final"))
for fn, R in (("women_u55_mortality_2013_2024.csv", rows), ("women_u55_counts_by_age_2013_2024.csv", cells)):
    with open(fn, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(R[0])); w.writeheader(); w.writerows(R)
for r in rows: print(r["cause"], r["year"], r["age_adjusted_rate_per_100k"], r["computed_check_unrounded"], r["diff_check"], r["deaths"])

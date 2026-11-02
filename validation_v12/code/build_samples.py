"""v12 out-of-sample validation samples for v11c rules. Run from validation_v12/: python3 work/build.py
Step 1 (sample) writes work/need.csv; then Rscript work/text.R; then rerun to write workbooks."""
import pandas as pd, numpy as np, os, sys
SEED=20261102
X=pd.read_csv('work/frame.csv.gz',dtype={'FULL_PROJECT_NUM':str,'CORE_PROJECT_NUM':str})
prior=set(open('work/prior_core_all.txt').read().split())
n0=len(X); X=X[~X.CORE_PROJECT_NUM.isin(prior)].copy()
print(f'frame project-years {n0:,}; after excluding {len(prior)} prior cores: {len(X):,}')
X['band']=np.where(X.FY<=2018,'FY2013-2018','FY2019-2025')
X['cvwhr']=X.t3&X.cv
X['C_label']=np.where(~X.cv,'CV no',np.where(X.cvwhr,'CV yes, CV-WHR yes','CV yes, CV-WHR no'))
X['W_label']=np.where(X.t3,'WHR yes','WHR no')
X['C_stratum']=X.C_label+' | '+X.band; X['W_stratum']=X.W_label+' | '+X.band
def alloc(lab_col,str_col,targets):
    n={}
    for lab,t in targets.items():
        pop=X[X[lab_col]==lab][str_col].value_counts().sort_index()
        a=np.floor(t*pop/pop.sum()).astype(int)
        while a.sum()<t: a[(t*pop/pop.sum()-a).idxmax()]+=1
        n.update(a.to_dict())
    return n
rng=np.random.default_rng(SEED); used=set()
def draw(col,n):
    out=[]
    for k,m in sorted(n.items()):
        g=X[X[col]==k]; idx=rng.permutation(len(g)); take=[]
        for i in idx:  # SRS of project-years; skip a core already drawn (keeps each grant once across both sets)
            c=g.CORE_PROJECT_NUM.iat[i]
            if c in used: continue
            used.add(c); take.append(i)
            if len(take)==m: break
        s=g.iloc[take].copy(); s['N_h']=len(g); s['n_h']=m; s['weight']=len(g)/m
        s['N_h_usd']=g.USD.sum(); out.append(s)
    return pd.concat(out)
C=draw('C_stratum',alloc('C_label','C_stratum',{'CV yes, CV-WHR yes':100,'CV yes, CV-WHR no':60,'CV no':40}))
W=draw('W_stratum',alloc('W_label','W_stratum',{'WHR yes':100,'WHR no':100}))
C['Set']='C'; W['Set']='W'
S=pd.concat([C,W]); S.to_csv('work/sample_draw.csv',index=False)
S[['FY','FULL_PROJECT_NUM']].to_csv('work/need.csv',index=False)
def strata(df,col):
    return df.groupby(col).agg(N_h=('N_h','first'),n_h=('n_h','first'),weight=('weight','first'),USD_h=('N_h_usd','first')).reset_index().assign(fraction=lambda d:d.n_h/d.N_h)
gc,gw=strata(C,'C_stratum'),strata(W,'W_stratum')
pd.concat([gc.rename(columns={'C_stratum':'Stratum'}).assign(Set='CV'),gw.rename(columns={'W_stratum':'Stratum'}).assign(Set='totalWHR')]).to_csv('work/strata.csv',index=False)
print(gc.to_string(index=False)); print(gw.to_string(index=False))
if not os.path.exists('work/text.csv'): sys.exit('run text.R next')
# ---------- workbooks ----------
from openpyxl import Workbook
from openpyxl.styles import Font, Alignment
from openpyxl.worksheet.datavalidation import DataValidation
T=pd.read_csv('work/text.csv',dtype={'FULL_PROJECT_NUM':str})
def abst(r):
    s=str(r.text); tl=str(r.PROJECT_TITLE).lower().strip()
    if s.lower().startswith(tl): s=s[len(tl):].lstrip(' .')
    return s
T['Abstract']=T.apply(abst,axis=1)
F=Font(name='Arial',size=11); FB=Font(name='Arial',size=11,bold=True); WR=Alignment(wrap_text=True,vertical='top')
def sheet(ws,cols,rows,widths):
    ws.append(cols)
    for r in rows: ws.append(list(r))
    for row in ws.iter_rows():
        for c in row: c.font=F; c.alignment=WR
    for c in ws[1]: c.font=FB
    ws.freeze_panes='A2'
    for i,w in enumerate(widths): ws.column_dimensions[chr(65+i)].width=w
RULES=open('work/rules.txt').read().strip().split('\n')
CATS=['Female-specific/reproductive','Maternal/pregnancy','Female cancers incl. breast','Female-predominant condition','Sex differences/women focus','Violence/social determinants',"Other women's health",'Not WHR']
def blind(df,name,tag,start):
    d=df.merge(T,on=['FY','FULL_PROJECT_NUM'],how='left').sample(frac=1,random_state=SEED%1000).reset_index(drop=True)
    assert d.Abstract.notna().all() and len(d)==len(df)
    d['Review_ID']=[f'{tag}{start+i:03d}' for i in range(len(d))]
    wb=Workbook(); ins=wb.active; ins.title='Instructions'
    for l in RULES: ins.append([l])
    for row in ins.iter_rows():
        for c in row: c.font=F; c.alignment=WR
    ins.column_dimensions['A'].width=120
    ws=wb.create_sheet('Review')
    cols=['Review_ID','Project_Number','FY','IC','Title','Abstract','WHR (yes/no)','CV (yes/no)','CV-WHR (yes/no)','WHR category','Comments']
    sheet(ws,cols,d[['Review_ID','FULL_PROJECT_NUM','FY','IC','PROJECT_TITLE','Abstract']].assign(a='',b='',c='',e='',f='').values,[10,20,7,7,40,100,12,12,14,30,40])
    n=len(d)+1
    dv=DataValidation(type='list',formula1='"yes,no"',allow_blank=True); ws.add_data_validation(dv)
    for col in 'GHI': dv.add(f'{col}2:{col}{n}')
    lst=wb.create_sheet('Lists'); [lst.append([c]) for c in CATS]
    dv2=DataValidation(type='list',formula1=f'Lists!$A$1:$A${len(CATS)}',allow_blank=True); ws.add_data_validation(dv2); dv2.add(f'J2:J{n}')
    wb.active=1; wb.properties.creator=''; wb.properties.lastModifiedBy=''; wb.properties.title=''
    wb.save(f'{name}_BLIND.xlsx'); return d
def key(d,name,strat,g):
    wb=Workbook(); ws=wb.active; ws.title='Key'; d=d.copy()
    for c in ['t3','cv','cvwhr']: d[c]=np.where(d[c],'yes','no')
    sheet(ws,['Review_ID','Project_Number','Core_Project','FY','IC','USD','Stratum','N_h (population)','n_h (sampled)','Weight','v11c WHR','v11c CV','v11c CV-WHR'],
          d[['Review_ID','FULL_PROJECT_NUM','CORE_PROJECT_NUM','FY','IC','USD',strat,'N_h','n_h','weight','t3','cv','cvwhr']].values,[10,20,14,7,7,12,36,12,10,10,9,9,11])
    s=wb.create_sheet('Strata')
    sheet(s,['Stratum','N_h (project-years)','n_h','Sampling fraction','Weight','Stratum USD'],g[[strat,'N_h','n_h','fraction','weight','USD_h']].values,[36,16,8,14,10,18])
    wb.properties.creator=''; wb.properties.lastModifiedBy=''
    wb.save(f'{name}_ANSWER_KEY.xlsx')
dc=blind(C,'WHR_v12_CV_validation','C',201); dw=blind(W,'WHR_v12_totalWHR_validation','W',201)
key(dc,'WHR_v12_CV_validation','C_stratum',gc); key(dw,'WHR_v12_totalWHR_validation','W_stratum',gw)
print('workbooks written')

"""Score a returned v12 validation workbook against its answer key.
Usage: python3 score_v12_validation.py RETURNED_BLIND.xlsx ANSWER_KEY.xlsx [--reps 2000] [--out results.xlsx]
   or: python3 score_v12_validation.py --items ../results/v12_validation_items.csv --set CV|totalWHR [--out scores.csv]
Reviewer answer = reference standard; v11c call = test. Reports sensitivity, specificity, PPV, NPV,
agreement and Cohen's kappa, three ways: unweighted (raw counts), count-weighted (inverse probability
N_h/n_h, i.e. portfolio project-years) and dollar-weighted (N_h/n_h x project USD, secondary).
95% CIs: stratified bootstrap (resample within each sampling stratum), percentile method.
Primary measure: CV-WHR for the CV set (C IDs), WHR for the total WHR set (W IDs).
Rows with a blank reviewer answer are dropped for that measure."""
import sys, argparse, pandas as pd, numpy as np
ap=argparse.ArgumentParser(); ap.add_argument('returned',nargs='?'); ap.add_argument('key',nargs='?')
ap.add_argument('--items'); ap.add_argument('--set',choices=['CV','totalWHR'])
ap.add_argument('--reps',type=int,default=2000); ap.add_argument('--seed',type=int,default=20261102); ap.add_argument('--out')
a=ap.parse_args()
if a.items:  # de-identified item file shipped in validation_v12/results/
    D=pd.read_csv(a.items); D=D[D.Set==a.set].rename(columns={'Review WHR':'WHR (yes/no)','Review CV':'CV (yes/no)','Review CV-WHR':'CV-WHR (yes/no)'}).reset_index(drop=True)
else:
    R=pd.read_excel(a.returned,sheet_name='Review'); K=pd.read_excel(a.key,sheet_name='Key')
    D=K.merge(R[['Review_ID','WHR (yes/no)','CV (yes/no)','CV-WHR (yes/no)']],on='Review_ID',how='left')
setC=D.Review_ID.str.startswith('C').all()
measures=[('CV-WHR','CV-WHR (yes/no)','v11c CV-WHR'),('CV','CV (yes/no)','v11c CV')] if setC else [('WHR','WHR (yes/no)','v11c WHR')]
def yn(s): return s.astype(str).str.strip().str.lower().map({'yes':1,'y':1,'no':0,'n':0})
def stats(p,t,w):
    tp=(w*(p&t)).sum(); fp=(w*(p&~t)).sum(); fn=(w*(~p&t)).sum(); tn=(w*(~p&~t)).sum(); n=tp+fp+fn+tn
    po=(tp+tn)/n; pe=((tp+fp)*(tp+fn)+(fn+tn)*(fp+tn))/n**2
    f=lambda x,y: x/y if y>0 else np.nan
    return dict(sensitivity=f(tp,tp+fn),specificity=f(tn,tn+fp),PPV=f(tp,tp+fp),NPV=f(tn,tn+fn),agreement=po,
                kappa=(po-pe)/(1-pe) if pe<1 else np.nan,prevalence=f(tp+fn,n))
rng=np.random.default_rng(a.seed); rows=[]
for name,rc,kc in measures:
    t=yn(D[rc]); p=yn(D[kc]); m=t.notna()&p.notna(); d=D[m].copy(); d['t']=t[m].astype(bool); d['p']=p[m].astype(bool)
    d['w_cnt']=d['Weight']; d['w_usd']=d['Weight']*d['USD'].clip(lower=0); d['w_raw']=1.0
    groups=[g.index.values for _,g in d.groupby('Stratum')]
    boots={k:[] for k in ('w_raw','w_cnt','w_usd')}
    for _ in range(a.reps):
        idx=np.concatenate([rng.choice(g,len(g),replace=True) for g in groups]); b=d.loc[idx]
        for k in boots: boots[k].append(stats(b.p.values,b.t.values,b[k].values))
    for k,lab in (('w_raw','unweighted'),('w_cnt','weighted (project-years)'),('w_usd','weighted (dollars)')):
        est=stats(d.p.values,d.t.values,d[k].values); B=pd.DataFrame(boots[k])
        for s,v in est.items():
            lo,hi=np.nanpercentile(B[s],[2.5,97.5])
            rows.append(dict(measure=name,weighting=lab,n=len(d),statistic=s,estimate=v,ci_low=lo,ci_high=hi))
    tab=pd.crosstab(d.p.map({True:'v11c yes',False:'v11c no'}),d.t.map({True:'review yes',False:'review no'}))
    print(f'\n{name}: raw counts (n={len(d)}, dropped blanks={int((~m).sum())})\n{tab}')
O=pd.DataFrame(rows)
P=O.assign(cell=lambda x:x.apply(lambda r:f'{r.estimate*100:.1f} ({r.ci_low*100:.1f}-{r.ci_high*100:.1f})' if r.statistic!='kappa' else f'{r.estimate:.2f} ({r.ci_low:.2f}-{r.ci_high:.2f})',axis=1))
print('\n'+P.pivot_table(index=['measure','weighting'],columns='statistic',values='cell',aggfunc='first')[['sensitivity','specificity','PPV','NPV','kappa','agreement','prevalence']].to_string())
print('\nPercentages except kappa; 95% CIs from stratified bootstrap,',a.reps,'reps.')
if a.out: (O.to_csv(a.out,index=False) if a.out.endswith('.csv') else O.to_excel(a.out,index=False))

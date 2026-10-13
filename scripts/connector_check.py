
import re,unicodedata
import os,sys,glob
R=os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..'))+'/'
STOP=set("the an to of in on at for my me is are am do does did what whats when how can you please with and or it this that there any anything have has be would could should will about from next all get show tell give need want let not dont now just some up out by as if so we us our your".split())
def stem(w):
    s=w
    for suf in ["ing","ed","es","s"]:
        if s.endswith(suf) and len(s)-len(suf)>=3:
            s=s[:-len(suf)];break
    if s.endswith("e") and len(s)>3: s=s[:-1]
    return s
def tokens(text):
    sp="";prev=" "
    for ch in text:
        if ch.isupper() and prev.islower(): sp+=" "
        sp+=ch;prev=ch
    f=unicodedata.normalize('NFD',sp);f=''.join(c for c in f if unicodedata.category(c)!='Mn').lower()
    out=[]
    for raw in re.split(r'[^a-z0-9\u00c0-\uffff]+',f):
        w=raw
        if len(w)<2 or w in STOP or w.isdigit(): continue
        out.append(stem(w))
    return out
LIT=r'"((?:[^"\\]|\\.)*)"'
def lits(s): return [re.sub(r'\\(.)',r'\1',m) for m in re.findall(LIT,s)]
def parse(path=R+'Packages/ToolKit/Sources/StandardCatalog.swift'):
    src=open(path,encoding='utf-8').read()
    entries=[]
    for blk in src.split('CatalogEntry(')[1:]:
        def one(k):
            m=re.search(k+r':\s*'+LIT,blk); return re.sub(r'\\(.)',r'\1',m.group(1)) if m else ''
        def lst(k):
            i=blk.find(k+': [')
            if i<0: return []
            j=blk.find(']',i)
            # lists can hold ']' inside strings only rarely; scan literals up to matching bracket
            depth=0;k2=i+len(k)+2;out=[];pos=k2+1
            body=blk[k2:]
            end=0;instr=False;esc=False
            for n,ch in enumerate(body):
                if instr:
                    if esc: esc=False
                    elif ch=='\\': esc=True
                    elif ch=='"': instr=False
                else:
                    if ch=='"': instr=True
                    elif ch=='[': depth+=1
                    elif ch==']':
                        depth-=1
                        if depth==0: end=n;break
            return lits(body[:end+1])
        entries.append(dict(id=one('id'),title=one('title'),category=one('category'),description=one('description'),keywords=lst('keywords'),examples=lst('examples')))
    return entries
def weights(e):
    w={}
    def put(t,x):
        for k in tokens(t): w[k]=max(w.get(k,0),x)
    put(e['id'],2);put(e['title'],2)
    for k in e['keywords']: put(k,3)
    for k in e['examples']: put(k,1.5)
    put(e['description'],1);put(e['category'],1)
    return w
def search(entries,primary='',secondary='',limit=3,minimum=3):
    ws=[weights(e) for e in entries]
    p=set(tokens(primary));s=set(tokens(secondary))
    sc=[]
    for i,w in enumerate(ws):
        score=2*sum(w.get(t,0) for t in p)+sum(w.get(t,0) for t in s)
        if score>=minimum: sc.append((score,i))
    sc.sort(key=lambda x:(-x[0],x[1]))
    if not sc: return []
    top=sc[0][0]
    return [(entries[i]['id'],s_) for s_,i in sc if s_>=top*0.5][:limit]

def unesc(s): return re.sub(r'\\(.)',r'\1',s)

def manifest_entries():
    """CatalogEntry rows derived from every *Manifest.swift, the way ConnectorManifest.catalogEntries does."""
    out=[]
    for f in sorted(glob.glob(R+'Packages/ToolKit/Sources/Connectors/*Manifest.swift')):
        if f.endswith('ConnectorManifest.swift'): continue
        s=open(f,encoding='utf-8').read()
        cat=re.search(r'category:\s*'+LIT,s).group(1)
        for blk in s.split('ConnectorToolSpec(')[1:]:
            def one(k):
                m=re.search(r'\b'+k+r':\s*'+LIT,blk); return unesc(m.group(1)) if m else ''
            def lst(k):
                i=blk.find(k+': [')
                if i<0: return []
                body=blk[i+len(k)+2:]
                d=0;instr=False;esc=False;end=0
                for n,ch in enumerate(body):
                    if instr:
                        if esc: esc=False
                        elif ch=='\\': esc=True
                        elif ch=='"': instr=False
                    else:
                        if ch=='"': instr=True
                        elif ch=='[': d+=1
                        elif ch==']':
                            d-=1
                            if d==0: end=n;break
                return lits(body[:end+1])
            out.append(dict(id=one('name'),title=one('title'),category=cat,description=one('description'),keywords=lst('keywords'),examples=lst('examples')))
    return out

def check(entries):
    bad=[]
    ids=[e['id'] for e in entries]
    for i in set(ids):
        if ids.count(i)>1: bad.append(('duplicate id',i,[]))
    for e in entries:
        if len(e['keywords'])<3 or len(e['examples'])<3: bad.append((e['id'],'needs 3+ keywords and examples',[]))
        for ex in e['examples']:
            h=search(entries,'',ex)
            if not h or h[0][0]!=e['id']: bad.append((e['id'],ex,h))
    for t in ["Tell me a joke about cats","What is the capital of France?","Explain how rainbows form","thanks, that was great"]:
        if search(entries,'',t): bad.append(('unrelated',t,search(entries,'',t)))
    return bad

if __name__=='__main__':
    base=[e for e in parse() if True]
    mans=manifest_entries()
    entries=base+mans
    print(len(base),'hand-written rows,',len(mans),'manifest rows')
    bad=check(entries)
    for b in bad: print('PROBLEM',b)
    print('OK' if not bad else '%d problems'%len(bad))
    sys.exit(1 if bad else 0)

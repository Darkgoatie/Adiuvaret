
import os, subprocess, re
P='C:/Users/halit/Desktop/Projects/Adiuvaret/'
def rd(p): return open(P+p,encoding='utf-8',newline='').read()
def wr(p,s):
    os.makedirs(os.path.dirname(P+p),exist_ok=True); open(P+p,'w',encoding='utf-8',newline='\n').write(s)
def edit(p,a,b,count=1):
    s=rd(p); crlf='\r\n' in s; s=s.replace('\r\n','\n')
    assert a in s,(p,a[:70]); s=s.replace(a,b,count)
    open(P+p,'w',encoding='utf-8',newline='').write(s.replace('\n','\r\n') if crlf else s)
def sh(c):
    r=subprocess.run('cd '+P+' && '+c,shell=True,capture_output=True,text=True); return r.stdout+r.stderr

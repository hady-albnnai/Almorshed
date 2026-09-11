import pymupdf as fitz
from PIL import Image
import sys, io
def art(doc_path, pno, x0,y0,x1,y1, w=46, h=22, dpi=1200, tag=""):
    d=fitz.open(doc_path); p=d[pno-1]
    pix=p.get_pixmap(dpi=dpi, clip=fitz.Rect(x0,y0,x1,y1))
    im=Image.frombytes("RGB",(pix.width,pix.height),pix.samples).convert("L")
    im=im.resize((w,h), Image.LANCZOS)
    px=im.load()
    # ink = dark
    vals=[px[x,y] for x in range(w) for y in range(h)]
    lo,hi=min(vals),max(vals); thr=(lo+hi)/2
    print(f"\n### {tag}  p{pno}  box=({x0:.1f},{y0:.1f})-({x1:.1f},{y1:.1f})  {pix.width}x{pix.height}px ###")
    for y in range(h):
        print("   "+"".join("#" if px[x,y]<thr else ("." if px[x,y]<hi- (hi-lo)*0.25 else " ") for x in range(w)))
if __name__=="__main__":
    import json
    a=json.loads(sys.argv[1])
    art(**a)

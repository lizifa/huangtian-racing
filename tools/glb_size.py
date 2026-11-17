import json, struct, sys
from pathlib import Path

KIT = Path("/Users/lizifa/works/huangtian-racing/assets/kit")
targets = ["barrierRed","barrierWhite","flagCheckers","grandStand","grandStandCovered",
           "treeLarge","treeSmall","raceCarRed"]

def mat_mul(A, B):
    return [[sum(A[i][k]*B[k][j] for k in range(4)) for j in range(4)] for i in range(4)]

def mat_id():
    return [[1.0 if i==j else 0.0 for j in range(4)] for i in range(4)]

def mat_node(n):
    if "matrix" in n:
        m = n["matrix"]; return [[m[c*4+r] for c in range(4)] for r in range(4)]
    t=n.get("translation",[0,0,0]); r=n.get("rotation",[0,0,0,1]); s=n.get("scale",[1,1,1])
    x,y,z,w=r
    R=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
       [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
       [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    M=mat_id()
    for i in range(3):
        for j in range(3): M[i][j]=R[i][j]*s[j]
    M[0][3],M[1][3],M[2][3]=t
    return M

def box_for(gltf):
    lo=[1e9]*3; hi=[-1e9]*3
    def walk(ni, PM):
        nonlocal lo, hi
        n=gltf["nodes"][ni]; M=mat_mul(PM,mat_node(n))
        if "mesh" in n:
            for prim in gltf["meshes"][n["mesh"]]["primitives"]:
                acc=prim["attributes"].get("POSITION")
                if acc is None: continue
                a=gltf["accessors"][acc]; mn,mx=a.get("min"),a.get("max")
                if mn is None: continue
                corners=[[x,y,z,1.0] for x in (mn[0],mx[0]) for y in (mn[1],mx[1]) for z in (mn[2],mx[2])]
                for c in corners:
                    w=[sum(M[i][j]*c[j] for j in range(4)) for i in range(4)]
                    for k in range(3):
                        lo[k]=min(lo[k],w[k]); hi[k]=max(hi[k],w[k])
        for ch in n.get("children",[]): walk(ch,M)
    for n in gltf["scenes"][0].get("nodes",[]): walk(n,mat_id())
    return lo,hi

for name in targets:
    f=KIT/(name+".glb"); data=f.read_bytes()
    jl=struct.unpack("<I",data[12:16])[0]
    gltf=json.loads(data[20:20+jl])
    lo,hi=box_for(gltf)
    size=[round(hi[k]-lo[k],3) for k in range(3)]
    print(f"{name:20s} min={[round(v,3) for v in lo]} size={size}")

import json, struct, sys
from pathlib import Path

p = Path(sys.argv[1])
data = p.read_bytes()
assert data[:4] == b'glTF'
json_len = struct.unpack('<I', data[12:16])[0]
gltf = json.loads(data[20:20+json_len])

def mat_mul(A, B):
    return [[sum(A[i][k]*B[k][j] for k in range(4)) for j in range(4)] for i in range(4)]

def mat_identity():
    return [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]

def mat_from_node(n):
    if 'matrix' in n:
        m = n['matrix']  # column-major
        return [[m[c*4+r] for c in range(4)] for r in range(4)]
    t = n.get('translation', [0,0,0])
    r = n.get('rotation', [0,0,0,1])
    s = n.get('scale', [1,1,1])
    x,y,z,w = r
    R = [
        [1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
        [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
        [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)],
    ]
    M = mat_identity()
    for i in range(3):
        for j in range(3):
            M[i][j] = R[i][j] * s[j]
    M[0][3], M[1][3], M[2][3] = t
    return M

def xform(M, v):
    return [sum(M[i][j]*v[j] for j in range(4)) for i in range(4)]

def walk(node_idx, parent_M, out):
    n = gltf['nodes'][node_idx]
    M = mat_mul(parent_M, mat_from_node(n))
    if 'mesh' in n:
        mesh = gltf['meshes'][n['mesh']]
        for pi, prim in enumerate(mesh['primitives']):
            acc = prim['attributes'].get('POSITION')
            if acc is None: continue
            a = gltf['accessors'][acc]
            mn, mx = a.get('min'), a.get('max')
            if mn is None: continue
            corners = [[x,y,z,1.0] for x in (mn[0],mx[0]) for y in (mn[1],mx[1]) for z in (mn[2],mx[2])]
            ws = [xform(M, c)[:3] for c in corners]
            wmin = [min(w[k] for w in ws) for k in range(3)]
            wmax = [max(w[k] for w in ws) for k in range(3)]
            out.append((n.get('name', f'node{node_idx}'), pi,
                        [round(v,3) for v in wmin], [round(v,3) for v in wmax]))
    for ch in n.get('children', []):
        walk(ch, M, out)

out = []
scene0 = gltf.get('scenes', [{}])[0]
for n in scene0.get('nodes', []):
    walk(n, mat_identity(), out)

allmin = [1e9]*3; allmax = [-1e9]*3
for name, pi, mn, mx in out:
    print(f"{name} prim{pi} min={mn} max={mx}")
    for k in range(3):
        allmin[k] = min(allmin[k], mn[k]); allmax[k] = max(allmax[k], mx[k])
print("MERGED min=", [round(v,3) for v in allmin], " max=", [round(v,3) for v in allmax])
print("center=", [round((allmin[k]+allmax[k])/2,3) for k in range(3)],
      " size=", [round(allmax[k]-allmin[k],3) for k in range(3)])

"""Task 7 mathematical reference, independent of RTL and golden outputs.

Implements the VISIBLE forward equations on page 1 of the supplied PDF.
Enumerates the shoulder, orientation and elbow branches instead of guessing
which inverse solution the judge selects. Angles are degrees externally.
No third-party dependencies. Does not overwrite official vectors.
"""
import argparse
import json
import math
import sys
from pathlib import Path

D0, A2, A3, D4, D5, TOOL = .18070, .61270, .57155, .17415, .11985, .32655


def signed32(word):
    return word - (1 << 32) if word & (1 << 31) else word


def forward(degrees):
    p1, p2, p3, p4 = map(math.radians, degrees)
    psi = p2 + p3 + p4
    radial = D5 * math.sin(psi) - A2 * math.cos(p2) - A3 * math.cos(p2+p3) + TOOL * math.cos(psi)
    return (radial * math.cos(p1) + D4 * math.sin(p1),
            radial * math.sin(p1) - D4 * math.cos(p1),
            D0 - A2 * math.sin(p2) - A3 * math.sin(p2+p3) + TOOL * math.sin(psi) - D5 * math.cos(psi),
            math.sin(psi))


def inverse(target):
    x, y, z, r33 = target
    discriminant = x*x + y*y - D4*D4
    if abs(r33) > 1 or discriminant < -1e-12:
        return []
    solutions = []
    for shoulder in (1, -1):
        radial = shoulder * math.sqrt(max(0, discriminant))
        p1 = math.atan2(y, x) + math.atan2(D4, radial)
        p1 = (p1 + math.pi) % (2*math.pi) - math.pi
        for psi in (math.asin(r33), math.pi-math.asin(r33)):
            arm_x = radial - D5*math.sin(psi) - TOOL*math.cos(psi)
            arm_z = z - D0 - TOOL*math.sin(psi) + D5*math.cos(psi)
            c3 = (arm_x*arm_x+arm_z*arm_z-A2*A2-A3*A3)/(2*A2*A3)
            if abs(c3) > 1 + 1e-12:
                continue
            for elbow in (1, -1):
                p3 = elbow*math.acos(max(-1, min(1, c3)))
                p2 = math.atan2(-arm_z, -arm_x)-math.atan2(A3*math.sin(p3), A2+A3*math.cos(p3))
                p4 = psi-p2-p3
                angles = list(map(math.degrees, (p1,p2,p3,p4)))
                if all(max(abs(a-b) for a,b in zip(angles,s)) > 1e-7 for s in solutions):
                    solutions.append(angles)
    return solutions


def read_hex(path):
    return [int(token,16) for line in path.read_text().splitlines()
            for token in line.split('//',1)[0].split()]


def report(tb_dir):
    source = read_hex(tb_dir/'task07.mem')
    golden = read_hex(tb_dir/'task07_ref.mem')
    result = []
    for offset in range(0, len(source)-4, 5):
        point = [signed32(v)/4096 for v in source[offset+1:offset+5]]
        angles = [signed32(v)/4096 for v in golden[offset+1:offset+5]]
        predicted = forward(angles)
        result.append(dict(header=source[offset], input_q20_12=point,
                           official_angles_degrees=angles,
                           forward_of_official_angles=predicted,
                           forward_error=[a-b for a,b in zip(predicted,point)],
                           inverse_candidates_degrees=inverse(point),
                           alternate_integer_r33_candidates=inverse(point[:3]+[signed32(source[offset+4])])) )
    return result


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--tb',type=Path,default=Path(__file__).resolve().parents[1]/'tb')
    parser.add_argument('--check-golden',action='store_true',help='Fail if supplied golden angles do not reconstruct the supplied inputs (tolerance 0.001).')
    args=parser.parse_args()
    results=report(args.tb)
    print(json.dumps(results,indent=2))
    if args.check_golden and any(max(map(abs,r['forward_error']))>0.001 for r in results):
        print('GOLDEN_MODEL_MISMATCH: check reference frames, orientation format and branch convention.',file=sys.stderr)
        sys.exit(1)

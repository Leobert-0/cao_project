"""Deterministic, independent software golden model and file-driven vectors."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
V = ROOT / 'vectors'
V.mkdir(exist_ok=True)
R_OP = {(0, 0): 0, (32, 0): 1, (0, 7): 2, (0, 6): 3,
        (0, 4): 4, (0, 1): 5, (0, 5): 6, (0, 2): 7}
I_OP = {0: 0, 7: 2, 6: 3, 4: 4, 1: 5, 5: 6, 2: 7}

def signed(n, bits):
    return n - (1 << bits) if n & (1 << (bits-1)) else n

def decode(ins):
    code, f3, f7 = ins & 127, (ins >> 12) & 7, ins >> 25
    imm = signed(ins >> 20, 12) & 0xffffffff
    op = src = rw = mr = mw = invalid = 0
    if code == 0x33:
        rw = 1
        op = R_OP.get((f7, f3), 0)
        invalid = int((f7, f3) not in R_OP)
    elif code == 0x13:
        rw = src = 1
        op = I_OP.get(f3, 0)
        invalid = int(f3 not in I_OP or (f3 in (1, 5) and f7 != 0))
    elif code == 3:
        src = rw = mr = 1
        invalid = int(f3 != 0)
    elif code == 0x23:
        imm = signed(((ins >> 25) << 5) | ((ins >> 7) & 31), 12) & 0xffffffff
        src = mw = 1
        invalid = int(f3 != 0)
    else:
        invalid = 1
    if invalid:
        rw = mr = mw = 0
    control = (op << 5) | (src << 4) | (rw << 3) | (mr << 2) | (mw << 1) | invalid
    return imm, control

def alu(a, b, op):
    sa, sb = signed(a, 8), signed(b, 8)
    ops = [a+b, a-b, a & b, a | b, a ^ b, a << (b % 8), a >> (b % 8), int(sa < sb)]
    y = ops[op] & 255
    c = int(a+b > 255) if op == 0 else int(a >= b) if op == 1 else 0
    math = sa+sb if op == 0 else sa-sb
    ov = int(not -128 <= math <= 127) if op < 2 else 0
    return y, (c << 3) | (int(y == 0) << 2) | (int(y >= 128) << 1) | ov

def r(rd, a, b, f3=0, f7=0):
    return f7 << 25 | b << 20 | a << 15 | f3 << 12 | rd << 7 | 0x33

def it(rd, a, imm, f3=0, code=0x13):
    return (imm & 4095) << 20 | a << 15 | f3 << 12 | rd << 7 | code

def store(a, b, imm):
    imm &= 4095
    return (imm >> 5) << 25 | b << 20 | a << 15 | (imm & 31) << 7 | 0x23

directed = [(0,255,1),(0,127,1),(0,128,128),(1,5,10),(1,128,1),(1,7,7),
            (2,255,0),(2,85,170),(2,255,85),(3,0,0),(3,85,170),(3,128,1),
            (4,85,85),(4,85,170),(4,0,255),(5,128,1),(5,1,7),(5,1,8),
            (6,1,1),(6,128,7),(6,255,0),(7,128,127),(7,127,128),(7,255,0)]
lines=[]
for op,a,b in directed:
    y,f=alu(a,b,op)
    lines.append(f'{(op<<28)|(a<<20)|(b<<12)|(y<<4)|f:08x}')
(V/'alu_directed.mem').write_text('\n'.join(lines)+'\n')

# All funct7/funct3 combinations for the four supported opcode families.
decoder = []
for code in (0x33, 0x13, 3, 0x23):
    for f7 in range(128):
        for f3 in range(8):
            ins = f7 << 25 | 31 << 20 | 17 << 15 | f3 << 12 | 29 << 7 | code
            imm, ctrl = decode(ins)
            decoder.append(f'{ins:08x}{imm:08x}{ctrl:02x}')
for code in range(128):
    ins = 0xfff08080 | code
    imm, ctrl = decode(ins)
    decoder.append(f'{ins:08x}{imm:08x}{ctrl:02x}')
(V/'decoder.mem').write_text('\n'.join(decoder)+'\n')

program = [
    ('ADDI x1,x0,-1', it(1, 0, -1)), ('ADDI x2,x0,1', it(2, 0, 1)),
    ('ADD x3,x1,x2 carry/zero', r(3, 1, 2)), ('ADDI x4,x0,127', it(4, 0, 127)),
    ('ADD x5,x4,x2 overflow', r(5, 4, 2)), ('ADDI x6,x0,5', it(6, 0, 5)),
    ('ADDI x7,x0,10', it(7, 0, 10)), ('SUB x8,x6,x7 negative/borrow', r(8, 6, 7, 0, 32)),
    ('AND x9,x1,x6', r(9, 1, 6, 7)), ('OR x10,x6,x7', r(10, 6, 7, 6)),
    ('XOR x11,x6,x6 zero', r(11, 6, 6, 4)), ('SLL x12,x2,x6', r(12, 2, 6, 1)),
    ('SRL x13,x5,x2', r(13, 5, 2, 5)), ('SLT x14,x5,x4', r(14, 5, 4, 2)),
    ('ANDI x15,x1,0 zero', it(15, 1, 0, 7)), ('ORI x16,x0,85', it(16, 0, 85, 6)),
    ('XORI x17,x16,85 zero', it(17, 16, 85, 4)), ('SLLI x18,x2,7', it(18, 2, 7, 1)),
    ('SRLI x19,x18,7', it(19, 18, 7, 5)), ('SLTI x20,x8,0', it(20, 8, 0, 2)),
    ('SB x8,3(x0)', store(0, 8, 3)), ('LB x21,3(x0)', it(21, 0, 3, 0, 3)),
    ('SB x6,-1(x0) wrap address', store(0, 6, -1)), ('LB x22,-1(x0)', it(22, 0, -1, 0, 3)),
    ('ADDI x0,x0,99 immutable x0', it(0, 0, 99)),
    ('ADDI x23,x0,257 truncate immediate', it(23, 0, 257)),
    ('SUB x24,x5,x2 signed overflow', r(24, 5, 2, 0, 32)),
    ('invalid opcode', 0xffffffff), ('invalid R funct7', r(1, 2, 2, 0, 1)),
    ('invalid load width', it(1, 0, 3, 2, 3)),
    ('invalid store width', store(0, 1, 3) | (2 << 12)),
    ('stall ADDI x1,x0,42', it(1, 0, 42)),
    ('stall SB x1,3(x0)', store(0, 1, 3)),
    ('LB x25,3(x0) verify stalled store', it(25, 0, 3, 0, 3)),
    ('SLL zero result', it(26, 18, 1, 1)),
    ('SRL zero result', it(27, 2, 1, 5)),
    ('SUB zero/no borrow', r(28, 7, 7, 0, 32)),
]
regs, memory, records, packed = [0]*32, [0]*256, [], []
for step, (name, ins) in enumerate(program):
    enabled = int(not name.startswith('stall'))
    imm, ctrl = decode(ins)
    op, src, rw, mr, mw, invalid = ctrl >> 5, (ctrl >> 4)&1, (ctrl >> 3)&1, (ctrl >> 2)&1, (ctrl >> 1)&1, ctrl&1
    rd, rs1, rs2 = (ins >> 7)&31, (ins >> 15)&31, (ins >> 20)&31
    a, b = regs[rs1], (imm & 255) if src else regs[rs2]
    y, flags = alu(a, b, op)
    wb = memory[y] if mr else y
    bits = (enabled << 108) | (ins << 76) | (wb << 68) | (flags << 64) | (ctrl << 56) | (imm << 24) | (a << 16) | (b << 8) | y
    packed.append(f'{bits:028x}')
    records.append(dict(step=step, instruction=f'{ins:08x}', assembly=name, enable=enabled, a=f'{a:02x}', b=f'{b:02x}', result=f'{y:02x}', writeback=f'{wb:02x}', CZNV=f'{flags:04b}'))
    if enabled and not invalid:
        if mw: memory[y] = regs[rs2]
        if rw and rd: regs[rd] = wb
(V/'program.mem').write_text('\n'.join(packed)+'\n')
(V/'program_listing.json').write_text(json.dumps(records, indent=2)+'\n')
(V/'final_registers.mem').write_text('\n'.join(f'{v:02x}' for v in regs)+'\n')
(V/'final_memory.mem').write_text('\n'.join(f'{v:02x}' for v in memory)+'\n')
(V/'vector_counts.vh').write_text(f'`define DECODER_COUNT {len(decoder)}\n`define PROGRAM_COUNT {len(program)}\n')
print(f'Generated {len(decoder)} decoder and {len(program)} program vectors.')

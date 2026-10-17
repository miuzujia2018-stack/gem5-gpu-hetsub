#!/usr/bin/env python3
# Post-process a yosys-abc bridge re-import netlist so OpenSTA can link it.
# The bridge names abc-created cells' ports by abc internal node names instead
# of liberty pin names. For each instance, the port whose name is not a liberty
# pin is renamed to the single missing signal pin (power pins VDD/VSS are never
# present in the netlist). Instances where every port is an abc node name have
# no unique missing pin and are left unchanged (OpenSTA will warn and drop their
# arcs); the count is printed so the WNS is reported on the linkable subset.
import re, sys

def cell_pins(lib_path):
    lib = open(lib_path).read()
    pins = {}
    for m in re.finditer(r'cell\s*\(([^)]+)\)\s*\{', lib):
        name = m.group(1).strip()
        i = m.end() - 1; depth = 0; j = i
        while j < len(lib):
            if lib[j] == '{': depth += 1
            elif lib[j] == '}':
                depth -= 1
                if depth == 0: break
            j += 1
        p = re.findall(r'pin\s*\(([^)]+)\)', lib[i:j])
        pins[name] = set(x for x in p if x not in ('VDD', 'VSS'))
    return pins

def fix(net_path, lib_path, out_path):
    pins = cell_pins(lib_path)
    net = open(net_path).read()
    def fix_inst(m):
        cell, inst, ports = m.group(1), m.group(2), m.group(3)
        if cell not in pins: return m.group(0)
        pairs = re.findall(r'\.(\S+?)\s*\(([^)]*)\)', ports)
        names = [p[0] for p in pairs]
        wrong = [p for p in names if p not in pins[cell]]
        if not wrong: return m.group(0)
        missing = pins[cell] - set(names)
        if len(missing) != 1: return m.group(0)
        target = next(iter(missing))
        out = ['.{}({})'.format(target if pn not in pins[cell] else pn, netn)
               for pn, netn in pairs]
        return '{} {} (\n    {}\n  );'.format(cell, inst, ',\n    '.join(out))
    fixed = re.sub(r'(\w+)\s+(\S+)\s*\((.*?)\)\s*;', fix_inst, net, flags=re.S)
    open(out_path, 'w').write(fixed)
    insts = re.findall(r'(\w+)\s+(\S+)\s*\((.*?)\)\s*;', fixed, re.S)
    rem = sum(1 for c, i, p in insts if c in pins and
              any(x not in pins[c] for x in
                  [q.split('.', 1)[1].split('(')[0].strip() for q in p.split(',') if '.' in q]))
    print('unlinked (ambiguous) instances:', rem)

if __name__ == '__main__':
    fix(sys.argv[1], sys.argv[2], sys.argv[3])

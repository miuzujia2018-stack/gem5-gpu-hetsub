#!/usr/bin/env python3
"""Fail-closed audit of actual formal_10c_v1 gem5 run directories."""
import argparse
import configparser
import json
import math
import re
from pathlib import Path

COUNTS = {'TimingSimpleCPU': 16, 'CudaCore': 10,
          'Directory_Controller': 4, 'GPUL2Cache_Controller': 40}
ERRORS = re.compile(r'panic:|fatal:|Assertion|NI-WARN|NI-ERROR|deadlocked|kernel error:', re.I)
NORMAL_EXIT = re.compile(r'Exiting @ tick \d+ because (?:target called exit\(\)|exiting with last active thread context)', re.I)
CACHE_FIELDS = ('size', 'assoc', 'start_index_bit', 'dataAccessLatency',
                'tagAccessLatency', 'dataArrayBanks', 'tagArrayBanks',
                'is_icache', 'resourceStalls')


def config(path):
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    with path.open(errors='replace') as stream:
        parser.read_file(stream)
    return parser


def normalize(path):
    path = path.strip()
    return 'ruby.'+path.split('.ruby.', 1)[1] if '.ruby.' in path else path


def sections(cfg, kind):
    return [s for s in cfg.sections() if cfg.get(s, 'type', fallback='') == kind]


def gpu_options(path):
    values, current = {}, None
    for raw in path.read_text(errors='replace').splitlines():
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('-'):
            if current:
                key, value = current.split(None, 1)
                values[key[1:]] = value.strip()
            current = line.split('#', 1)[0].rstrip()
        elif current:
            current += ' '+line.split('#', 1)[0].rstrip()
    if current:
        key, value = current.split(None, 1)
        values[key[1:]] = value.strip()
    return values


def stats(path):
    values, begin, end = {}, 0, 0
    for line in path.read_text(errors='replace').splitlines():
        begin += 'Begin Simulation Statistics' in line
        end += 'End Simulation Statistics' in line
        row = line.split()
        if len(row) > 1:
            try:
                value = float(row[1])
            except ValueError:
                continue
            if math.isfinite(value):
                values[row[0]] = value
    return values, begin, end


def one_stat(values, suffix):
    matches = {k: v for k, v in values.items() if k.endswith('.'+suffix)}
    if len(matches) != 1:
        raise ValueError('expected one stat ending %s, found %d' % (suffix, len(matches)))
    return next(iter(matches.values()))


def stat_vector(values, suffix):
    marker = '.'+suffix+'::'
    return {k.split(marker, 1)[1]: v for k, v in values.items()
            if marker in k and not k.endswith('::total')}


def suffix_sum(values, suffix):
    return sum(value for key, value in values.items()
               if key.endswith('.'+suffix))


def mapping(cfg, network):
    rows, links = [], cfg.get(network, 'ext_links').split()
    if len(links) != 72:
        raise ValueError('expected 72 external links, found %d' % len(links))
    for link in links:
        controller = cfg.get(link, 'ext_node')
        router = cfg.get(link, 'int_node')
        rows.append((normalize(controller), cfg.get(controller, 'type'),
                     cfg.get(controller, 'version'), cfg.getint(router, 'router_id')))
    return sorted(rows)


def cache_geometry(cfg):
    rows = []
    for section in sections(cfg, 'RubyCache'):
        row = [normalize(section)]
        row.extend(cfg.get(section, field, fallback=None) for field in CACHE_FIELDS)
        rows.append(tuple(row))
    return sorted(rows)


def shared_signature(cfg, network, gpu):
    routers = cfg.get(network, 'routers').split()
    router_ids = sorted(cfg.getint(router, 'router_id') for router in routers)
    if len(routers) != 64 or router_ids != list(range(64)):
        raise ValueError('network does not reference physical router IDs 0..63')
    clocks = {name: cfg.get(name, 'clock') for name in
              ('system.clk_domain', 'system.cpu_clk_domain',
               'system.ruby_clk_domain', 'system.gpu.clk_domain')}
    return {
        'gpu_options': {k: v for k, v in sorted(gpu.items())
                        if k != 'inter_config_file'},
        'endpoint_mapping': mapping(cfg, network),
        'cache_geometry': cache_geometry(cfg),
        'clocks': clocks,
        'network_resources': {
            'vcs_per_vnet': cfg.get(network, 'vcs_per_vnet'),
            'buffer_size': cfg.get(network, 'buffer_size'),
            'number_of_pipe_stages': cfg.get(network, 'number_of_pipe_stages'),
        },
    }


def audit_run(directory):
    directory = Path(directory)
    errors, warnings = [], []
    result = {'path': str(directory), 'errors': errors, 'warnings': warnings}
    try:
        command = json.loads((directory/'command.json').read_text())
        if command.get('profile') != 'formal_10c_v1' or command.get('exit_code') != 0:
            errors.append('invalid formal command metadata or nonzero recorded exit')
        method = command.get('method')
        result['identity'] = {k: command.get(k) for k in
                              ('profile', 'repo', 'method', 'app', 'run_name', 'exit_code')}
        cfg = config(directory/'config.ini')
        network = sections(cfg, 'GarnetNetwork')
        if len(network) != 1:
            raise ValueError('expected one GarnetNetwork')
        network = network[0]
        counts = {kind: len(sections(cfg, kind)) for kind in COUNTS}
        result['counts'] = counts
        for kind, expected in COUNTS.items():
            if counts[kind] != expected:
                errors.append('%s expected %d got %d' % (kind, expected, counts[kind]))
        gpu = gpu_options(directory/'gpgpusim.config')
        if gpu.get('gpgpu_n_clusters') != '10' or gpu.get('gpgpu_n_cores_per_cluster') != '1':
            errors.append('GPGPU-Sim is not 10 clusters x 1 core')
        if gpu.get('gpgpu_num_sp_units') != '2':
            errors.append('GPGPU-Sim SP units differ from frozen common value 2')
        result['_signature'] = shared_signature(cfg, network, gpu)
        mode = cfg.get(network, 'het_mode', fallback=None)
        result['network'] = {'mode': mode or method,
                             'router_objects': len(sections(cfg, 'GarnetRouter')),
                             'external_endpoints': len(cfg.get(network, 'ext_links').split())}

        stdout = (directory/'stdout.log').read_text(errors='replace')
        stderr = (directory/'stderr.log').read_text(errors='replace')
        markers = sorted(set(ERRORS.findall(stdout+'\n'+stderr)))
        if markers:
            errors.append('runtime error markers: '+', '.join(markers))
        if not NORMAL_EXIT.search(stdout):
            errors.append('normal application exit not observed')
        values, begin, end = stats(directory/'stats.txt')
        if (begin, end) != (1, 1):
            errors.append('stats are not one full-job window')
        injected = one_stat(values, 'packets_injected')
        received = one_stat(values, 'packets_received')
        byte_injected = one_stat(values, 'bytes_injected')
        byte_received = one_stat(values, 'bytes_received')
        service = one_stat(values, 'packet_service_cycles')
        queue = one_stat(values, 'packet_queue_cycles')
        completion = one_stat(values, 'packet_completion_cycles')
        if received > injected or byte_received > byte_injected:
            errors.append('received count exceeds injected count')
        if completion != service + queue:
            errors.append('packet completion sum differs from service + queue')
        flits = stat_vector(values, 'link_transfer_flits')
        widths = stat_vector(values, 'link_width_bytes')
        if not flits or set(flits) != set(widths):
            errors.append('link transfer/width vectors missing or misaligned')
        sim_ticks = values.get('sim_ticks')
        ruby_clock_ticks = cfg.getfloat('system.ruby_clk_domain', 'clock')
        link_total = sum(flits.values())
        link_square_total = sum(value*value for value in flits.values())
        link_count = len(flits)
        link_mean = link_total/link_count if link_count else 0
        result['metrics'] = {
            'sim_ticks': sim_ticks, 'ruby_cycles': sim_ticks/ruby_clock_ticks,
            'received_messages_per_ruby_cycle': received/(sim_ticks/ruby_clock_ticks),
            'packets_injected': injected,
            'packets_received': received, 'packets_inflight_at_exit': injected-received,
            'bytes_injected': byte_injected, 'bytes_received': byte_received,
            'packet_service_latency_cycles': one_stat(values, 'packet_service_latency_cycles'),
            'packet_completion_latency_cycles': one_stat(values, 'packet_completion_latency_cycles'),
            'link_transfer_flits': link_total,
            'link_wire_bytes': sum(flits[k]*widths[k] for k in flits),
            'registered_links': link_count,
            'active_links': sum(value > 0 for value in flits.values()),
            'link_load_jain': (link_total*link_total/(link_count*link_square_total)
                               if link_count and link_square_total else 0),
            'link_peak_to_mean': max(flits.values())/link_mean if link_mean else 0,
            'pg_sleep_router_cycles': suffix_sum(values, 'het_sleep_cycles'),
            'pg_waking_router_cycles': suffix_sum(values, 'het_waking_cycles'),
            'pg_active_router_cycles': suffix_sum(values, 'het_active_cycles'),
            'pg_wakeups': suffix_sum(values, 'het_wakeups'),
            'pg_transition_energy_wu': suffix_sum(values, 'het_transition_energy_cycles'),
            'normal_exit': True, 'explicit_network_drain': False,
            'population': 'received original messages at process exit',
        }
        if method == 'tbp' and not any(('vc_grant_tbp_xy' in k or
                                       'vc_grant_tbp_yx' in k) and v > 0
                                      for k, v in values.items()):
            errors.append('TBP method activity not observed')
        if method == 'bak' and not any('pso_table_usage_rate' in k and v > 0
                                      for k, v in values.items()):
            errors.append('bak online routing activity not observed')
        if mode in ('dual', 'static') and one_stat(values, 'het_received_packets::total') <= 0:
            errors.append('HetSub receive activity not observed')
        if mode == 'static' and one_stat(values, 'het_bypass_segment_beats') <= 0:
            errors.append('HetSub static bypass activity not observed')
    except (OSError, ValueError, configparser.Error, KeyError) as exc:
        errors.append('audit failed closed: %s' % exc)
    return result


def differences(reference, actual, prefix=''):
    if isinstance(reference, dict) and isinstance(actual, dict):
        output = []
        for key in sorted(set(reference) | set(actual)):
            output += differences(reference.get(key), actual.get(key), prefix+'.'+key)
        return output
    if reference != actual:
        return [{'field': prefix.lstrip('.'), 'reference': reference, 'actual': actual}]
    return []


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', '--reference-off', required=True, type=Path)
    parser.add_argument('runs', nargs='+', type=Path)
    args = parser.parse_args()
    paths = [args.reference] + [p for p in args.runs if p.resolve() != args.reference.resolve()]
    records = [audit_run(path) for path in paths]
    reference = records[0].get('_signature')
    comparisons = []
    for record in records[1:]:
        delta = differences(reference, record.get('_signature')) if reference else [{'field': 'signature'}]
        comparisons.append({'run': record['path'], 'matches_platform': not delta,
                            'differences': delta[:80]})
        if delta:
            record['errors'].append('shared platform differs from reference')
    clean = [{k: v for k, v in record.items() if k != '_signature'} for record in records]
    output = {'tool': 'audit_comparison', 'schema': 1,
              'ok': all(not record['errors'] for record in records),
              'reference': str(args.reference), 'comparisons': comparisons,
              'runs': clean}
    print(json.dumps(output, indent=2))
    raise SystemExit(0 if output['ok'] else 1)


if __name__ == '__main__':
    main()

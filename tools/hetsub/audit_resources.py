#!/usr/bin/env python3
"""Audit configured data queues and measured PG states; no area/power fitting."""
import argparse
import configparser
import json
from pathlib import Path


def audit(directory):
    cfg = configparser.ConfigParser()
    cfg.read(directory/'config.ini')
    raw = (directory/'stats.txt').read_text()
    assert raw.count('Begin Simulation Statistics') == 1
    stats = {}
    for line in raw.splitlines():
        row = line.split()
        if len(row) > 1:
            try:
                stats[row[0]] = float(row[1])
            except ValueError:
                pass
    assert stats['sim_ticks'] == stats['final_tick'], 'full-job window required'
    net = 'system.ruby.network'
    prefix = net+'.'
    mode = cfg.get(net, 'het_mode')
    assert mode in ('dual', 'static')
    vn = cfg.getint(net, 'number_of_virtual_networks')
    depth = cfg.getint(net, 'buffer_size')
    width = cfg.getint(net, 'het_mesh_bytes')
    nodes = len(cfg.get(net, 'netifs').split())
    mesh_channels = 2*len(cfg.get(net, 'int_links').split())
    line_channels = 0
    for section in cfg.get(net, 'het_line_links').split():
        if cfg.getint(section, 'het_src_tile') >= 0 and cfg.getint(section, 'het_dst_tile') >= 0:
            line_channels += 1
    relays = cfg.get(net, 'het_relays').split()
    shortcuts = len(relays)//2
    router_bytes = vn*depth*(16*(line_channels+nodes+shortcuts) +
                            2*width*(mesh_channels+nodes))
    ni_bytes = nodes*vn*depth*(16+2*width)
    relay_bytes = sum(vn*4*cfg.getint(s, 'input_bytes') + cfg.getint(s, 'output_bytes') for s in relays)
    # Existing NI M source staging is retained while the serializer replaces
    # its physical link producer. Relay stages are counted in relay_bytes.
    staging_bytes = 16*(line_channels+2*nodes+shortcuts) + width*(mesh_channels+2*nodes)
    internal = line_channels*16+mesh_channels*width
    expected = dict(het_router_buffer_bytes=router_bytes, het_ni_buffer_bytes=ni_bytes,
                    het_relay_buffer_bytes=relay_bytes, het_staging_bytes=staging_bytes,
                    het_internal_capacity_bytes_per_cycle=internal)
    for key, value in expected.items():
        assert stats[prefix+key] == value, (key, value, stats[prefix+key])
    routers = [s for s in cfg.sections() if cfg.get(s, 'type', fallback='') == 'GarnetRouter'
               and cfg.getint(s, 'het_subnet') == 1]
    assert len(routers) == 64
    ruby_clock = cfg.get(net, 'clk_domain')
    cycles = stats['final_tick']/cfg.getint(ruby_clock, 'clock')
    totals = dict(active=0, sleep=0, waking=0, wakeups=0, transition=0)
    for section in routers:
        values = {key:stats[section+'.het_'+field] for key, field in
                  [('active','active_cycles'), ('sleep','sleep_cycles'),
                   ('waking','waking_cycles'), ('wakeups','wakeups'),
                   ('transition','transition_energy_cycles')]}
        assert values['active']+values['sleep']+values['waking'] == cycles
        assert 0 <= values['waking'] <= 6*values['wakeups']
        assert values['transition'] == 10*values['wakeups']
        for key, value in values.items():
            totals[key] += int(value)
    return dict(mode=mode, mesh_bytes=width, protocol_vnets=vn, endpoints=nodes,
                internal_channels=dict(line=line_channels, mesh=mesh_channels),
                internal_bytes_per_cycle=internal,
                baseline_internal_bytes_per_cycle=mesh_channels*16,
                external_installed_width_bytes_both_directions=2*nodes*(16+width),
                baseline_external_width_bytes_both_directions=2*nodes*16,
                ni_service_max_bytes_per_cycle_per_direction_per_endpoint=16,
                virtual_relay_access_channels=2*shortcuts,
                data_storage_bytes=dict(router_vcs=router_bytes, ni_vcs=ni_bytes,
                                        relay_fifo_and_staging=relay_bytes,
                                        other_source_staging=staging_bytes),
                m_router_state_totals=totals,
                excluded_from_storage_sum=['link delay/pipeline implementation',
                                          'VC/control metadata', 'mux/crossbar area'],
                energy_joules=None,
                energy_note='State and wake-cost counters only; calibrated power coefficients unavailable')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    print(json.dumps(audit(args.directory), indent=2))

#!/usr/bin/env python3
"""Check finite-packet delivery and actual subnet widths in raw gem5 output."""
import configparser
import csv
import pathlib
import re
import sys


def vnets_for_relay(cfg):
    return cfg.getint('system.ruby.network', 'number_of_virtual_networks')


def validate(directory, case):
    root = pathlib.Path(directory)
    logs = (root / 'stdout.log').read_text() + (root / 'stderr.log').read_text()
    assert 'Network Tester completed simCycles' in logs, 'abnormal exit'
    assert not re.search(r'panic:|fatal:|Assertion|NI-WARN|NI-ERROR|deadlocked',
                         logs, re.I), 'runtime error or delivery fallback'
    raw = (root / 'stats.txt').read_text()
    assert raw.count('Begin Simulation Statistics') == 1, 'ambiguous stats block'
    values = {}
    for line in raw.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            try:
                values[parts[0]] = float(parts[1])
            except ValueError:
                pass
    cfg = configparser.ConfigParser()
    cfg.read(root / 'config.ini')
    prefix = 'system.ruby.network.'
    injected = values[prefix + 'packets_injected']
    received = values[prefix + 'packets_received']
    testers = [s for s in cfg.sections() if cfg.get(s, 'type', fallback='') == 'NetworkTest']
    assert len(testers) == 64
    expected_packets = sum(cfg.getint(s, 'max_packets') for s in testers)
    assert all(cfg.getboolean(s, 'fixed_pkts') for s in testers)
    assert injected == received == expected_packets, (injected, received)
    assert values[prefix + 'bytes_injected'] == values[
        prefix + 'bytes_received'], 'byte conservation failed'
    assert values[prefix + 'flits_injected::total'] == values[
        prefix + 'flits_received::total'], 'not all flits drained'
    service = values[prefix + 'packet_service_cycles']
    queue = values[prefix + 'packet_queue_cycles']
    completion = values[prefix + 'packet_completion_cycles']
    assert service > 0 and queue >= 0 and completion == service + queue
    assert abs(values[prefix + 'packet_service_latency_cycles'] - service/received) < 1e-5
    assert abs(values[prefix + 'packet_completion_latency_cycles'] - completion/received) < 1e-5
    assert completion/received <= values[prefix + 'packet_max_completion_cycles'] <= 12000
    routers = [s for s in cfg.sections() if cfg.get(s, 'type', fallback='') == 'GarnetRouter']
    period = 1000 if case == 'line_1ghz' else 500
    assert cfg.getint('system.clk_domain', 'clock') == period
    assert cfg.getint('system.ruby.clk_domain', 'clock') == period
    assert values['sim_freq'] == 10**12
    assert values['sim_ticks'] == 12000 * period, 'tick/cycle mismatch'
    if case == 'off':
        assert len(routers) == 64
        assert all(cfg.getint(s, 'het_subnet') == -1 for s in routers)
        assert cfg.getint('system.ruby.network', 'buffer_size') == 4
        assert cfg.getint('system.ruby.network', 'number_of_pipe_stages') == 2
        assert values[prefix + 'het_injected_packets::total'] == 0
        print('PASS off: %d correctly delivered XY packets, D=4, 2 stages' % received)
        return
    assert values[prefix + 'het_injected_packets::total'] == injected
    assert values[prefix + 'het_received_packets::total'] == received
    if case in ('line', 'pg_line', 'line_1ghz'):
        assert values[prefix + 'het_injected_packets::1'] == 0
    if case in ('mesh8', 'mesh7', 'pg_mesh'):
        assert values[prefix + 'het_injected_packets::0'] == 0
    if case == 'independence':
        parallel = values[prefix + 'het_parallel_tile_cycles::total']
        l_waking = values[prefix + 'het_l_transfers_m_waking']
        m_lfull = values[prefix + 'het_m_transfers_l_full']
        assert parallel > 0, 'no co-located L/M parallel transfer observed'
        assert l_waking > 0, 'L did not progress while co-located M woke'
        assert m_lfull > 0, 'M did not progress while co-located L was full'
        print('Independence evidence: %d tile cycles parallel, %d L during M wake, %d M during L full' % (
            parallel, l_waking, m_lfull))
    if case == 'policy_load':
        assert values[prefix + 'het_injected_packets::0'] > 0
        assert values[prefix + 'het_injected_packets::1'] > 0, 'no real congestion split'
    assert values[prefix + 'het_busy_resources'] == 0, 'network contexts or queues not drained'
    width = cfg.getint('system.ruby.network', 'het_mesh_bytes')
    static = cfg.get('system.ruby.network', 'het_mode') == 'static'
    expected_flits = 0
    for subnet, flit_width in enumerate((16, width)):
        packets = values[prefix + 'het_injected_packets::%d' % subnet]
        byte_count = values[prefix + 'het_injected_bytes::%d' % subnet]
        # Network_test messages are 8-byte control or 72-byte data messages.
        data = (byte_count - packets * 8) / 64
        assert data == int(data) and 0 <= data <= packets
        control = packets - data
        expected_flits += control * ((8 + flit_width - 1) // flit_width)
        expected_flits += data * ((72 + flit_width - 1) // flit_width)
    relays = [s for s in cfg.sections() if cfg.get(s, 'type', fallback='') == 'HetSubRelay']
    if static:
        assert values[prefix + 'het_injected_packets::1'] == 0
        assert len(relays) == len(cfg.get('system.ruby.network', 'het_shortcut_paths').split()) // 3 * 2
        assert values[prefix + 'het_bypass_segment_beats'] > 0
        total_relay_bytes = 0
        for section in relays:
            frames = values[section + '.completed_frames']
            byte_count = values[section + '.input_bytes']
            assert frames > 0 or case in ('static_pilot', 'static_transpose'), 'unused shortcut relay'
            assert byte_count == values[section + '.output_bytes']
            data = (byte_count - frames * 8) / 64
            assert data == int(data) and 0 <= data <= frames
            for direction in ('input', 'output'):
                flit_width = cfg.getint(section, direction + '_bytes')
                expected = ((frames-data) * ((8+flit_width-1)//flit_width) +
                            data * ((72+flit_width-1)//flit_width))
                assert values[section + '.' + direction + '_flits'] == expected
            expected_flits += values[section + '.output_flits']
            assert 0 <= values[section + '.fifo_highwater'] <= 4
            if frames: assert values[section + '.fifo_highwater'] > 0
            total_relay_bytes += (vnets_for_relay(cfg) * 4 *
                                 cfg.getint(section, 'input_bytes') +
                                 cfg.getint(section, 'output_bytes'))
        ordered_relays = cfg.get('system.ruby.network', 'het_relays').split()
        paths = [int(t) for t in cfg.get('system.ruby.network', 'het_shortcut_paths').split()]
        if case == 'static_level2':
            assert paths == [10, 9, 17], 'frozen level-2 shortcut path mismatch'
            # Tester 10's 16 directed packets must use the frozen level-2 port;
            # other packets passing through router 10 toward tile 17 may share it.
            assert values[ordered_relays[0] + '.completed_frames'] >= 16, 'level-2 relay did not carry the directed packets'
        segment_beats = 0
        for i in range(len(ordered_relays)//2):
            serializer, deserializer = ordered_relays[2*i:2*i+2]
            assert values[serializer + '.input_bytes'] == values[deserializer + '.output_bytes']
            assert values[serializer + '.completed_frames'] == values[deserializer + '.completed_frames']
            assert values[serializer + '.output_flits'] == values[deserializer + '.input_flits']
            segment_beats += values[serializer + '.output_flits'] * (3 if paths[3*i+1] == -1 else 4)
        assert values[prefix + 'het_bypass_segment_beats'] == segment_beats
        assert values[prefix + 'het_relay_buffer_bytes'] == total_relay_bytes
        assert sum(values[s + '.completed_frames'] for s in relays) > 0
        downstream_stalls = sum(values[s + '.downstream_stall_cycles'] for s in relays)
        mux_deferrals = values[prefix + 'het_local_mux_deferrals']
        if case in ('static7', 'static_transpose', 'static_pilot'):
            assert downstream_stalls > 0, 'no actual downstream backpressure exercised'
        if case in ('static_transpose', 'static_pilot'):
            assert mux_deferrals > 0, 'no actual local service sharing exercised'
        print('Backpressure evidence: %d downstream stall cycles, %d MUX deferrals' % (
            downstream_stalls, mux_deferrals))
        # Static paths must not use M buffers or ordinary RC/VA, even though
        # the reserved physical segments carry the serialized data.
        for section in routers:
            if cfg.getint(section, 'het_subnet') == 1:
                assert values[section + '.het_route_requests'] == 0
                assert values[section + '.het_buffer_writes'] == 0
        print('Bypass evidence: %d relays, %d physical segment beats' % (
            len(relays), values[prefix + 'het_bypass_segment_beats']))
    else:
        assert not relays
    assert values[prefix + 'flits_injected::total'] == expected_flits, (
        'physical flit counts do not match actual message sizes', expected_flits)
    assert values[prefix + 'het_internal_capacity_bytes_per_cycle'] == (
        126 * 16 + 224 * width), 'unexpected physical bandwidth'
    assert len(routers) == 128, 'missing independent subrouters'
    assert sum(cfg.getint(s, 'het_subnet') == 0 for s in routers) == 64
    assert sum(cfg.getint(s, 'het_subnet') == 1 for s in routers) == 64
    for s in routers:
        assert cfg.getint(s, 'vcs_per_vnet') == (1 if cfg.getint(s, 'het_subnet') == 0 else 2)
    ni_count = sum(cfg.get(s, 'type', fallback='') == 'GarnetNetworkInterface'
                   for s in cfg.sections())
    vnets = cfg.getint(routers[0], 'virt_nets')
    assert ni_count == 128
    router_bytes = vnets * 4 * (16 * (126 + ni_count) +
                              2 * width * (224 + ni_count))
    ni_bytes = ni_count * vnets * 4 * (16 + 2 * width)
    if static:
        router_bytes += len(relays)//2 * vnets * 4 * 16
    assert values[prefix + 'het_router_buffer_bytes'] == router_bytes
    assert values[prefix + 'het_ni_buffer_bytes'] == ni_bytes
    if case == 'static_pilot':
        assert '--random_seed=42' in logs
        assert not cfg.get('system.ruby.network', 'het_profile_file')
    if case == 'pilot':
        with (root / 'profile.csv').open() as stream:
            flows = list(csv.DictReader(stream))
        assert flows and sum(int(row['bytes']) for row in flows) == values[prefix + 'bytes_injected']
        for row in flows:
            src, dst, count = (int(row[k]) for k in ('src_tile', 'dst_tile', 'bytes'))
            assert 0 <= src < 64 and 0 <= dst < 64 and count > 0
            assert values[prefix + 'het_pilot_flow_bytes::%d' % (src*64+dst)] == count
        assert '--random_seed=17' in logs
        print('Pilot evidence: %d actual source/destination flows, total bytes conserved' % len(flows))
    if case.startswith('pg_'):
        m_routers = [s for s in routers if cfg.getint(s, 'het_subnet') == 1]
        sleeps = sum(values[s + '.het_sleep_cycles'] for s in m_routers)
        wakes = sum(values[s + '.het_wakeups'] for s in m_routers)
        waking = sum(values[s + '.het_waking_cycles'] for s in m_routers)
        transition = sum(values[s + '.het_transition_energy_cycles'] for s in m_routers)
        assert sleeps > 0, 'no M resource ever slept'
        assert waking == wakes * 6, 'wake service did not last six cycles'
        assert transition == wakes * 10, 'missing PG transition energy'
        if case == 'pg_line':
            assert wakes == 0, 'idle M subnet woke without a request'
        else:
            assert wakes > 0, 'M traffic did not exercise wakeup'
        print('PG evidence: sleep_cycles=%d wakeups=%d waking_cycles=%d' % (
            sleeps, wakes, waking))
    print('PASS %s: %d packets, byte/flit conservation, 64 independent L/M pairs' % (
        case, received))


if __name__ == '__main__':
    validate(sys.argv[1], sys.argv[2])

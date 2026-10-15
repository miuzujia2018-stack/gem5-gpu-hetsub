#!/usr/bin/env python3
"""Check application completion, fixed platform and independent numeric output."""
import argparse
import configparser
import json
import math
import re
import struct
from pathlib import Path


def f32(value):
    return struct.unpack('f', struct.pack('f', value))[0]


def kmeans_reference(path):
    # The existing Rodinia text reader treats the FIRST column as an ID.
    points = [[f32(float(v)) for v in row.split()[1:]]
              for row in path.read_text().splitlines() if row.split()]
    dimensions = len(points[0])
    assert dimensions and all(len(p) == dimensions for p in points)
    # This benchmark initializes centers from the first five rows (the rand
    # selection line is commented out); do not substitute a random initializer.
    centers = [p[:] for p in points[:5]]
    membership = [-1] * len(points)

    def distance(a, b):
        total = f32(0)
        for x, y in zip(a, b):
            delta = f32(x-y)
            total = f32(total + f32(delta*delta))
        return total

    for iteration in range(502):
        counts, sums = [0]*5, [[f32(0)]*dimensions for _ in range(5)]
        changed = 0
        for i, point in enumerate(points):
            cluster = min(range(5), key=lambda c: distance(point, centers[c]))
            changed += membership[i] != cluster
            membership[i] = cluster
            counts[cluster] += 1
            for j, value in enumerate(point):
                sums[cluster][j] = f32(sums[cluster][j] + value)
        for c in range(5):
            if counts[c]:
                centers[c] = [f32(v/counts[c]) for v in sums[c]]
        if changed <= .001:
            break
    assert changed <= .001, 'CPU reference failed to converge'
    squared = f32(0)
    for point in points:
        squared = f32(squared + min(distance(point, c) for c in centers))
    rmse = f32(math.sqrt(f32(squared/len(points))))
    return points, centers, iteration+1, rmse


def block(text, start, end=None):
    assert text.count(start) == 1, 'missing or ambiguous numeric block: '+start
    section = text.split(start, 1)[1]
    if end:
        section = section.split(end, 1)[0]
    else:
        section = section.split('Training done', 1)[0]
    # Runtime method monitors may emit trace rows while the application is
    # printing a numeric block.  Accept complete numeric rows only; embedded
    # key=value diagnostics are simulator evidence, not application values.
    number = re.compile(r'[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?')
    output = []
    for line in section.splitlines():
        tokens = line.split()
        if tokens and all(number.fullmatch(token) for token in tokens):
            output.extend(float(token) for token in tokens)
    return output


def validate(directory, reference, input_file):
    app = directory.name
    text = (directory/'stdout.log').read_text()
    errors = (directory/'stderr.log').read_text()
    assert re.search(r'Exiting @ tick \d+ because (?:target called exit\(\)|exiting with last active thread context)', text), 'application did not exit normally'
    assert not re.search(r'panic:|fatal:|Assertion|NI-WARN|NI-ERROR|deadlocked|kernel error:',
                         text+errors, re.I), 'runtime error'
    cfg = configparser.ConfigParser()
    cfg.read(directory/'config.ini')
    cpus = [s for s in cfg.sections() if cfg.get(s, 'type', fallback='') == 'TimingSimpleCPU']
    assert len(cpus) == 16
    assert cfg.getint('system', 'cache_line_size') == 128
    assert cfg.getint('system.cpu_clk_domain', 'clock') == 500
    assert cfg.getint('system.ruby_clk_domain', 'clock') == 500
    net = 'system.ruby.network'
    assert cfg.get(net, 'topology') == 'Mesh8x8_CPU_GPU'
    assert cfg.getint(net, 'buffer_size') == 4
    assert cfg.getint(net, 'number_of_pipe_stages') == 2
    values = {}
    raw = (directory/'stats.txt').read_text()
    assert raw.count('Begin Simulation Statistics') == 1, 'requires full-job stats without per-kernel resets'
    for line in raw.splitlines():
        row = line.split()
        if len(row) > 1:
            try:
                values[row[0]] = float(row[1])
            except ValueError:
                pass
    prefix = net+'.'
    received, injected = (values[prefix+k] for k in ('packets_received', 'packets_injected'))
    assert 0 < received <= injected
    assert values[prefix+'packet_completion_cycles'] == (
        values[prefix+'packet_service_cycles'] + values[prefix+'packet_queue_cycles'])
    mode = cfg.get(net, 'het_mode', fallback=None)
    method = mode
    command_file = directory/'command.json'
    if command_file.is_file():
        command = json.loads(command_file.read_text())
        method = command.get('method', method)
    if mode is None:
        assert method in ('xy', 'tbp', 'bak'), 'missing method identity'
    if mode in ('dual', 'static'):
        assert values[prefix+'het_received_packets::total'] == received
    if app == 'backprop':
        assert reference and reference.exists(), 'CPU backprop reference required'
        expected = reference.read_text()
        for start, end, size in [('Partial Sums:', 'Input Weights:', 16),
                                 ('Input Weights:', 'Net Inputs:', 289),
                                 ('Net Inputs:', None, 16)]:
            observed, target = block(text, start, end), block(expected, start, end)
            assert len(observed) == len(target) == size
            if start == 'Net Inputs:':
                # Reserved bias input slot 0 is uninitialized in the original
                # CUDA host code; scalar training writes 1 there. Exclude it.
                observed, target = observed[1:], target[1:]
            assert all(math.isfinite(x) and abs(x-y) <= 2e-5
                       for x, y in zip(observed, target)), 'CPU backprop numerical mismatch: '+start
        assert 'Training done' in text
    elif app == 'kmeans':
        points, centers, iterations, rmse = kmeans_reference(input_file)
        assert 'Number of objects: %d' % len(points) in text
        assert 'Number of features: %d' % len(points[0]) in text
        assert 'iterated %d times' % iterations in text
        output = text.split('Centroid Coordinates', 1)[1]
        for i, center in enumerate(centers):
            match = re.search(r'^%d:\s+([^\n]+)' % i, output, re.M)
            assert match, 'missing cluster center'
            observed = [float(v) for v in match.group(1).split()]
            assert len(observed) == len(center)
            assert all(math.isfinite(x) and abs(x-y) <= .0051 for x, y in zip(observed, center)), 'CPU kmeans center mismatch'
        # Existing cluster.c stores rms_err() into an int before printing.
        # Match that documented legacy behavior; center coordinates above are
        # the independent numerical correctness check.
        assert 'Root Mean Squared Error: %.3f' % int(rmse) in text
    else:
        raise ValueError('unknown application '+app)
    shader_cores = sum(cfg.get(s, 'type', fallback='') == 'CudaCore' for s in cfg.sections())
    gpu_config = Path(cfg.get('system.gpu', 'config_path')).read_text()
    clusters = int(re.search(r'^-gpgpu_n_clusters\s+(\d+)', gpu_config, re.M).group(1))
    cores_per_cluster = int(re.search(r'^-gpgpu_n_cores_per_cluster\s+(\d+)', gpu_config, re.M).group(1))
    if mode == 'static':
        routers = [s for s in cfg.sections() if cfg.get(s, 'type', fallback='') == 'GarnetRouter']
        for router in routers:
            if cfg.getint(router, 'het_subnet') == 1:
                assert values[router+'.het_route_requests'] == 0
                assert values[router+'.het_buffer_writes'] == 0
        assert values[prefix+'het_bypass_segment_beats'] > 0
    result = dict(application=app, mode=mode, method=method, numeric_reference='CPU',
                  gem5_shader_cores=shader_cores, gpgpusim_shader_cores=clusters*cores_per_cluster,
                  gpu_model_consistent=(shader_cores == clusters*cores_per_cluster),
                  latency_population='received original messages at process exit',
                  packets_injected=int(injected), packets_received=int(received),
                  packets_inflight_at_exit=int(injected-received),
                  packet_service_cycles=values[prefix+'packet_service_latency_cycles'],
                  packet_completion_cycles=values[prefix+'packet_completion_latency_cycles'])
    if mode in ('dual', 'static'):
        result['busy_resources_at_process_exit'] = values[prefix+'het_busy_resources']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--backprop-reference', type=Path)
    parser.add_argument('--kmeans-input', type=Path, default=Path(__file__).resolve().parents[2]/'kmeans_input.txt')
    args = parser.parse_args()
    print(json.dumps(validate(args.directory, args.backprop_reference, args.kmeans_input), indent=2))

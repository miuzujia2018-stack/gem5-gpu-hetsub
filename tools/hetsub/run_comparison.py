#!/usr/bin/env python3
"""Run the frozen 10-cluster comparison without changing repository defaults."""
import argparse
import json
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REPOS = {'hetsub': ROOT, 'tbp': ROOT.with_name('gem5-gpu-tbp'),
         'bak': ROOT.with_name('gem5-gpu-bak')}


def write_common_gpu_config(out):
    """Render one GPGPU-Sim configuration used verbatim by all three trees."""
    gpu_dir = ROOT/'gem5-gpu'/'configs'/'gpu_config'
    icnt = out/'config_fermi_islip.icnt'
    config = (gpu_dir/'gpgpusim.fermi.config.template').read_text()
    replacements = {
        '%clusters%': '10', '%cores_per_cluster%': '1',
        '%ctas_per_shader%': '8', '%warp_size%': '32',
        '%threads_per_sm%': '1536', '%freq%': '700.0',
        '%icnt_file%': str(icnt),
    }
    for old, new in replacements.items():
        config = config.replace(old, new)
    if '%' in '\n'.join(line for line in config.splitlines()
                         if not line.lstrip().startswith('#')):
        raise RuntimeError('unresolved active GPGPU-Sim template placeholder')
    (out/'gpgpusim.config').write_text(config)
    icnt_text = (gpu_dir/'config_fermi_islip.template.icnt').read_text()
    icnt.write_text(icnt_text.replace('%num_nodes%', '12'))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('repo', choices=REPOS)
    p.add_argument('app', choices=['backprop', 'kmeans'])
    p.add_argument('--method', required=True,
                   choices=['xy', 'tbp', 'bak', 'dual8', 'dual7', 'static8', 'static7', 'pilot'])
    p.add_argument('--tag', required=True)
    p.add_argument('--shortcuts', type=Path)
    p.add_argument('--dry-run', action='store_true')
    args = p.parse_args()
    if not args.tag or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-' for c in args.tag):
        p.error('invalid output tag')
    allowed = {'hetsub': {'xy', 'dual8', 'dual7', 'static8', 'static7', 'pilot'},
               'tbp': {'tbp'}, 'bak': {'xy', 'bak'}}
    if args.method not in allowed[args.repo]:
        p.error('method and repository do not match')
    repo = REPOS[args.repo]
    run_name = args.repo+'_'+args.method
    out = ROOT/'m5out'/'comparison_10c'/args.tag/run_name/args.app
    seed = 17 if args.method == 'pilot' else 0
    binary = ROOT/'benchmarks'/'rodinia'/args.app/('gem5_fusion_'+args.app)
    workload = '16' if args.app == 'backprop' else '-i %s -o -r' % (ROOT/'kmeans_input.txt')
    flags = ['--garnet-network=flexible', '--topology=Mesh8x8_CPU_GPU', '--mesh-rows=8',
             '--cpu-type=timing', '--num-cpus=16', '--num-dirs=4', '--num-l2caches=40',
             '--mem-channels=8', '--clusters=10', '--cores_per_cluster=1',
             '--sys-clock=1GHz', '--cpu-clock=2GHz', '--ruby-clock=2GHz', '--cacheline_size=128',
             '--gpu-core-clock=700MHz', '--gpu_core_config=Fermi', '--ctas_per_shader=8',
             '--gpu_warp_size=32', '--gpu_threads_per_core=1536',
             '--sc_l1_size=64kB', '--sc_l1_assoc=4', '--sc_l2_size=1MB', '--sc_l2_assoc=16',
             '--l1d_size=64kB', '--l1d_assoc=2', '--l1i_size=32kB', '--l1i_assoc=2',
             '--l2_size=2MB', '--l2_assoc=8', '--random_seed=%d' % seed]
    flags += ['--gpgpusim-config='+str(out/'gpgpusim.config')]
    if args.repo != 'bak':
        flags += ['--topology-seed=0']
    if args.repo == 'hetsub':
        flags += ['--network-vcs-per-vnet=2', '--network-buffer-size=4', '--network-pipeline-stages=2']
        mode = 'off' if args.method == 'xy' else 'static' if args.method.startswith('static') else 'dual'
        flags += ['--hetsub-mode='+mode]
        if mode != 'off':
            flags += ['--hetsub-mesh-bytes='+('7' if args.method.endswith('7') else '8'), '--hetsub-pg']
        if args.method == 'pilot':
            flags += ['--hetsub-force-subnet=0', '--hetsub-profile='+str(out/'profile.csv')]
        if mode == 'static':
            if not args.shortcuts or not args.shortcuts.is_file():
                p.error('static mode requires an existing frozen pilot JSON')
            flags += ['--hetsub-shortcuts='+str(args.shortcuts.resolve())]
    elif args.repo == 'tbp':
        flags += ['--tbp-vcs-per-vnet=2', '--tbp-buffer-size=4', '--tbp-pipeline-stages=2',
                  '--tbp-startup-cycles=700000', '--tbp-sample-cycles=200000',
                  '--tbp-main-tb-cycles=3000000', '--tbp-main-tbp-cycles=2000000']
    elif args.repo == 'bak':
        if args.method == 'bak':
            flags += ['--routing-mode=online', '--retrain-mode=4']
        else:
            flags += ['--routing-mode=xy', '--retrain-mode=0']
    sim = [str(repo/'gem5/build/X86_VI_hammer_GPU/gem5.opt'), '-d', str(out),
           str(repo/'gem5-gpu/configs/se_fusion.py')] + flags + ['-c', str(binary), '-o', workload]
    guard = [str(repo/'tools/reproduction/verify_gem5_build.sh'), 'verify', str(repo), 'X86_VI_hammer_GPU']
    body = ('set -e; export CUDAHOME=/usr/local/cuda/cuda; '
            'export PATH=/usr/local/cuda/cuda/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; '
            'export LD_LIBRARY_PATH=/usr/local/cuda/cuda/lib64; '+shlex.join(guard)+'; exec '+shlex.join(sim))
    cmd = ['sudo', 'docker', 'run', '--rm', '--volumes-from', 'gem5gpu-dev-hetsub',
           '--volume', '%s:%s' % (repo, repo), '--workdir', str(out),
           'myubuntu14:latest', '/bin/bash', '--noprofile', '--norc', '-c', body]
    metadata = dict(profile='formal_10c_v1', repo=args.repo, method=args.method, app=args.app,
                    run_name=run_name, sim_seed=seed, topology_seed=0,
                    command=cmd, simulator_command=sim,
                    measurement_window='full job through application exit; no kernel resets',
                    power='uncalibrated activity/state proxies only')
    if args.dry_run:
        print(json.dumps(metadata, indent=2))
        return
    if out.exists():
        p.error('refusing to overwrite '+str(out))
    subprocess.run(guard, check=True)
    out.mkdir(parents=True)
    write_common_gpu_config(out)
    credential = repo/'.build_provenance/X86_VI_hammer_GPU.env'
    metadata['build_credential'] = credential.read_text()
    (out/'command.json').write_text(json.dumps(metadata, indent=2)+'\n')
    with (out/'stdout.log').open('w') as stdout, (out/'stderr.log').open('w') as stderr:
        result = subprocess.run(cmd, stdout=stdout, stderr=stderr)
    metadata['exit_code'] = result.returncode
    (out/'command.json').write_text(json.dumps(metadata, indent=2)+'\n')
    print('%s: exit %s: %s' % (args.method, result.returncode, out), flush=True)
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()

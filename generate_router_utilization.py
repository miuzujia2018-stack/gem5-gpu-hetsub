#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
路由器利用率统计 - 简化版
计算每个路由器的总体利用率
"""

import sys
import re
from datetime import datetime
from generate_comprehensive_csv import ComprehensiveGem5Parser


def generate_router_utilization_csv(stats_file, output_file, test_name='unknown'):
    """生成路由器利用率CSV（简化版）"""

    print(f"正在解析统计文件: {stats_file}")
    parser = ComprehensiveGem5Parser(stats_file)
    parser.parse()

    if not parser.stats:
        print(f"错误: 无法解析统计文件 {stats_file}")
        return False

    print(f"✅ 成功解析 {len(parser.stats)} 条统计数据")

    # 获取基本信息
    sim_seconds = parser.get_stat('sim_seconds')
    sim_ticks = parser.get_stat('sim_ticks')
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # 统计每个路由器的利用率
    router_stats = {}
    total_flits = 0

    # 16个路由器节点（4x4 Mesh）
    for router_id in range(16):
        router_node = f'system.ruby.network.ext_links{router_id:02d}'
        node_prefix = f'{router_node}.int_node'

        router_total = 0

        # 每个路由器24条链路
        for link_id in range(24):
            link_key = f'{node_prefix}.link_utilization::{link_id}'
            utilization = parser.get_stat(link_key)

            if utilization != 'N/A':
                try:
                    util_value = int(utilization)
                    router_total += util_value
                except ValueError:
                    pass

        if router_total > 0:
            row = router_id // 4
            col = router_id % 4
            router_stats[router_id] = {
                'total': router_total,
                'row': row,
                'col': col
            }
            total_flits += router_total

    # 计算每个路由器的利用率百分比
    for router_id, data in router_stats.items():
        data['percent'] = (data['total'] / total_flits * 100) if total_flits > 0 else 0

    # 生成CSV内容
    rows = []

    # 报告头
    rows.append(['========== 路由器利用率统计报告 =========='])
    rows.append(['报告生成时间', timestamp])
    rows.append(['测试程序', test_name])
    rows.append(['仿真时间 (秒)', sim_seconds])
    rows.append(['仿真周期 (ticks)', sim_ticks])
    rows.append([''])

    # 网络整体统计
    rows.append(['========== 网络整体统计 =========='])
    rows.append(['指标', '数值'])
    rows.append(['总传输量 (flits)', total_flits])
    rows.append(['活跃路由器数', len(router_stats)])
    rows.append(['路由器总数', 16])

    if sim_seconds != 'N/A':
        try:
            sim_sec = float(sim_seconds)
            if sim_sec > 0:
                throughput = total_flits / sim_sec
                rows.append(['网络总吞吐量 (flits/秒)', f"{throughput:.2f}"])
        except ValueError:
            pass

    rows.append([''])

    # 每个路由器的利用率
    rows.append(['========== 各路由器利用率 =========='])
    rows.append(['路由器ID', 'Mesh坐标', '传输总量 (flits)', '利用率 (%)', '占网络总量'])

    # 按路由器ID排序
    for router_id in sorted(router_stats.keys()):
        data = router_stats[router_id]
        rows.append([
            f'Router {router_id}',
            f'({data["row"]}, {data["col"]})',
            data['total'],
            f"{data['percent']:.4f}",
            f"{data['percent']:.2f}%"
        ])

    rows.append([''])

    # 4x4 Mesh可视化热力图（利用率百分比）
    rows.append(['========== 4x4 Mesh 路由器利用率热力图 =========='])
    rows.append(['', '列0', '列1', '列2', '列3'])

    for row in range(4):
        row_data = [f'行{row}']
        for col in range(4):
            router_id = row * 4 + col
            if router_id in router_stats:
                percent = router_stats[router_id]['percent']
                row_data.append(f'{percent:.2f}%')
            else:
                row_data.append('0.00%')
        rows.append(row_data)

    rows.append([''])

    # 热力图（传输总量）
    rows.append(['========== 4x4 Mesh 路由器传输量热力图 =========='])
    rows.append(['', '列0', '列1', '列2', '列3'])

    for row in range(4):
        row_data = [f'行{row}']
        for col in range(4):
            router_id = row * 4 + col
            if router_id in router_stats:
                total = router_stats[router_id]['total']
                row_data.append(str(total))
            else:
                row_data.append('0')
        rows.append(row_data)

    rows.append([''])

    # 统计摘要
    max_util_router = max(router_stats.items(), key=lambda x: x[1]['percent'])
    min_util_router = min(router_stats.items(), key=lambda x: x[1]['percent'])

    rows.append(['========== 利用率统计摘要 =========='])
    rows.append(['指标', '数值'])
    rows.append(['最高利用率路由器',
                f"Router {max_util_router[0]} ({max_util_router[1]['row']}, {max_util_router[1]['col']})"])
    rows.append(['最高利用率', f"{max_util_router[1]['percent']:.2f}%"])
    rows.append(['最低利用率路由器',
                f"Router {min_util_router[0]} ({min_util_router[1]['row']}, {min_util_router[1]['col']})"])
    rows.append(['最低利用率', f"{min_util_router[1]['percent']:.2f}%"])

    avg_util = sum(data['percent'] for data in router_stats.values()) / len(router_stats) if router_stats else 0
    rows.append(['平均利用率', f"{avg_util:.2f}%"])

    # 写入CSV文件
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            for row in rows:
                f.write(','.join(str(x) for x in row) + '\n')

        print(f"\n✅ 路由器利用率CSV报告生成成功: {output_file}")
        print(f"   - 总传输量: {total_flits} flits")
        print(f"   - 活跃路由器: {len(router_stats)}/16")
        print(f"   - 最高利用率: Router {max_util_router[0]} @ {max_util_router[1]['percent']:.2f}%")
        print(f"   - 平均利用率: {avg_util:.2f}%")

        return True

    except Exception as e:
        print(f"错误: 写入CSV文件失败: {e}")
        return False


def main():
    if len(sys.argv) < 2:
        print("用法: python3 generate_router_utilization.py <stats.txt> [output.csv] [test_name]")
        print("\n示例:")
        print("  python3 generate_router_utilization.py stats.txt")
        print("  python3 generate_router_utilization.py stats.txt router_util.csv backprop")
        sys.exit(1)

    stats_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else 'router_utilization.csv'
    test_name = sys.argv[3] if len(sys.argv) > 3 else 'unknown'

    success = generate_router_utilization_csv(stats_file, output_file, test_name)
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

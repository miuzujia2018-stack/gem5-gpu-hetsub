#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
增强型CSV生成器 - 专注于利用率统计
生成包含总链路利用率、单链路利用率百分比、处理单元利用率的CSV报告
"""

import sys
import re
from datetime import datetime
from generate_comprehensive_csv import ComprehensiveGem5Parser

class UtilizationAnalyzer:
    """利用率分析器"""

    def __init__(self, stats_parser):
        self.parser = stats_parser
        self.total_flits = 0
        self.router_utilization = {}
        self.link_utilization = {}
        self.active_links = 0
        self.total_links = 0

    def analyze(self):
        """执行全面的利用率分析"""
        self._analyze_link_utilization()
        self._analyze_router_utilization()
        self._calculate_network_metrics()

    def _analyze_link_utilization(self):
        """分析链路利用率"""
        # 16个路由器节点
        for router_id in range(16):
            router_node = f'system.ruby.network.ext_links{router_id:02d}'
            node_prefix = f'{router_node}.int_node'

            router_total = 0
            router_links = {}

            # 每个路由器24条链路
            for link_id in range(24):
                link_key = f'{node_prefix}.link_utilization::{link_id}'
                utilization = self.parser.get_stat(link_key)

                if utilization != 'N/A':
                    try:
                        util_value = int(utilization)
                        router_links[link_id] = util_value
                        router_total += util_value
                        self.total_flits += util_value
                        self.total_links += 1

                        if util_value > 0:
                            self.active_links += 1
                    except ValueError:
                        pass

            if router_total > 0:
                self.router_utilization[router_id] = {
                    'total': router_total,
                    'links': router_links
                }

        # 计算每条链路的利用率百分比
        if self.total_flits > 0:
            for router_id, data in self.router_utilization.items():
                for link_id, count in data['links'].items():
                    utilization_percent = (count / self.total_flits) * 100
                    self.link_utilization[f'R{router_id}_L{link_id}'] = {
                        'count': count,
                        'percent': utilization_percent
                    }

    def _analyze_router_utilization(self):
        """分析路由器（处理单元）利用率"""
        for router_id in range(16):
            if router_id in self.router_utilization:
                router_total = self.router_utilization[router_id]['total']
                router_percent = (router_total / self.total_flits) * 100 if self.total_flits > 0 else 0
                self.router_utilization[router_id]['percent'] = router_percent

    def _calculate_network_metrics(self):
        """计算网络整体指标"""
        self.avg_utilization_per_link = self.total_flits / self.total_links if self.total_links > 0 else 0
        self.active_link_ratio = (self.active_links / self.total_links * 100) if self.total_links > 0 else 0

    def get_summary(self):
        """获取利用率摘要"""
        return {
            'total_flits': self.total_flits,
            'total_links': self.total_links,
            'active_links': self.active_links,
            'avg_per_link': self.avg_utilization_per_link,
            'active_ratio': self.active_link_ratio
        }


def generate_utilization_csv(stats_file, output_file, test_name='unknown'):
    """生成利用率分析CSV"""

    print(f"正在解析统计文件: {stats_file}")
    parser = ComprehensiveGem5Parser(stats_file)
    parser.parse()  # 需要调用parse()方法

    if not parser.stats:
        print(f"错误: 无法解析统计文件 {stats_file}")
        return False

    print(f"✅ 成功解析 {len(parser.stats)} 条统计数据")

    # 创建利用率分析器
    analyzer = UtilizationAnalyzer(parser)
    analyzer.analyze()
    summary = analyzer.get_summary()

    # 获取基本信息
    sim_seconds = parser.get_stat('sim_seconds')
    sim_ticks = parser.get_stat('sim_ticks')
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # 生成CSV内容
    rows = []

    # ========== 第1部分：报告头信息 ==========
    rows.append(['========== 网络利用率分析报告 =========='])
    rows.append(['报告生成时间', timestamp])
    rows.append(['测试程序', test_name])
    rows.append(['仿真时间 (秒)', sim_seconds])
    rows.append(['仿真周期 (ticks)', sim_ticks])
    rows.append([''])

    # ========== 第2部分：网络整体利用率 ==========
    rows.append(['========== 网络整体利用率统计 =========='])
    rows.append(['指标', '数值'])
    rows.append(['总传输数据包片段数 (flits)', summary['total_flits']])
    rows.append(['总链路数', summary['total_links']])
    rows.append(['活跃链路数 (利用率>0)', summary['active_links']])
    rows.append(['空闲链路数 (利用率=0)', summary['total_links'] - summary['active_links']])
    rows.append(['活跃链路比例 (%)', f"{summary['active_ratio']:.2f}"])
    rows.append(['平均每链路传输量 (flits)', f"{summary['avg_per_link']:.2f}"])

    # 计算网络整体吞吐量
    if sim_seconds != 'N/A':
        try:
            sim_sec = float(sim_seconds)
            if sim_sec > 0:
                throughput = summary['total_flits'] / sim_sec
                rows.append(['网络总吞吐量 (flits/秒)', f"{throughput:.2f}"])
        except ValueError:
            pass

    rows.append([''])

    # ========== 第3部分：路由器（处理单元）利用率 ==========
    rows.append(['========== 路由器（处理单元）利用率 =========='])
    rows.append(['路由器ID', '传输总量 (flits)', '利用率 (%)', '活跃链路数', '在Mesh中的位置'])

    # 按路由器ID排序
    for router_id in sorted(analyzer.router_utilization.keys()):
        data = analyzer.router_utilization[router_id]
        active_links_count = sum(1 for count in data['links'].values() if count > 0)

        # 计算Mesh坐标
        row = router_id // 4
        col = router_id % 4
        position = f"({row}, {col})"

        rows.append([
            f'Router {router_id}',
            data['total'],
            f"{data['percent']:.4f}",
            f"{active_links_count}/24",
            position
        ])

    rows.append([''])

    # ========== 第4部分：Top活跃链路 ==========
    rows.append(['========== Top 20 活跃链路统计 =========='])
    rows.append(['链路标识', '传输量 (flits)', '利用率 (%)', '路由器位置', '链路方向'])

    # 按传输量排序，取Top 20
    sorted_links = sorted(analyzer.link_utilization.items(),
                         key=lambda x: x[1]['count'], reverse=True)[:20]

    link_direction_map = {
        range(0, 4): '东向 (East)',
        range(4, 8): '西向 (West)',
        range(8, 12): '南向 (South)',
        range(12, 16): '北向 (North)',
        range(16, 20): '本地注入 (Local Injection)',
        range(20, 24): '本地弹出 (Local Ejection)'
    }

    def get_link_direction(link_id):
        for r, direction in link_direction_map.items():
            if link_id in r:
                return direction
        return '未知'

    for link_name, data in sorted_links:
        # 解析链路名: R<router_id>_L<link_id>
        match = re.match(r'R(\d+)_L(\d+)', link_name)
        if match:
            router_id = int(match.group(1))
            link_id = int(match.group(2))
            row = router_id // 4
            col = router_id % 4
            position = f"({row},{col})"
            direction = get_link_direction(link_id)

            rows.append([
                link_name,
                data['count'],
                f"{data['percent']:.4f}",
                position,
                f"{direction} VC{link_id%4}"
            ])

    rows.append([''])

    # ========== 第5部分：链路方向统计 ==========
    rows.append(['========== 各方向链路统计 =========='])
    rows.append(['方向', '传输总量 (flits)', '利用率 (%)', '平均每链路'])

    direction_stats = {
        '东向 (East)': {'range': range(0, 4), 'total': 0, 'count': 0},
        '西向 (West)': {'range': range(4, 8), 'total': 0, 'count': 0},
        '南向 (South)': {'range': range(8, 12), 'total': 0, 'count': 0},
        '北向 (North)': {'range': range(12, 16), 'total': 0, 'count': 0},
        '本地注入': {'range': range(16, 20), 'total': 0, 'count': 0},
        '本地弹出': {'range': range(20, 24), 'total': 0, 'count': 0}
    }

    for router_id, data in analyzer.router_utilization.items():
        for link_id, count in data['links'].items():
            for direction, stats in direction_stats.items():
                if link_id in stats['range']:
                    stats['total'] += count
                    stats['count'] += 1

    for direction, stats in direction_stats.items():
        total = stats['total']
        percent = (total / summary['total_flits'] * 100) if summary['total_flits'] > 0 else 0
        avg = total / stats['count'] if stats['count'] > 0 else 0
        rows.append([direction, total, f"{percent:.2f}", f"{avg:.2f}"])

    rows.append([''])

    # ========== 第6部分：详细链路利用率矩阵 ==========
    rows.append(['========== 详细链路利用率（按路由器） =========='])

    for router_id in sorted(analyzer.router_utilization.keys()):
        data = analyzer.router_utilization[router_id]
        row = router_id // 4
        col = router_id % 4
        rows.append([f'Router {router_id} @ ({row},{col})', '传输量', '占本路由器比例 (%)'])

        for link_id in range(24):
            if link_id in data['links']:
                count = data['links'][link_id]
                local_percent = (count / data['total'] * 100) if data['total'] > 0 else 0
                direction = get_link_direction(link_id)
                rows.append([
                    f"  链路 {link_id} ({direction} VC{link_id%4})",
                    count,
                    f"{local_percent:.2f}"
                ])
        rows.append([''])

    # ========== 写入CSV文件 ==========
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            for row in rows:
                f.write(','.join(str(x) for x in row) + '\n')

        print(f"\n✅ 利用率分析CSV报告生成成功: {output_file}")
        print(f"   - 总传输量: {summary['total_flits']} flits")
        print(f"   - 活跃链路: {summary['active_links']}/{summary['total_links']}")
        print(f"   - 活跃比例: {summary['active_ratio']:.2f}%")
        print(f"   - 平均每链路: {summary['avg_per_link']:.2f} flits")

        return True

    except Exception as e:
        print(f"错误: 写入CSV文件失败: {e}")
        return False


def main():
    if len(sys.argv) < 2:
        print("用法: python3 generate_utilization_csv.py <stats.txt> [output.csv] [test_name]")
        print("\n示例:")
        print("  python3 generate_utilization_csv.py stats.txt")
        print("  python3 generate_utilization_csv.py stats.txt utilization.csv backprop")
        sys.exit(1)

    stats_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else 'utilization_report.csv'
    test_name = sys.argv[3] if len(sys.argv) > 3 else 'unknown'

    success = generate_utilization_csv(stats_file, output_file, test_name)
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
generate_comprehensive_csv.py - gem5-gpu Comprehensive Performance CSV Generator

生成包含配置信息和全面性能指标的CSV报告
"""

import sys
import re
import csv
from datetime import datetime
from collections import defaultdict


class ComprehensiveGem5Parser:
    """增强型gem5统计解析器 - 提取所有性能指标"""

    def __init__(self, stats_file):
        self.stats_file = stats_file
        self.stats = {}
        self.all_router_nodes = []
        self.all_link_utils = defaultdict(dict)

    def parse(self):
        """解析stats.txt文件"""
        try:
            with open(self.stats_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#') or line.startswith('-'):
                        continue

                    # 解析统计行
                    match = re.match(r'([^\s]+)\s+([^\s#]+)', line)
                    if match:
                        stat_name = match.group(1)
                        stat_value = match.group(2)
                        self.stats[stat_name] = stat_value

                        # 收集路由器节点
                        if 'ruby.network' in stat_name and 'int_node' in stat_name:
                            router = stat_name.split('.int_node')[0]
                            if router not in self.all_router_nodes:
                                self.all_router_nodes.append(router)

                        # 收集链路利用率
                        if 'link_utilization::' in stat_name:
                            match_link = re.match(r'(.+)\.link_utilization::(\d+)', stat_name)
                            if match_link:
                                router = match_link.group(1)
                                link_id = int(match_link.group(2))
                                self.all_link_utils[router][link_id] = stat_value

        except FileNotFoundError:
            print(f"错误: 统计文件不存在: {self.stats_file}")
            sys.exit(1)
        except Exception as e:
            print(f"错误: 解析统计文件时出错: {e}")
            sys.exit(1)

    def get_stat(self, key, default='N/A'):
        """获取统计值"""
        return self.stats.get(key, default)

    def get_config_info(self):
        """提取配置信息"""
        config = {
            'sim_seconds': self.get_stat('sim_seconds'),
            'sim_ticks': self.get_stat('sim_ticks'),
            'sim_freq': self.get_stat('sim_freq'),
            'ruby_clk': self.get_stat('system.ruby_clk_domain.clock'),
            'sys_clk': self.get_stat('system.clk_domain.clock'),
        }
        return config

    def get_all_mvpp_metrics(self):
        """获取所有MVPP相关指标"""
        mvpp_metrics = {}
        for key, value in self.stats.items():
            if 'mvpp' in key.lower():
                mvpp_metrics[key] = value
        return mvpp_metrics

    def get_all_link_utilizations(self):
        """获取所有链路利用率"""
        return self.all_link_utils


class ComprehensiveCSVGenerator:
    """生成全面的CSV报告"""

    def __init__(self, parser, test_name='unknown'):
        self.parser = parser
        self.test_name = test_name
        self.timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

    def generate_comprehensive_csv(self, output_file=None):
        """生成包含所有信息的综合CSV报告"""

        if output_file is None:
            output_file = f'comprehensive_results_{self.timestamp}.csv'

        rows = []

        # ===== 第一部分：配置信息 =====
        rows.append(['========== 配置信息 ==========', ''])
        rows.append(['报告生成时间', self.timestamp])
        rows.append(['测试名称', self.test_name])
        rows.append(['', ''])

        # 系统配置
        rows.append(['--- 系统配置 ---', ''])
        rows.append(['仿真频率 (Hz)', self.parser.get_stat('sim_freq')])
        rows.append(['Ruby时钟周期 (ps)', self.parser.get_stat('system.ruby_clk_domain.clock')])
        rows.append(['系统时钟周期 (ps)', self.parser.get_stat('system.clk_domain.clock')])
        rows.append(['电压 (V)', self.parser.get_stat('system.voltage_domain.voltage')])
        rows.append(['', ''])

        # 网络拓扑配置
        rows.append(['--- 网络拓扑配置 ---', ''])
        router_count = len(self.parser.all_router_nodes)
        rows.append(['路由器节点数量', str(router_count)])

        # 提取拓扑类型
        if router_count >= 16:
            topology_type = 'Mesh 4x4 或更大'
        else:
            topology_type = f'{router_count}节点拓扑'
        rows.append(['拓扑类型', topology_type])

        # 路由算法配置
        rows.append(['路由算法', 'MVPP_MGC_PSO (Multi-Vehicle Path Planning with Multi-Group Clustering PSO)'])
        rows.append(['', ''])

        # ===== 第二部分：总体性能指标 =====
        rows.append(['========== 总体性能指标 ==========', ''])
        rows.append(['仿真时间 (秒)', self.parser.get_stat('sim_seconds')])
        rows.append(['仿真时钟周期', self.parser.get_stat('sim_ticks')])
        rows.append(['主机执行时间 (秒)', self.parser.get_stat('host_seconds')])
        rows.append(['仿真指令数', self.parser.get_stat('sim_insts')])
        rows.append(['仿真操作数', self.parser.get_stat('sim_ops')])
        rows.append(['主机指令速率 (inst/s)', self.parser.get_stat('host_inst_rate')])
        rows.append(['主机操作速率 (op/s)', self.parser.get_stat('host_op_rate')])
        rows.append(['主机时钟速率 (tick/s)', self.parser.get_stat('host_tick_rate')])
        rows.append(['', ''])

        # ===== 第三部分：MVPP_MGC_PSO路由算法性能 =====
        rows.append(['========== MVPP_MGC_PSO 路由算法性能 ==========', ''])

        # 为每个路由器节点收集MVPP统计
        for router_node in self.parser.all_router_nodes[:1]:  # 示例：第一个路由器
            # 注意：router_node 不包含 .int_node，需要添加
            node_prefix = f'{router_node}.int_node'

            rows.append([f'路由器节点', router_node])
            rows.append(['', ''])

            # 路由决策统计
            rows.append(['--- 路由决策统计 ---', ''])
            rows.append(['MVPP_MGC_PSO路由次数',
                        self.parser.get_stat(f'{node_prefix}.mvpp_mgc_pso_routing_count')])
            rows.append(['传统路由次数',
                        self.parser.get_stat(f'{node_prefix}.traditional_routing_count')])
            rows.append(['总路由次数',
                        self.parser.get_stat(f'{node_prefix}.total_routing_count')])
            rows.append(['', ''])

            # 路由时间性能
            rows.append(['--- 路由时间性能 ---', ''])
            rows.append(['MVPP_MGC_PSO路由时间 (ticks)',
                        self.parser.get_stat(f'{node_prefix}.mvpp_mgc_pso_routing_time')])
            rows.append(['传统路由时间 (ticks)',
                        self.parser.get_stat(f'{node_prefix}.traditional_routing_time')])
            rows.append(['总路由时间 (ticks)',
                        self.parser.get_stat(f'{node_prefix}.total_routing_time')])
            rows.append(['', ''])

            # 路由延迟统计
            rows.append(['--- 路由延迟统计 ---', ''])
            rows.append(['平均延迟 (ticks)',
                        self.parser.get_stat(f'{node_prefix}.mvpp_mgc_pso_routing_delay::mean')])
            rows.append(['延迟标准差 (ticks)',
                        self.parser.get_stat(f'{node_prefix}.mvpp_mgc_pso_routing_delay::stdev')])
            rows.append(['延迟几何平均 (ticks)',
                        self.parser.get_stat(f'{node_prefix}.mvpp_mgc_pso_routing_delay::gmean')])
            rows.append(['延迟样本数',
                        self.parser.get_stat(f'{node_prefix}.mvpp_mgc_pso_routing_delay::samples')])
            rows.append(['', ''])

            # 功耗统计
            rows.append(['--- 功耗统计 ---', ''])
            rows.append(['MVPP_MGC_PSO功耗 (μW·s)',
                        self.parser.get_stat(f'{node_prefix}.mvpp_mgc_pso_power_consumption')])
            rows.append(['传统路由功耗 (μW·s)',
                        self.parser.get_stat(f'{node_prefix}.traditional_power_consumption')])
            rows.append(['总功耗 (μW·s)',
                        self.parser.get_stat(f'{node_prefix}.total_power_consumption')])
            rows.append(['', ''])

        # ===== 第四部分：网络链路利用率（全部链路） =====
        rows.append(['========== 网络链路利用率（全部链路） ==========', ''])

        all_links = self.parser.get_all_link_utilizations()
        for router, links in sorted(all_links.items()):
            rows.append([f'路由器: {router}', ''])
            for link_id in sorted(links.keys()):
                utilization = links[link_id]
                rows.append([f'  链路 {link_id}', utilization])
            rows.append(['', ''])

        # ===== 第五部分：内存系统性能 =====
        rows.append(['========== 内存系统性能 ==========', ''])

        # Memory Controller 0
        rows.append(['--- Memory Controller 0 ---', ''])
        rows.append(['读取字节数', self.parser.get_stat('system.mem_ctrls0.bytes_read::total')])
        rows.append(['写入字节数', self.parser.get_stat('system.mem_ctrls0.bytes_written::total')])
        rows.append(['读取请求数', self.parser.get_stat('system.mem_ctrls0.num_reads::total')])
        rows.append(['写入请求数', self.parser.get_stat('system.mem_ctrls0.num_writes::total')])
        rows.append(['读取带宽 (bytes/s)', self.parser.get_stat('system.mem_ctrls0.bw_read::total')])
        rows.append(['写入带宽 (bytes/s)', self.parser.get_stat('system.mem_ctrls0.bw_write::total')])
        rows.append(['总带宽 (bytes/s)', self.parser.get_stat('system.mem_ctrls0.bw_total::total')])
        rows.append(['平均总线延迟 (cycles)', self.parser.get_stat('system.mem_ctrls0.avgBusLat')])
        rows.append(['平均内存访问延迟 (cycles)', self.parser.get_stat('system.mem_ctrls0.avgMemAccLat')])
        rows.append(['', ''])

        # Memory Controller 1 (if exists)
        if self.parser.get_stat('system.mem_ctrls1.bytes_read::total') != 'N/A':
            rows.append(['--- Memory Controller 1 ---', ''])
            rows.append(['读取字节数', self.parser.get_stat('system.mem_ctrls1.bytes_read::total')])
            rows.append(['写入字节数', self.parser.get_stat('system.mem_ctrls1.bytes_written::total')])
            rows.append(['读取请求数', self.parser.get_stat('system.mem_ctrls1.num_reads::total')])
            rows.append(['写入请求数', self.parser.get_stat('system.mem_ctrls1.num_writes::total')])
            rows.append(['读取带宽 (bytes/s)', self.parser.get_stat('system.mem_ctrls1.bw_read::total')])
            rows.append(['写入带宽 (bytes/s)', self.parser.get_stat('system.mem_ctrls1.bw_write::total')])
            rows.append(['总带宽 (bytes/s)', self.parser.get_stat('system.mem_ctrls1.bw_total::total')])
            rows.append(['平均总线延迟 (cycles)', self.parser.get_stat('system.mem_ctrls1.avgBusLat')])
            rows.append(['平均内存访问延迟 (cycles)', self.parser.get_stat('system.mem_ctrls1.avgMemAccLat')])
            rows.append(['', ''])

        # ===== 第六部分：功耗统计 =====
        rows.append(['========== 功耗统计 ==========', ''])
        rows.append(['Memory Controller 0 Rank 0 平均功耗 (mW)',
                    self.parser.get_stat('system.mem_ctrls0_0.averagePower')])
        rows.append(['Memory Controller 0 Rank 1 平均功耗 (mW)',
                    self.parser.get_stat('system.mem_ctrls0_1.averagePower')])

        if self.parser.get_stat('system.mem_ctrls1_0.averagePower') != 'N/A':
            rows.append(['Memory Controller 1 Rank 0 平均功耗 (mW)',
                        self.parser.get_stat('system.mem_ctrls1_0.averagePower')])
            rows.append(['Memory Controller 1 Rank 1 平均功耗 (mW)',
                        self.parser.get_stat('system.mem_ctrls1_1.averagePower')])
        rows.append(['', ''])

        # ===== 第七部分：Ruby内存系统 =====
        rows.append(['========== Ruby 内存系统 ==========', ''])
        rows.append(['CPU0指令字节读取', self.parser.get_stat('system.ruby.phys_mem.bytes_read::cpu0.inst')])
        rows.append(['CPU0数据字节读取', self.parser.get_stat('system.ruby.phys_mem.bytes_read::cpu0.data')])
        rows.append(['GPU CE字节读取', self.parser.get_stat('system.ruby.phys_mem.bytes_read::gpu.ce')])
        rows.append(['CPU0数据字节写入', self.parser.get_stat('system.ruby.phys_mem.bytes_written::cpu0.data')])
        rows.append(['GPU CE字节写入', self.parser.get_stat('system.ruby.phys_mem.bytes_written::gpu.ce')])
        rows.append(['总字节读取', self.parser.get_stat('system.ruby.phys_mem.bytes_read::total')])
        rows.append(['总字节写入', self.parser.get_stat('system.ruby.phys_mem.bytes_written::total')])
        rows.append(['', ''])

        # 写入CSV文件
        try:
            with open(output_file, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerows(rows)

            print(f"✅ 综合CSV报告生成成功: {output_file}")
            print(f"   - 配置信息: 已包含")
            print(f"   - 路由器节点数: {router_count}")
            print(f"   - 链路统计数: {sum(len(links) for links in all_links.values())}")
            print(f"   - 总行数: {len(rows)}")
            return output_file

        except Exception as e:
            print(f"错误: 写入CSV文件时出错: {e}")
            sys.exit(1)


def main():
    """主函数"""

    if len(sys.argv) < 2:
        print("用法: python3 generate_comprehensive_csv.py <stats_file> [output_csv] [test_name]")
        print("\n示例:")
        print("  python3 generate_comprehensive_csv.py /home/siat/test/stats.txt")
        print("  python3 generate_comprehensive_csv.py stats.txt results.csv backprop")
        sys.exit(1)

    stats_file = sys.argv[1]
    output_csv = sys.argv[2] if len(sys.argv) > 2 else None
    test_name = sys.argv[3] if len(sys.argv) > 3 else 'unknown'

    # 从文件名推断测试名称
    if test_name == 'unknown':
        if 'backprop' in stats_file.lower():
            test_name = 'backprop'
        elif 'kmeans' in stats_file.lower():
            test_name = 'kmeans'

    # 解析统计文件
    print(f"正在解析统计文件: {stats_file}")
    parser = ComprehensiveGem5Parser(stats_file)
    parser.parse()
    print(f"✅ 成功解析 {len(parser.stats)} 条统计数据")

    # 生成综合CSV报告
    generator = ComprehensiveCSVGenerator(parser, test_name)
    output_file = generator.generate_comprehensive_csv(output_csv)

    # 显示摘要
    config = parser.get_config_info()
    print(f"\n结果摘要:")
    print(f"  - 仿真时间: {config['sim_seconds']} 秒")
    print(f"  - 测试程序: {test_name}")
    print(f"  - CSV输出: {output_file}")


if __name__ == '__main__':
    main()

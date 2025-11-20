#!/usr/bin/env python3
"""
MVPP_MGC_PSO路由算法实现机制图
使用matplotlib绘制完整的算法架构图
"""

import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import FancyBboxPatch, ConnectionPatch
import numpy as np

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False

# 创建图形
fig, ax = plt.subplots(1, 1, figsize=(16, 12))
ax.set_xlim(0, 16)
ax.set_ylim(0, 12)
ax.axis('off')

# 颜色定义
colors = {
    'input': '#E3F2FD',      # 浅蓝色 - 输入层
    'decision': '#FFF3E0',    # 浅橙色 - 决策层
    'algorithm': '#E8F5E8',   # 浅绿色 - 算法层
    'collaboration': '#F3E5F5', # 浅紫色 - 协作层
    'output': '#FFEBEE',      # 浅红色 - 输出层
    'data': '#F5F5F5'         # 灰色 - 数据结构
}

# 绘制标题
ax.text(8, 11.5, 'MVPP_MGC_PSO路由算法实现机制', 
        fontsize=20, fontweight='bold', ha='center')

# 1. 输入层
input_box = FancyBboxPatch((0.5, 10), 3, 0.8, 
                          boxstyle="round,pad=0.1", 
                          facecolor=colors['input'], 
                          edgecolor='blue', linewidth=2)
ax.add_patch(input_box)
ax.text(2, 10.4, '数据包输入\n(Incoming Packet)', 
        fontsize=12, ha='center', va='center', fontweight='bold')

# 2. 包-粒子转换
conversion_box = FancyBboxPatch((5, 10), 3.5, 0.8, 
                               boxstyle="round,pad=0.1", 
                               facecolor=colors['algorithm'], 
                               edgecolor='green', linewidth=2)
ax.add_patch(conversion_box)
ax.text(6.75, 10.4, 'PacketParticle创建\n(4D优化空间映射)', 
        fontsize=12, ha='center', va='center', fontweight='bold')

# 3. 群体分配
group_box = FancyBboxPatch((10, 10), 4, 0.8, 
                          boxstyle="round,pad=0.1", 
                          facecolor=colors['collaboration'], 
                          edgecolor='purple', linewidth=2)
ax.add_patch(group_box)
ax.text(12, 10.4, '多群体分类(MGC)\nCPU/GPU/Memory Groups', 
        fontsize=12, ha='center', va='center', fontweight='bold')

# 4. 四层路由决策框架
decision_y = 8.5
decision_boxes = [
    ("协作路由层", "Collaborative Routing", colors['collaboration'], 0.5),
    ("全局图指导层", "Global Graph Guidance", colors['decision'], 4.5),
    ("PSO算法层", "MVPP_MGC_PSO Core", colors['algorithm'], 8.5),
    ("表路由层", "Table Routing Fallback", colors['output'], 12.5)
]

for i, (chinese, english, color, x) in enumerate(decision_boxes):
    box = FancyBboxPatch((x, decision_y), 3, 1.2, 
                        boxstyle="round,pad=0.1", 
                        facecolor=color, 
                        edgecolor='black', linewidth=1.5)
    ax.add_patch(box)
    ax.text(x + 1.5, decision_y + 0.6, f'{chinese}\n({english})', 
            fontsize=10, ha='center', va='center', fontweight='bold')

# 5. PSO核心算法详细展开
pso_y = 6.5
pso_components = [
    ("粒子初始化", "Particle Init", 1),
    ("适应度计算", "Fitness Calc", 4),
    ("速度更新", "Velocity Update", 7),
    ("位置更新", "Position Update", 10),
    ("群体协作", "Swarm Collab", 13)
]

for i, (chinese, english, x) in enumerate(pso_components):
    circle = plt.Circle((x, pso_y), 0.8, 
                       facecolor=colors['algorithm'], 
                       edgecolor='green', linewidth=2)
    ax.add_patch(circle)
    ax.text(x, pso_y, f'{chinese}\n{english}', 
            fontsize=9, ha='center', va='center', fontweight='bold')

# 6. 全局图结构
global_graph_box = FancyBboxPatch((0.5, 4.5), 6, 1.5, 
                                 boxstyle="round,pad=0.1", 
                                 facecolor=colors['data'], 
                                 edgecolor='gray', linewidth=2)
ax.add_patch(global_graph_box)
ax.text(3.5, 5.8, '全局图(GlobalGraph)', 
        fontsize=12, ha='center', fontweight='bold')
ax.text(3.5, 5.3, '• 16节点4×4网格\n• 48条双向链路\n• 实时状态监控', 
        fontsize=10, ha='center', va='center')

# 7. 群体管理器
swarm_manager_box = FancyBboxPatch((8.5, 4.5), 6, 1.5, 
                                  boxstyle="round,pad=0.1", 
                                  facecolor=colors['collaboration'], 
                                  edgecolor='purple', linewidth=2)
ax.add_patch(swarm_manager_box)
ax.text(11.5, 5.8, '群体管理器(SwarmManager)', 
        fontsize=12, ha='center', fontweight='bold')
ax.text(11.5, 5.3, '• 多群体协作\n• 知识共享\n• 粒子迁移', 
        fontsize=10, ha='center', va='center')

# 8. 多目标优化
multi_obj_box = FancyBboxPatch((2, 2.5), 12, 1.2, 
                              boxstyle="round,pad=0.1", 
                              facecolor=colors['decision'], 
                              edgecolor='orange', linewidth=2)
ax.add_patch(multi_obj_box)
ax.text(8, 3.5, '多目标适应度函数', 
        fontsize=14, ha='center', fontweight='bold')
ax.text(8, 2.9, 'F(x) = α₁·延迟 + α₂·功耗 + α₃·拥塞 + α₄·负载均衡 + α₅·可靠性 + α₆·QoS', 
        fontsize=11, ha='center', va='center')

# 9. 输出结果
output_box = FancyBboxPatch((6, 0.5), 4, 0.8, 
                           boxstyle="round,pad=0.1", 
                           facecolor=colors['output'], 
                           edgecolor='red', linewidth=2)
ax.add_patch(output_box)
ax.text(8, 0.9, '下一跳决策\n(Next-hop Decision)', 
        fontsize=12, ha='center', va='center', fontweight='bold')

# 绘制箭头连接
# 垂直主流程箭头
arrows = [
    # 主流程
    ((2, 10), (6.75, 10)),          # 输入 → 转换
    ((6.75, 10), (12, 10)),         # 转换 → 分组
    ((12, 9.2), (12, 9.7)),         # 分组 → 决策层
    ((8, 7.7), (8, 7.2)),           # 决策层 → PSO
    ((8, 5.7), (8, 3.7)),           # PSO → 多目标
    ((8, 2.5), (8, 1.3)),           # 多目标 → 输出
    
    # PSO内部流程
    ((1.8, 6.5), (3.2, 6.5)),       # 粒子初始化 → 适应度
    ((4.8, 6.5), (6.2, 6.5)),       # 适应度 → 速度更新
    ((7.8, 6.5), (9.2, 6.5)),       # 速度 → 位置更新
    ((10.8, 6.5), (12.2, 6.5)),     # 位置 → 群体协作
    
    # 全局图 → PSO
    ((3.5, 4.5), (7, 5.7)),         # 全局图 → PSO
    
    # 群体管理器 → PSO
    ((11.5, 4.5), (10, 5.7)),       # 群体管理器 → PSO
]

for start, end in arrows:
    arrow = ConnectionPatch(start, end, "data", "data",
                          arrowstyle="->", shrinkA=5, shrinkB=5,
                          mutation_scale=20, fc="black", linewidth=2)
    ax.add_patch(arrow)

# 添加决策层之间的箭头
decision_arrows = [
    ((2, 8.5), (6, 8.5)),          # 协作 → 全局图
    ((6, 8.5), (10, 8.5)),         # 全局图 → PSO
    ((10, 8.5), (14, 8.5)),        # PSO → 表路由
]

for start, end in decision_arrows:
    arrow = ConnectionPatch(start, end, "data", "data",
                          arrowstyle="->", shrinkA=5, shrinkB=5,
                          mutation_scale=20, fc="blue", linewidth=2)
    ax.add_patch(arrow)

# 添加文字标注
ax.text(15.5, 8.5, '层次化\n降级', fontsize=10, ha='center', va='center', 
        bbox=dict(boxstyle="round,pad=0.3", facecolor='yellow', alpha=0.7))

ax.text(0.5, 6.5, 'PSO\n核心\n流程', fontsize=10, ha='center', va='center',
        bbox=dict(boxstyle="round,pad=0.3", facecolor='lightgreen', alpha=0.7))

# 添加性能指标
performance_box = FancyBboxPatch((11, 0.2), 4.5, 1.4, 
                                boxstyle="round,pad=0.1", 
                                facecolor='lightcyan', 
                                edgecolor='teal', linewidth=2)
ax.add_patch(performance_box)
ax.text(13.25, 1.3, '性能提升', fontsize=12, ha='center', fontweight='bold')
ax.text(13.25, 0.8, '• 延迟降低: 33.3%\n• 功耗节省: 23.6%\n• 吞吐量提升: 14.7%', 
        fontsize=10, ha='center', va='center')

# 保存图片
plt.tight_layout()
plt.savefig('/home/siat/gem5-gpu-bak/MVPP_MGC_PSO_Implementation_Mechanism.png', 
           dpi=300, bbox_inches='tight', facecolor='white')
plt.savefig('/home/siat/gem5-gpu-bak/MVPP_MGC_PSO_Implementation_Mechanism.pdf', 
           bbox_inches='tight', facecolor='white')

print("MVPP_MGC_PSO路由算法实现机制图已生成:")
print("- PNG格式: MVPP_MGC_PSO_Implementation_Mechanism.png")
print("- PDF格式: MVPP_MGC_PSO_Implementation_Mechanism.pdf")

# 显示图形
plt.show()
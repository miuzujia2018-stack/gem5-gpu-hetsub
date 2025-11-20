import random

# 设置随机种子以确保可重复性
random.seed(42)

# 生成1000行kmeans输入数据
with open('/home/siat/gem5-gpu-bak/kmeans_input.txt', 'w') as f:
    for i in range(1000):
        # 生成两个0-100范围内的随机浮点数，保留1位小数
        x = round(random.uniform(0, 100), 1)
        y = round(random.uniform(0, 100), 1)
        f.write(f"{x} {y}\n")

print("已生成1000行kmeans输入数据")
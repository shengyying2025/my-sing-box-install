# sing-box 一键安装脚本

> ⚠️ **学习实验项目** - 仅供个人学习和研究使用

这是一个用于自动化安装和配置 sing-box 的脚本工具。

## 📋 项目说明

本项目为个人学习实验项目，代码部分使用 AI 工具辅助生成。所有代码已经过测试和验证，但仅供学习交流使用。

## ✨ 功能特性

- 🔍 自动检测系统架构和发行版
- 📦 一键安装最新版本 sing-box
- ⚙️ 自动配置系统服务
- 🚀 简单快速部署

## 💻 系统要求

- **支持的系统：** Ubuntu 20.04+, Debian 11+, CentOS 8+
- **权限要求：** 需要 root 或 sudo 权限
- **网络要求：** 需要能够访问 GitHub 和相关下载源

## 🚀 快速开始

### 在线安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/shengying2025/my-sing-box-install/main/syy-sing-box.sh)
```

### 手动下载安装

```bash
# 下载脚本
wget https://raw.githubusercontent.com/shengying2025/my-sing-box-install/main/syy-sing-box.sh

# 添加执行权限
chmod +x syy-sing-box.sh

# 运行脚本
sudo ./syy-sing-box.sh
```

## 📖 使用说明

安装完成后，可以使用以下命令管理 sing-box 服务：

```bash
# 启动服务
sudo systemctl start sing-box

# 停止服务
sudo systemctl stop sing-box

# 重启服务
sudo systemctl restart sing-box

# 查看服务状态
sudo systemctl status sing-box

# 查看日志
sudo journalctl -u sing-box -f
```

配置文件通常位于：`/etc/sing-box/config.json`

## ⚠️ 重要声明

### 使用限制

- ✅ **允许：** 个人学习、研究和实验使用
- ❌ **禁止：** 用于任何商业用途
- ❌ **禁止：** 用于违反当地法律法规的行为
- ❌ **禁止：** 未经授权的二次分发或商业化

### 关于 AI 生成内容

本项目中的部分代码使用了 AI 辅助工具（如 Claude、ChatGPT 等）协助生成。所有 AI 生成的代码均已由作者审核、测试，并对其质量和功能负责。

### 免责声明

1. **使用风险：** 本脚本按"原样"提供，不提供任何明示或暗示的保证。使用本脚本所产生的任何后果由使用者自行承担。

2. **法律合规：** 使用者必须确保其使用行为符合所在地区的法律法规。作者不对使用者的任何违法行为承担责任。

3. **数据安全：** 请勿在生产环境中使用未经充分测试的脚本。建议先在测试环境中验证。

4. **技术支持：** 本项目为个人学习项目，不提供任何形式的技术支持保证。

5. **间接损失：** 作者不对因使用本脚本导致的任何直接或间接损失承担责任，包括但不限于数据丢失、服务中断、经济损失等。

## 🔧 常见问题

**Q: 安装失败怎么办？**  
A: 请检查系统是否满足要求，查看错误日志，或在 Issues 中反馈问题。

**Q: 支持哪些系统？**  
A: 目前主要支持基于 Debian 和 Red Hat 的主流 Linux 发行版。

**Q: 如何卸载？**  
A: 可以手动停止服务并删除相关文件，或等待后续版本添加卸载功能。

**Q: 可以用于商业项目吗？**  
A: 不可以，本项目仅供个人学习使用。

## 📝 版权说明

Copyright © 2024 shengying2025. All rights reserved.

本项目代码版权归作者所有。未经明确授权，禁止将本项目用于商业用途或进行二次分发。

## 🤝 贡献

由于这是一个个人学习项目，暂不接受外部贡献。如有问题或建议，欢迎通过 Issues 反馈。

## 📮 反馈与联系

如遇到问题或有任何建议，请通过以下方式反馈：

- 提交 [GitHub Issue](https://github.com/shengying2025/my-sing-box-install/issues)
- 在仓库中发起 Discussion

---

**最后提醒：请确保遵守所在地区的法律法规，合理合法使用本工具。**

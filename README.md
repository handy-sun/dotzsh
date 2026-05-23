# dotzsh

虽然项目名称带zsh， 但是这是一套个人向 zsh、fish、bash 的 shell 配置文件集，通过 Nix Flake + home-manager 分发，也支持独立使用。

## 目录结构

```
.
├── flake.nix              # Nix Flake：homeManagerModules + packages + devshell
├── zshrc                  # Zsh 入口（由 home-manager 或手动 source）
├── zsh-config.zsh         # Zsh 选项、按键绑定、补全、提示符、钩子
├── common.sh.in           # 模板 → 生成 common.sh（bash/zsh 共用 alias 和函数）
├── common.fish.in         # 模板 → 生成 common.fish（fish 共用 alias、函数、tide 辅助）
├── plugins/               # 内置 zsh 插件（git submodule 或 vendor）
│   ├── fast-syntax-highlighting/
│   ├── zsh-autosuggestions/
│   ├── zsh-history-substring-search/
│   └── zsh-syntax-highlighting/
├── plugsfile/             # 小型 zsh 插件片段（自动加载）
│   ├── colored-man-pages.plugin.zsh
│   ├── copypath.plugin.zsh
│   ├── docker-compose.plugin.zsh
│   └── zsh-copybuffer.plugin.zsh
└── scripts/
    └── newuser            # Zsh 新用户引导脚本 （基本废弃）
```

## 安装

### 方式一：Nix Flake + home-manager（推荐）

在 `flake.nix` 中添加 dotzsh 作为 input：

```nix
{
  inputs = {
    dotzsh.url = "github:handy/dotzsh";
    # ... 其他 inputs
  };
}
```

然后在 home-manager 模块中导入并启用：

```nix
{
  imports = [ dotzsh.homeManagerModules.default ];

  programs.dotzsh = {
    enable = true;
    enableZshIntegration = true;   # 启用 zsh 集成
    enableFishIntegration = true;  # 启用 fish 集成 （如果用了tide插件，则会覆盖其提示符）
    enableFishPrompt = true;       # 使用自定义 fish 提示符
    fishGreetingMode = "custom";   # fish 欢迎语模式提供NixOS相应信息
  };
}
```

### 方式二：独立使用（非 Nix 环境）

```bash
# 克隆仓库
git clone https://github.com/handy/dotzsh.git ~/dotzsh

# zsh — 在 ~/.zshrc 中添加
source ~/dotzsh/zshrc

# fish — 生成 common.fish 并 source
cd ~/dotzsh && bash common.fish.in -1
echo 'source ~/.cache/dotzsh/common.fish' >> ~/.config/fish/config.fish

# bash — 生成 common.sh 并 source
cd ~/dotzsh && bash common.sh.in -1
echo 'source ~/.cache/dotzsh/common.sh' >> ~/.bashrc
```

生成脚本的 `-1` 选项会将输出写入 `~/.cache/dotzsh/`；也可用 `-2`（当前目录）、`-3`（`/tmp/`）、`-0`（stdout）。

## 配置选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enable` | bool | `false` | 总开关 |
| `enableZshIntegration` | bool | `false` | 将 `zshrc` 注入到 `programs.zsh.initContent`（排序 1200） |
| `enableFishIntegration` | bool | `false` | 将生成的 `common.fish` 注入到 `programs.fish.shellInitLast` |
| `enableFishPrompt` | bool | `false` | 启用自定义 `fish_prompt` 和 `fish_right_prompt`（含 SHLVL、代理指示等功能） |
| `fishGreetingMode` | `null` / `"empty"` / `"custom"` | `null` | fish 欢迎语：`null` = fish 默认，`empty` = 禁用，`custom` = dotzsh 的 Nix 感知问候语 |

## 主要功能

### Zsh

- **插件**：自动加载 fast-syntax-highlighting、zsh-autosuggestions
- **补全**：大小写不敏感、彩色补全列表、菜单选择、缓存加速
- **提示符**：彩色双行提示符，含路径缩短、git 状态、上条命令耗时、后台任务数
- **按键绑定**：Home/End/Delete、Ctrl+←→ 按词跳转、Esc Esc 插入 sudo、Alt+O 返回上级目录
- **选项**：自动纠错、扩展通配符、自动 cd、历史去重

### Fish

- **共享函数**：与 bash/zsh 保持功能一致的 fish 实现（详见下方函数表）
- **tide 集成**：提供 `dotzsh_tide` 命令来管理 tide 提示符项
- **代理指示**：自定义 tide item `proxy`，检测到 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` 时显示 🌐 图标
- **自定义提示符**（`enableFishPrompt` 模式下）：彩色双行提示符，含 SHLVL 层级显示、代理状态前缀

### 共享函数（bash / zsh / fish）

| 函数 | 用途 |
|------|------|
| `fwh` | 追溯命令来源（别名 → 函数 → 可执行文件 → 符号链接） |
| `gaa` / `groa` / `grga` | 从仓库根目录执行 git add / restore / staged-restore |
| `gitur` | git add + commit + pull --rebase + push 所有远程 |
| `gcldi` | 交互式清理未跟踪文件 |
| `cdt` | cd 到文件所在目录 |
| `upd N` | 向上跳 N 级目录 |
| `swap2file` | 交换两个文件 |
| `dkex` | 进入 docker 容器并自动选择最佳可用 shell |
| `htdel` | 按模式删除历史条目 |
| `dus` | 排序的磁盘使用量 |
| `qip` | 查询 IP 地理位置（需 jq） |
| `ppre` | 搜索进程（`ps -ef | grep -i`） |
| `shpo` / `shap` / `shsw` / `shdr` | 按索引操作 git stash（pop / apply / show / drop） |

## tide 提示符管理

启用 fish 集成后，可使用 `dotzsh_tide` 命令管理 tide 提示符布局：

```fish
# 配置风格
dotzsh_tide rainbow       # Rainbow 风格（默认）
dotzsh_tide lean          # Lean 风格

# 管理右侧提示项
dotzsh_tide ar shlvl proxy  # 添加右侧提示项
dotzsh_tide remove-right <item>  # 移除指定项
dotzsh_tide reset-right   # 重置右侧为默认布局

# 管理左侧提示项
dotzsh_tide remove-left <item>   # 移除指定项
dotzsh_tide reset-rainbow-left   # 重置左侧为默认布局

# 其他
dotzsh_tide set-vi-icon        # vi 模式图标设为 →
dotzsh_tide transient-on       # 启用瞬态提示符
dotzsh_tide transient-off      # 禁用瞬态提示符
```

## 自定义扩展

### localpre / localpost

在以下目录中放置 `.sh`（zsh/bash）或 `.fish`（fish）文件，会在加载时自动 source：

| 优先级 | Zsh/Bash | Fish |
|--------|----------|------|
| 1 | `./localpre/` | `./localpre/` |
| 2 | `~/.cache/dotzsh/localpre/` | `~/.cache/dotzsh/localpre/` |
| 3 | `/tmp/localpre/` | `/tmp/localpre/` |

`localpost` 同理，在配置加载末尾执行。会按优先级依次查找，使用第一个存在的目录。

## 开发

```bash
# 进入开发环境
nix develop

# 重新生成 common.sh
cm-init -2       # 输出到当前目录

# 重新生成 common.fish
fish-init -2gp   # 输出到当前目录，含问候语和自定义提示符

# 测试 zsh 配置（不安装）
zsh -d -f -c "source ./zshrc"

# 检查模板语法
bash -n common.sh.in
bash -n common.fish.in
```

### 添加新别名或函数

1. 同时在 `common.sh.in` 和 `common.fish.in` 中添加（保持功能对等）
2. 如果依赖外部工具，用 `_dotzsh_cmd_exists <tool>` 守卫
3. 平台差异代码用 `_dotzsh_is_linux` / `else` 分支
4. 放在对应功能区域（git、docker、tar、包管理等）

### 提交规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：`type(scope): subject`

- **类型**：feat、fix、refactor、docs、style、chore
- **主题**：小写英文，句末不加句号

## License

MIT

import os.path

# 绝对路径，避免工作目录问题
APP = os.path.abspath("GameCenter.app")
BG = os.path.abspath("Assets/dmg/background.png")

volume_name = "GameCenter"
format = "UDZO"
size = "120m"

# 背景图与窗口（dmgbuild 使用 window_rect，不是 window）
background = BG
window_rect = ((400, 100), (660, 420))
icon_size = 128
text_size = 14
show_icon_preview = False

# 内容：app 本体 + 应用程序快捷方式
files = [APP]
symlinks = {"Applications": "/Applications"}

# 图标位置（与背景箭头对齐）
icon_locations = {
    "GameCenter.app": (150, 232),
    "Applications": (510, 232),
}

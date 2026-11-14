# M09 贪吃蛇　B　依赖 G01、G03

来源：2026-11-07 架构审查及其最后实施记录。整理日期：2026-11-14。下列待办保留原状态；实施前核对本包源码与工作区，不以历史检查代替本次验收。

[共享 G01–G03 任务](../../../protocols/godot_party_default_protocol/doc/godot_party_default_protocol_development.md) · [包说明](gp_snake_guide.md)


包：`gp_snake`。定位：[game.gd](../game.gd)、[sound_bank.gd](../sound_bank.gd)、`board_view.gd`。

- [ ] 用 Cue 与作用域声音池替换四个动态播放器；将 `_tone()` 中明确的数值/数组/播放器 Variant 改成具体类型。保留现有音色。
- [ ] 速度枚举和必需配置使用已校验的配置，不再把未知值静默变成“标准”；状态与排行榜的中文拼接转为命名模板。
- [ ] 保留 model/view/entry 分层、动态蛇身和食物。当前 `api.input.event_matches()` 自带输入许可检查，不能仅因入口没有手写 `input_blocked` 就认定漏门控。

验证：变向、死亡/胜利声音、菜单后输入恢复、本地进度上报与最终成绩。

## 人工验收待办

保留自 2026-11-05 场景审查，后续记录未明确关闭的人工事项：多人操作待人工验收。

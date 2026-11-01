## Business-owned setting defaults, constraints and UI hierarchy. No runtime side effects.
extends RefCounted

static func schema() -> Dictionary:
	return {
		"schema_format": 3,
		"settings_version": 1,
		"fields": {
			"duration": {
				"type": "int",
				"default": 120,
				"title": "比赛时限（秒）",
				"audience": "room",
				"apply": "next_round",
				"min": 30,
				"max": 600,
				"control": "number"
			},
			"move_left": {
				"type": "array",
				"action": "move_left",
				"default": [
					{
						"kind": "key",
						"code": 65,
						"physical": true
					},
					{
						"kind": "key",
						"code": 4194319,
						"physical": true
					}
				],
				"title": "向左",
				"audience": "local",
				"apply": "immediate",
				"control": "binding",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2
			},
			"move_right": {
				"type": "array",
				"action": "move_right",
				"default": [
					{
						"kind": "key",
						"code": 68,
						"physical": true
					},
					{
						"kind": "key",
						"code": 4194321,
						"physical": true
					}
				],
				"title": "向右",
				"audience": "local",
				"apply": "immediate",
				"control": "binding",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2
			},
			"move_up": {
				"type": "array",
				"action": "move_up",
				"default": [
					{
						"kind": "key",
						"code": 87,
						"physical": true
					},
					{
						"kind": "key",
						"code": 4194320,
						"physical": true
					}
				],
				"title": "向上",
				"audience": "local",
				"apply": "immediate",
				"control": "binding",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2
			},
			"move_down": {
				"type": "array",
				"action": "move_down",
				"default": [
					{
						"kind": "key",
						"code": 83,
						"physical": true
					},
					{
						"kind": "key",
						"code": 4194322,
						"physical": true
					}
				],
				"title": "向下",
				"audience": "local",
				"apply": "immediate",
				"control": "binding",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2
			},
			"speed": {
				"type": "string",
				"default": "标准",
				"values": [
					"舒缓",
					"标准",
					"高速"
				],
				"title": "速度档位",
				"audience": "room",
				"apply": "next_round",
				"control": "select"
			},
			"sound": {
				"type": "bool",
				"default": true,
				"title": "音效",
				"audience": "local",
				"apply": "immediate",
				"control": "toggle"
			}
		},
		"layout": [
			{
				"id": "room",
				"title": "游戏规则",
				"expanded": true,
				"children": [
					{
						"field": "duration"
					},
					{
						"field": "speed"
					}
				]
			},
			{
				"id": "local",
				"title": "本机偏好",
				"expanded": true,
				"children": [
					{
						"field": "move_left"
					},
					{
						"field": "move_right"
					},
					{
						"field": "move_up"
					},
					{
						"field": "move_down"
					},
					{
						"field": "sound"
					}
				]
			}
		]
	}

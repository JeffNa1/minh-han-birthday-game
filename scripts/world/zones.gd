extends RefCounted
## The festival map: side-scrolling areas joined by staircases at their ends.
## Each exit sits at `x`; walking into it arrives in `to` at `arrive_x`.
## GROUND_* bound the body origin of walkers (their feet stand 55px lower).

const GROUND_TOP := 318.0
const GROUND_BOTTOM := 468.0

static var ZONES := {
	"courtyard": {"name": "Sân trường lễ hội", "floor": "Tầng 1", "width": 2240.0,
		"exits": [{"x": 2170.0, "to": "hallway", "arrive_x": 1880.0, "dir": "up", "label": "Lên tầng 2"}]},
	"hallway": {"name": "Hành lang lớp học", "floor": "Tầng 2", "width": 2000.0,
		"exits": [{"x": 1935.0, "to": "courtyard", "arrive_x": 2060.0, "dir": "down", "label": "Xuống sân trường"},
			{"x": 65.0, "to": "rooftop", "arrive_x": 170.0, "dir": "up", "label": "Lên sân thượng"}]},
	"rooftop": {"name": "Sân thượng", "floor": "Tầng 3", "width": 1700.0,
		"exits": [{"x": 70.0, "to": "hallway", "arrive_x": 180.0, "dir": "down", "label": "Xuống tầng 2"}]},
}

static var ORDER := ["courtyard", "hallway", "rooftop"]

const LEVEL_COUNT := 10
const RIVALS := ["rival", "emo", "bikini", "rival_b", "catgirl", "librarian", "rival_c", "yandere", "singer", "elegant", "actress"]
const TITLES := ["Lễ hội bắt đầu", "Đối thủ xuất hiện", "Cô quản lý để mắt", "Hành lang nhộn nhịp", "Đêm hội tình yêu",
	"Tranh giành gắt gao", "Ánh mắt khắp nơi", "Sân thượng lộng gió", "Trái tim thử thách", "Nữ hoàng lễ hội"]

## Level plan for index n (0-based). Every step adds pressure: shorter clocks, faster heart drain,
## more and quicker rivals, sharper-eyed managers who give chase, and boys who keep walking
## while beamed so the pointer has to track them.
static func level(n: int) -> Dictionary:
	var rivals: Array = []
	for i in range(mini(1 + n / 2, 5)):
		rivals.append([RIVALS[(n * 3 + i * 5) % RIVALS.size()], ORDER[i % 3]])
	var managers: Array = []
	for i in range(mini(1 + (n + 1) / 3, 4)):
		managers.append(["hallway", "courtyard", "rooftop"][i % 3])
	return {
		"title": "Màn %d · %s" % [n + 1, TITLES[n % TITLES.size()]],
		"time": maxf(80.0, 110.0 - n * 3.0),
		"drain": maxf(5.0, 15.0 - n * 1.1),
		"boys": {"courtyard": 4, "hallway": 3 + int(n > 2), "rooftop": 2 + int(n > 4)},
		"rivals": rivals,
		"managers": managers,
		"rival_speed": 1.0 + n * 0.08,
		"rival_charm": maxf(0.55, 1.0 - n * 0.05),
		"rival_reach": 420.0 + n * 35.0,
		"clash_push": 40.0,
		# Managers were eased by 20%: shorter sight and slower patrols and chases.
		"manager_sight": minf(380.0, 240.0 + n * 16.0) * 0.8,
		"manager_speed": (55.0 + n * 5.0) * 0.8,
		"manager_chase": n >= 1,
		"boy_resist": 1.0 + n * 0.12,
		"boy_evasive": n >= 2,
		"tier3": minf(0.25, 0.1 + n * 0.015),
	}

extends RefCounted
## Everything Minh Hân can own: outfits, hairstyles and love-beam styles, with shop prices.
## Prices are {"coin": n} or {"gem": n}.

const Wardrobe := preload("res://scripts/art/wardrobe.gd")

const KINDS := ["outfit", "hair", "hat", "wings", "aura", "pet", "beam"]
const DEFAULTS := {"outfit": "pajamas", "hair": "long", "hat": "none", "wings": "none", "aura": "none", "pet": "none", "beam": "heart"}
## Gear slots may be left empty ("none"); it is owned from the start and never sold.
const OPTIONAL := ["hat", "wings", "aura", "pet"]

## Wearable extras and companions. `special` marks the showpieces priced in many diamonds.
static var GEAR := {
	"hat": {"none": {"name": "Không đội"}, "cat_ears": {"name": "Tai mèo hồng"}, "bunny_ears": {"name": "Tai thỏ"},
		"flower_crown": {"name": "Vòng hoa"}, "tiara_silver": {"name": "Tiara bạc"}, "star_tiara": {"name": "Tiara sao"},
		"bow_big": {"name": "Nơ khổng lồ"}, "headphones": {"name": "Tai nghe mèo"}, "witch_hat": {"name": "Mũ phù thủy"},
		"top_hat": {"name": "Mũ chóp mini"}, "halo": {"name": "Vầng hào quang", "special": true},
		"crown_royal": {"name": "Vương miện hoàng gia", "special": true}, "veil": {"name": "Khăn voan cô dâu", "special": true}},
	"wings": {"none": {"name": "Không cánh"}, "heart": {"name": "Cánh trái tim"}, "angel": {"name": "Cánh thiên thần"},
		"fairy": {"name": "Cánh tiên"}, "butterfly": {"name": "Cánh bướm"}, "bat": {"name": "Cánh dơi"},
		"crystal": {"name": "Cánh pha lê", "special": true}, "galaxy": {"name": "Cánh ngân hà", "special": true},
		"phoenix": {"name": "Cánh phượng hoàng", "special": true}},
	"aura": {"none": {"name": "Không hào quang"}, "sparkle": {"name": "Lấp lánh"}, "hearts": {"name": "Tim bay"},
		"petals": {"name": "Cánh hoa"}, "bubbles": {"name": "Bong bóng"}, "music": {"name": "Nốt nhạc"},
		"rainbow": {"name": "Cầu vồng", "special": true}, "starfall": {"name": "Mưa sao băng", "special": true},
		"halo_light": {"name": "Hào quang thánh", "special": true}},
	"pet": {"none": {"name": "Không thú cưng"}, "kitten": {"name": "Mèo cam"}, "puppy": {"name": "Cún shiba"},
		"bunny": {"name": "Thỏ bông"}, "hamster": {"name": "Hamster"}, "chick": {"name": "Gà con"}, "panda": {"name": "Gấu trúc"},
		"unicorn": {"name": "Kỳ lân cầu vồng", "special": true}, "dragon": {"name": "Rồng tí hon", "special": true},
		"star_spirit": {"name": "Tinh linh sao", "special": true}},
}

static var BEAMS := {
	"heart": {"name": "Tim hồng", "main": Color("ff4f8b"), "soft": Color("ffd3e2"), "shape": "heart"},
	"sakura": {"name": "Hoa anh đào", "main": Color("ff8fb8"), "soft": Color("fff0f6"), "shape": "petal"},
	"star": {"name": "Sao lấp lánh", "main": Color("ffae34"), "soft": Color("fff0b0"), "shape": "star"},
	"bubble": {"name": "Bong bóng", "main": Color("4cc3f0"), "soft": Color("e0f7ff"), "shape": "bubble"},
	"melody": {"name": "Giai điệu", "main": Color("2fc79a"), "soft": Color("d9fff0"), "shape": "note"},
	"flame": {"name": "Lửa tình", "main": Color("ff5a3c"), "soft": Color("ffd28a"), "shape": "heart"},
	"rainbow": {"name": "Cầu vồng", "main": Color("ff6fae"), "soft": Color("ffffff"), "shape": "star", "rainbow": true},
}

static var PRICES := {
	"outfit": {"christmas": {"gem": 25}, "white_dress": {"gem": 25}, "bomber": {"gem": 25}, "black_crop": {"gem": 25},
		"aodai": {"gem": 45}, "yukata": {"gem": 45}, "sailor": {"gem": 35}, "princess": {"gem": 60}, "idol": {"gem": 40},
		"overall": {"gem": 35}, "sweater": {"gem": 35}, "sundress": {"gem": 40}, "magical": {"gem": 50}, "gala": {"gem": 60},
		"offshoulder": {"gem": 35}, "aodai_modern": {"gem": 50}, "lace_plaid": {"gem": 45}, "uniform": {"gem": 35},
		"floral_cami": {"gem": 40}, "polka_cami": {"gem": 35}, "polka_blouse": {"gem": 35},
		"street_chic": {"gem": 45}, "tennis": {"gem": 35}, "y2k": {"gem": 40}, "office_chic": {"gem": 40},
		"tweed": {"gem": 60}, "satin_slip": {"gem": 60}, "qipao": {"gem": 55}, "velvet": {"gem": 65},
		"punk": {"gem": 45}, "gothic": {"gem": 55}, "cyber": {"gem": 50}, "rocker": {"gem": 45},
		"gown_royal": {"gem": 260}, "gown_sakura": {"gem": 220}, "gown_starlight": {"gem": 280}, "gown_bride": {"gem": 240}, "gown_phoenix": {"gem": 300}},
	"hair": {"layered": {"coin": 600}, "bob": {"coin": 450}, "ponytail": {"coin": 500}, "twin": {"coin": 650}, "bun": {"coin": 450},
		"wavy": {"coin": 700}, "spacebuns": {"coin": 800}, "emo": {"coin": 700}},
	"hat": {"cat_ears": {"coin": 500}, "bunny_ears": {"coin": 500}, "flower_crown": {"coin": 650}, "tiara_silver": {"gem": 20},
		"star_tiara": {"gem": 30}, "bow_big": {"coin": 400}, "headphones": {"coin": 600}, "witch_hat": {"coin": 700},
		"top_hat": {"coin": 550}, "halo": {"gem": 90}, "crown_royal": {"gem": 150}, "veil": {"gem": 110}},
	"wings": {"heart": {"coin": 900}, "angel": {"gem": 40}, "fairy": {"gem": 35}, "butterfly": {"coin": 1200}, "bat": {"coin": 1100},
		"crystal": {"gem": 160}, "galaxy": {"gem": 200}, "phoenix": {"gem": 250}},
	"aura": {"sparkle": {"coin": 800}, "hearts": {"coin": 700}, "petals": {"coin": 900}, "bubbles": {"coin": 700}, "music": {"coin": 800},
		"rainbow": {"gem": 120}, "starfall": {"gem": 150}, "halo_light": {"gem": 180}},
	"pet": {"kitten": {"coin": 1000}, "puppy": {"coin": 1000}, "bunny": {"coin": 1100}, "hamster": {"coin": 900}, "chick": {"coin": 800},
		"panda": {"gem": 45}, "unicorn": {"gem": 200}, "dragon": {"gem": 240}, "star_spirit": {"gem": 180}},
	"beam": {"sakura": {"coin": 600}, "star": {"coin": 700}, "bubble": {"coin": 700}, "melody": {"coin": 800},
		"flame": {"coin": 900}, "rainbow": {"gem": 30}},
}

static func ids(kind: String) -> Array:
	match kind:
		"outfit": return Wardrobe.ids_for("minh_han")
		"hair": return Wardrobe.HAIRS.keys()
		"beam": return BEAMS.keys()
		_: return GEAR[kind].keys()

static func item_name(kind: String, id: String) -> String:
	match kind:
		"outfit": return Wardrobe.OUTFITS[id]["name"]
		"hair": return Wardrobe.HAIRS[id]["name"]
		"beam": return BEAMS[id]["name"]
		_: return GEAR[kind][id]["name"]

## Showpieces: full-set gowns and the special wings, auras, hats and pets.
static func is_special(kind: String, id: String) -> bool:
	if kind == "outfit":
		return Wardrobe.OUTFITS[id].has("set")
	return kind in GEAR and GEAR[kind][id].get("special", false)

static func price(kind: String, id: String) -> Dictionary:
	return PRICES[kind].get(id, {})

static func kind_label(kind: String) -> String:
	return {"outfit": "Trang phục", "hair": "Kiểu tóc", "hat": "Mũ & tiara", "wings": "Cánh", "aura": "Hào quang", "pet": "Thú cưng", "beam": "Tia tình yêu"}[kind]

extends RefCounted
## Original NightGrid colorways over the existing weighted garment materials.
## No new body, geometry, skeleton, texture or collision assets.
const Economy = preload("res://scripts/economy.gd")
const DEFAULT = "dispatch"
const IDS = ["dispatch","tideline","rustline","quay_basic","vesper_tailored","nocturne_atelier","obscura_signature","threadline_basics","night_shift","quay_dock","vesper_ink","nocturne_veil","obscura_sable","signal_reclaimed","signal_rivet","signal_static","signal_union","threadline_concrete","threadline_copper","threadline_rain","quay_breakwater","quay_forge","quay_silt","vesper_meridian","vesper_oxblood","vesper_pearl","nocturne_afterimage","nocturne_eclipse","nocturne_ember","obscura_archivist","obscura_porcelain","obscura_monolith","signal_overprint","signal_scrapyard","signal_deadstock"]
const ITEMS = {
	"dispatch":{"name":"Morrow Dispatch","rarity":"COMMON","tier":0,"price":45,"jacket":Color.WHITE,"pants":Color.WHITE,"finish":1.0},
	"tideline":{"name":"Tideline","rarity":"COMMON","tier":0,"price":35,"jacket":Color(.55,.88,1.0),"pants":Color(.65,.83,.95),"finish":1.0},
	"rustline":{"name":"Rustline","rarity":"COMMON","tier":0,"price":45,"jacket":Color(1.0,.72,.48),"pants":Color(.92,.80,.65),"finish":1.0},
	"quay_basic":{"name":"Quay Standard / Streetwear","rarity":"UNCOMMON","tier":1,"price":75,"jacket":Color(.90,.72,1.0),"pants":Color(.75,.74,.90),"finish":.94},
	"vesper_tailored":{"name":"Vesper Line / Tailored","rarity":"RARE","tier":2,"price":300,"jacket":Color(.74,1.0,.80),"pants":Color(.52,.60,.55),"finish":.82},
	"nocturne_atelier":{"name":"Nocturne Atelier / Midnight","rarity":"LUXURY","tier":3,"price":950,"jacket":Color(.46,.48,.76),"pants":Color(.40,.42,.55),"finish":.70},
	"obscura_signature":{"name":"Obscura / Signature Edition","rarity":"EXCLUSIVE","tier":4,"price":2400,"jacket":Color(1.0,.59,.82),"pants":Color(.48,.38,.46),"finish":.62},
	"threadline_basics":{"name":"Threadline / Everyday","rarity":"COMMON","tier":0,"price":20,"jacket":Color(.78,.81,.76),"pants":Color(.80,.81,.78),"finish":1.0},
	"night_shift":{"name":"Threadline / Night Shift","rarity":"UNCOMMON","tier":1,"price":65,"jacket":Color(.62,.73,.86),"pants":Color(.48,.53,.64),"finish":.90},
	"quay_dock":{"name":"Quay Standard / Dock Canvas","rarity":"UNCOMMON","tier":1,"price":85,"jacket":Color(.75,.88,.65),"pants":Color(.58,.68,.55),"finish":1.0},
	"vesper_ink":{"name":"Vesper Line / Ink","rarity":"RARE","tier":2,"price":360,"jacket":Color(.50,.59,.83),"pants":Color(.45,.48,.66),"finish":.84},
	"nocturne_veil":{"name":"Nocturne / Violet Veil","rarity":"LUXURY","tier":3,"price":620,"jacket":Color(.82,.49,.94),"pants":Color(.43,.35,.56),"finish":.70},
	"obscura_sable":{"name":"Obscura / Sable Collection","rarity":"EXCLUSIVE","tier":4,"price":1800,"jacket":Color(.44,.43,.46),"pants":Color(.48,.44,.41),"finish":.62},
	"signal_reclaimed":{"name":"Second Signal / Reclaimed","rarity":"SECONDHAND","tier":0,"price":8,"jacket":Color(.69,.68,.57),"pants":Color(.61,.66,.60),"finish":1.0},
	"signal_rivet":{"name":"Second Signal / Rivet","rarity":"ROTATING FIND","tier":0,"price":17,"jacket":Color(.88,.48,.36),"pants":Color(.45,.46,.47),"finish":.96},
	"signal_static":{"name":"Second Signal / Static","rarity":"ROTATING FIND","tier":0,"price":14,"jacket":Color(.68,.49,.88),"pants":Color(.60,.54,.70),"finish":1.0},
	"signal_union":{"name":"Second Signal / Union Surplus","rarity":"ROTATING FIND","tier":0,"price":12,"jacket":Color(.69,.84,.47),"pants":Color(.76,.70,.51),"finish":1.0},
	"threadline_concrete":{"name":"Threadline / Concrete","rarity":"COMMON","tier":0,"price":29,"jacket":Color(.68,.71,.74),"pants":Color(.57,.60,.63),"finish":1,"detail":"Cool grey everyday set"},
	"threadline_copper":{"name":"Threadline / Copper Hour","rarity":"COMMON","tier":0,"price":39,"jacket":Color(.92,.62,.43),"pants":Color(.52,.52,.56),"finish":0.95,"detail":"Copper and slate street colors"},
	"threadline_rain":{"name":"Threadline / Rain City","rarity":"UNCOMMON","tier":1,"price":68,"jacket":Color(.53,.71,.82),"pants":Color(.48,.58,.70),"finish":0.88,"detail":"Muted blue, satin finish"},
	"quay_breakwater":{"name":"Quay / Breakwater","rarity":"UNCOMMON","tier":1,"price":88,"jacket":Color(.47,.68,.70),"pants":Color(.58,.65,.65),"finish":0.98,"detail":"Sea-green industrial palette"},
	"quay_forge":{"name":"Quay / Forge Shift","rarity":"UNCOMMON","tier":1,"price":95,"jacket":Color(.88,.65,.39),"pants":Color(.46,.49,.51),"finish":1,"detail":"Amber and charcoal work colors"},
	"quay_silt":{"name":"Quay / Silt","rarity":"COMMON","tier":0,"price":48,"jacket":Color(.77,.73,.58),"pants":Color(.65,.60,.48),"finish":1,"detail":"Dusty earth tones"},
	"vesper_meridian":{"name":"Vesper / Meridian","rarity":"RARE","tier":2,"price":320,"jacket":Color(.62,.66,.76),"pants":Color(.44,.48,.59),"finish":0.79,"detail":"Slate blue refined finish"},
	"vesper_oxblood":{"name":"Vesper / Oxblood","rarity":"RARE","tier":2,"price":410,"jacket":Color(.68,.37,.41),"pants":Color(.46,.42,.46),"finish":0.75,"detail":"Wine-red evening palette"},
	"vesper_pearl":{"name":"Vesper / Pearl","rarity":"RARE","tier":2,"price":385,"jacket":Color(.92,.89,.82),"pants":Color(.72,.70,.68),"finish":0.84,"detail":"Pale neutral tonal set"},
	"nocturne_afterimage":{"name":"Nocturne / Afterimage","rarity":"LUXURY","tier":3,"price":690,"jacket":Color(.49,.80,.87),"pants":Color(.35,.43,.55),"finish":0.68,"detail":"Icy cyan and deep blue"},
	"nocturne_eclipse":{"name":"Nocturne / Eclipse","rarity":"LUXURY","tier":3,"price":780,"jacket":Color(.45,.38,.58),"pants":Color(.36,.35,.46),"finish":0.65,"detail":"Dark violet low sheen"},
	"nocturne_ember":{"name":"Nocturne / Ember","rarity":"LUXURY","tier":3,"price":820,"jacket":Color(.94,.43,.54),"pants":Color(.45,.36,.43),"finish":0.72,"detail":"Crimson nightlife palette"},
	"obscura_archivist":{"name":"Obscura / Archivist","rarity":"EXCLUSIVE","tier":4,"price":1650,"jacket":Color(.67,.63,.55),"pants":Color(.43,.42,.40),"finish":0.64,"detail":"Warm stone and graphite"},
	"obscura_porcelain":{"name":"Obscura / Porcelain","rarity":"EXCLUSIVE","tier":4,"price":2150,"jacket":Color(.95,.92,.88),"pants":Color(.72,.71,.73),"finish":0.6,"detail":"Pale monochrome collection"},
	"obscura_monolith":{"name":"Obscura / Monolith","rarity":"EXCLUSIVE","tier":4,"price":2800,"jacket":Color(.35,.39,.46),"pants":Color(.35,.37,.41),"finish":0.58,"detail":"Graphite signature finish"},
	"signal_overprint":{"name":"Second Signal / Overprint","rarity":"ROTATING FIND","tier":0,"price":15,"jacket":Color(.79,.46,.58),"pants":Color(.56,.58,.66),"finish":1,"detail":"Faded rose and slate"},
	"signal_scrapyard":{"name":"Second Signal / Scrapyard","rarity":"ROTATING FIND","tier":0,"price":11,"jacket":Color(.73,.72,.43),"pants":Color(.57,.60,.50),"finish":1,"detail":"Worn olive and mustard"},
	"signal_deadstock":{"name":"Second Signal / Deadstock","rarity":"ROTATING FIND","tier":0,"price":19,"jacket":Color(.46,.65,.83),"pants":Color(.60,.64,.71),"finish":0.95,"detail":"Washed blue deadstock colors"}
}

# Catalog values are estimated 2026 USD anchors, not final shelf prices.
static func price(id: String) -> int:
	return Economy.price_2036(int(ITEMS[id]["price"])) if valid_id(id) else 0

static func valid_id(value: Variant) -> bool:
	return value is String and ITEMS.has(value)

static func garment_slot(name: String) -> String:
	var normalized := name.to_lower()
	if normalized.contains("jacket"):
		return "jacket"
	if normalized.contains("cargo") or normalized.contains("pants"):
		return "pants"
	return ""

# Individual material-compatible pieces. Future mesh pieces use the same
# stable slot/item identities, with a separate validated visual asset contract.
const SLOTS=["jacket","pants","glasses","watch","patch","hat"]
const RESET_IDS=["reset_jacket","reset_pants","reset_glasses","reset_watch","reset_patch","reset_hat"]
const PIECE_IDS=["jacket_ash","jacket_oxide","jacket_midnight","pants_charcoal","pants_sand","pants_teal","glasses_night","glasses_clear","watch_shift","watch_brass","jacket_ink","jacket_patch","jacket_signal","pants_salvage","pants_indigo","patch_deadcarrier","patch_voltage","patch_ghostshift","patch_nightgrid","jacket_concrete","pants_olive","jacket_copper","jacket_breakwater","pants_forge","jacket_silt","jacket_meridian","pants_pearl","jacket_oxblood","jacket_afterimage","pants_eclipse","jacket_ember","jacket_archivist","pants_porcelain","jacket_monolith","jacket_overprint","pants_scrapyard","jacket_deadstock","glasses_metro","watch_commute","glasses_harbor","watch_tide","glasses_meridian","watch_ink","glasses_afterimage","watch_pulse","glasses_porcelain","watch_monolith","glasses_deadstock","watch_salvage","hat_thread_cap","hat_thread_beanie","hat_quay_cap","hat_quay_bucket","hat_vesper_fedora","hat_vesper_cap","hat_nocturne_bucket","hat_nocturne_beanie","hat_obscura_fedora","hat_obscura_bucket","hat_signal_cap","hat_signal_beanie"]
const PIECES={
	"jacket_ash":{"name":"Ash work jacket","slot":"jacket","price":18,"tint":Color(.73,.77,.79),"finish":1.0},
	"jacket_oxide":{"name":"Oxide street jacket","slot":"jacket","price":32,"tint":Color(1.0,.53,.38),"finish":.9},
	"jacket_midnight":{"name":"Midnight jacket","slot":"jacket","price":65,"tint":Color(.43,.48,.68),"finish":.82},
	"pants_charcoal":{"name":"Charcoal cargo trousers","slot":"pants","price":15,"tint":Color(.42,.45,.49),"finish":1.0},
	"pants_sand":{"name":"Sand cargo trousers","slot":"pants","price":24,"tint":Color(1.0,.89,.72),"finish":1.0},
	"pants_teal":{"name":"Deep teal cargo trousers","slot":"pants","price":35,"tint":Color(.52,.87,.79),"finish":.92},
	"glasses_night":{"name":"Nightline smoke shades","slot":"glasses","price":26},
	"glasses_clear":{"name":"Threadline clear frames","slot":"glasses","price":19},
	"watch_shift":{"name":"Quay Shift digital watch","slot":"watch","price":38},
	"watch_brass":{"name":"Nocturne brass watch","slot":"watch","price":110},
	"jacket_ink":{"name":"Vesper ink jacket","slot":"jacket","price":175,"tint":Color(.48,.60,.82),"finish":.8},
	"jacket_patch":{"name":"Rivet patched jacket","slot":"jacket","price":10,"tint":Color(.89,.63,.43),"finish":1.0},
	"jacket_signal":{"name":"Static faded jacket","slot":"jacket","price":9,"tint":Color(.62,.51,.79),"finish":1.0},
	"pants_salvage":{"name":"Salvaged work trousers","slot":"pants","price":6,"tint":Color(.72,.67,.49),"finish":1.0},
	"pants_indigo":{"name":"Faded indigo trousers","slot":"pants","price":7,"tint":Color(.49,.57,.78),"finish":1.0},
	"patch_deadcarrier":{"name":"Dead Carrier / Signal Lost","slot":"patch","price":5},
	"patch_voltage":{"name":"Voltage Debt / Live Wire","slot":"patch","price":6},
	"patch_ghostshift":{"name":"Ghost Shift / After Work","slot":"patch","price":4},
	"patch_nightgrid":{"name":"NightGrid FM / Local Signal","slot":"patch","price":5},
	"jacket_concrete":{"name":"Concrete jacket","slot":"jacket","price":22,"tint":Color(.68,.71,.74),"finish":1,"detail":"Cool grey everyday layer"},
	"pants_olive":{"name":"Olive cargo trousers","slot":"pants","price":21,"tint":Color(.69,.74,.48),"finish":1,"detail":"Muted utility green"},
	"jacket_copper":{"name":"Copper Hour jacket","slot":"jacket","price":30,"tint":Color(.92,.62,.43),"finish":0.95,"detail":"Warm copper finish"},
	"jacket_breakwater":{"name":"Breakwater jacket","slot":"jacket","price":47,"tint":Color(.47,.68,.70),"finish":0.98,"detail":"Muted harbor green"},
	"pants_forge":{"name":"Forge cargo trousers","slot":"pants","price":42,"tint":Color(.46,.49,.51),"finish":1,"detail":"Charcoal shift wear"},
	"jacket_silt":{"name":"Silt work jacket","slot":"jacket","price":31,"tint":Color(.77,.73,.58),"finish":1,"detail":"Dusty sand finish"},
	"jacket_meridian":{"name":"Meridian jacket","slot":"jacket","price":165,"tint":Color(.62,.66,.76),"finish":0.79,"detail":"Slate blue subtle sheen"},
	"pants_pearl":{"name":"Pearl trousers","slot":"pants","price":130,"tint":Color(.72,.70,.68),"finish":0.84,"detail":"Warm grey tonal finish"},
	"jacket_oxblood":{"name":"Oxblood jacket","slot":"jacket","price":215,"tint":Color(.68,.37,.41),"finish":0.75,"detail":"Deep burgundy finish"},
	"jacket_afterimage":{"name":"Afterimage jacket","slot":"jacket","price":260,"tint":Color(.49,.80,.87),"finish":0.68,"detail":"Cool cyan sheen"},
	"pants_eclipse":{"name":"Eclipse trousers","slot":"pants","price":190,"tint":Color(.36,.35,.46),"finish":0.65,"detail":"Dark plum finish"},
	"jacket_ember":{"name":"Ember jacket","slot":"jacket","price":310,"tint":Color(.94,.43,.54),"finish":0.72,"detail":"Crimson club colors"},
	"jacket_archivist":{"name":"Archivist jacket","slot":"jacket","price":760,"tint":Color(.67,.63,.55),"finish":0.64,"detail":"Warm stone finish"},
	"pants_porcelain":{"name":"Porcelain trousers","slot":"pants","price":610,"tint":Color(.72,.71,.73),"finish":0.6,"detail":"Pale grey designer palette"},
	"jacket_monolith":{"name":"Monolith jacket","slot":"jacket","price":1180,"tint":Color(.35,.39,.46),"finish":0.58,"detail":"Graphite signature finish"},
	"jacket_overprint":{"name":"Overprint jacket","slot":"jacket","price":8,"tint":Color(.79,.46,.58),"finish":1,"detail":"Faded rose thrift color"},
	"pants_scrapyard":{"name":"Scrapyard trousers","slot":"pants","price":7,"tint":Color(.57,.60,.50),"finish":1,"detail":"Earthy surplus colors"},
	"jacket_deadstock":{"name":"Deadstock jacket","slot":"jacket","price":12,"tint":Color(.46,.65,.83),"finish":0.95,"detail":"Washed blue thrift finish"},
	"glasses_metro":{"name":"Metro amber frames","slot":"glasses","price":27,"detail":"Amber round lenses / copper frames"},
	"watch_commute":{"name":"Commute digital","slot":"watch","price":32,"detail":"Compact red display / rubber band"},
	"glasses_harbor":{"name":"Harbor safety frames","slot":"glasses","price":34,"detail":"Broad smoked lenses / teal frame"},
	"watch_tide":{"name":"Tide shift chronometer","slot":"watch","price":64,"detail":"Round steel dial / olive band"},
	"glasses_meridian":{"name":"Meridian wire frames","slot":"glasses","price":95,"detail":"Round clear lenses / silver frame"},
	"watch_ink":{"name":"Ink dress watch","slot":"watch","price":145,"detail":"Round dark dial / navy band"},
	"glasses_afterimage":{"name":"Afterimage visor frames","slot":"glasses","price":120,"detail":"Wide violet tinted lenses"},
	"watch_pulse":{"name":"Pulse club watch","slot":"watch","price":210,"detail":"Wide digital face / violet accents"},
	"glasses_porcelain":{"name":"Porcelain signature frames","slot":"glasses","price":390,"detail":"Ivory frame / pale smoke lenses"},
	"watch_monolith":{"name":"Monolith signature watch","slot":"watch","price":720,"detail":"Round graphite case / gold markers"},
	"glasses_deadstock":{"name":"Deadstock aviator rounds","slot":"glasses","price":12,"detail":"Reclaimed amber lens / bronze frame"},
	"watch_salvage":{"name":"Salvage digital watch","slot":"watch","price":9,"detail":"Scuffed olive band / green display"},
	"hat_thread_cap":{"name":"Threadline / Block cap","slot":"hat","price":24,"detail":"Slate cap with brass-tone clasp"},
	"hat_thread_beanie":{"name":"Threadline / Night Bus beanie","slot":"hat","price":16,"detail":"Steel-blue knit with folded cuff"},
	"hat_quay_cap":{"name":"Quay / Shift cap","slot":"hat","price":29,"detail":"Olive crown and sand visor"},
	"hat_quay_bucket":{"name":"Quay / Breakwater bucket","slot":"hat","price":38,"detail":"Harbor-green tapered crown"},
	"hat_vesper_fedora":{"name":"Vesper / Meridian fedora","slot":"hat","price":115,"detail":"Charcoal crown and mauve ribbon"},
	"hat_vesper_cap":{"name":"Vesper / Ink cap","slot":"hat","price":78,"detail":"Ink crown with silver-tone trim"},
	"hat_nocturne_bucket":{"name":"Nocturne / Eclipse bucket","slot":"hat","price":95,"detail":"Violet brim and midnight crown"},
	"hat_nocturne_beanie":{"name":"Nocturne / Static beanie","slot":"hat","price":65,"detail":"Plum knit and contrast cuff"},
	"hat_obscura_fedora":{"name":"Obscura / Monolith fedora","slot":"hat","price":480,"detail":"Graphite crown with muted gold ribbon"},
	"hat_obscura_bucket":{"name":"Obscura / Porcelain bucket","slot":"hat","price":290,"detail":"Ivory crown and stone trim"},
	"hat_signal_cap":{"name":"Second Signal / Reclaimed cap","slot":"hat","price":8,"detail":"Faded brown surplus cap"},
	"hat_signal_beanie":{"name":"Second Signal / Ghost Shift beanie","slot":"hat","price":7,"detail":"Rust-toned knit with repaired cuff"}
}

static func piece_valid(id:Variant) -> bool:
	return id is String and PIECES.has(id)

static func piece_price(id:String) -> int:
	return Economy.price_2036(int(PIECES[id]["price"])) if piece_valid(id) else 0

static func valid_slots(value:Variant) -> bool:
	if not value is Dictionary or value.size()>SLOTS.size():
		return false
	for slot in value:
		if slot not in SLOTS or not piece_valid(value[slot]) or PIECES[value[slot]]["slot"]!=slot:
			return false
	return true

static func browse_ids() -> Array:
	return IDS+PIECE_IDS+RESET_IDS

static func reset_slot(id:String) -> String:
	return id.trim_prefix("reset_") if id in RESET_IDS else ""

static func listing(id:String) -> Dictionary:
	if valid_id(id):
		return {"name":ITEMS[id]["name"],"rarity":ITEMS[id]["rarity"],"price":price(id),"type":"OUTFIT","detail":ITEMS[id].get("detail","Coordinated jacket and trousers")}
	if piece_valid(id):
		return {"name":PIECES[id]["name"],"rarity":"INDIVIDUAL","price":piece_price(id),"type":str(PIECES[id]["slot"]).to_upper(),"detail":PIECES[id].get("detail","Individual cosmetic")}
	var slot:=reset_slot(id)
	if not slot.is_empty():
		return {"name":"Restore base "+slot if slot in ["jacket","pants"] else "Remove "+slot,"rarity":"NO CHARGE","price":0,"type":"RESET","detail":"Keep ownership; restore appearance"}
	return {}

const CATEGORIES=["ALL","OUTFITS","JACKETS","TROUSERS","GLASSES","WATCHES","PATCHES","HEADWEAR","OWNED","LOOKS"]
static func category_ids(category:String) -> Array:
	if category in ["ALL","OWNED"]:
		return browse_ids()
	if category=="OUTFITS":
		return IDS.duplicate()
	var slot:String={"JACKETS":"jacket","TROUSERS":"pants","GLASSES":"glasses","WATCHES":"watch","PATCHES":"patch","HEADWEAR":"hat"}.get(category,"")
	var result:Array=[]
	if slot.is_empty():
		return result
	for id in PIECE_IDS:
		if PIECES[id]["slot"]==slot:
			result.append(id)
	result.append("reset_"+slot)
	return result

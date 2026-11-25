extends RefCounted
## Stable authored street personalities. No runtime text generation.
const LINES = [
	{
		"id": "street.robot_romantic.01",
		"character": "robot_romantic",
		"text": "My girlfriend is a robot. Her parents are a motherboard and a warranty department."
	},
	{
		"id": "street.robot_romantic.02",
		"character": "robot_romantic",
		"text": "We had an argument last night. She rolled back to a previous version of herself."
	},
	{
		"id": "street.robot_romantic.03",
		"character": "robot_romantic",
		"text": "She's not high maintenance. It's a monthly subscription."
	},
	{
		"id": "street.nothing_happens.01",
		"character": "nothing_happens",
		"text": "Nothing ever happens."
	},
	{
		"id": "street.nothing_happens.02",
		"character": "nothing_happens",
		"text": "Everybody says this city is collapsing. I've been refreshing the feed for six hours. Nothing."
	},
	{
		"id": "street.nothing_happens.03",
		"character": "nothing_happens",
		"text": "They could put a crater where the mayor's office is and I'd still call it a nothingburger."
	},
	{
		"id": "street.gig_grinder.01",
		"character": "gig_grinder",
		"text": "I work for three apps. None of them know I'm employed."
	},
	{
		"id": "street.gig_grinder.02",
		"character": "gig_grinder",
		"text": "My boss is a progress bar that hates me."
	},
	{
		"id": "street.gig_grinder.03",
		"character": "gig_grinder",
		"text": "They gave me a loyalty badge instead of a raise. I can't pay rent with a little star."
	},
	{
		"id": "street.subscription_skeptic.01",
		"character": "subscription_skeptic",
		"text": "My apartment has a subscription doorbell. I canceled it. Now visitors are downloadable content."
	},
	{
		"id": "street.subscription_skeptic.02",
		"character": "subscription_skeptic",
		"text": "I miss when a toaster was just a toaster."
	},
	{
		"id": "street.subscription_skeptic.03",
		"character": "subscription_skeptic",
		"text": "They offered me an ad-free shower. I asked if the water was extra."
	},
	{
		"id": "street.street_visionary.01",
		"character": "street_visionary",
		"text": "I'm disrupting the sidewalk industry. People are already walking all over my product."
	},
	{
		"id": "street.street_visionary.02",
		"character": "street_visionary",
		"text": "My startup has no customers, but our waiting list is emotionally invested."
	},
	{
		"id": "street.street_visionary.03",
		"character": "street_visionary",
		"text": "We're pre-revenue, post-accountability. It's a very exciting phase."
	},
	{
		"id": "street.night_regular.01",
		"character": "night_regular",
		"text": "This club has a dress code and a credit score requirement."
	},
	{
		"id": "street.night_regular.02",
		"character": "night_regular",
		"text": "I came out for one drink. That was two firmware updates ago."
	},
	{
		"id": "street.night_regular.03",
		"character": "night_regular",
		"text": "The DJ is an algorithm. Somehow it still takes requests personally."
	},
	{
		"id": "street.robot_romantic.incident",
		"character": "robot_romantic",
		"text": "My girlfriend says public disturbances are a known issue. They're working on a patch.",
		"context": "incident"
	},
	{
		"id": "street.robot_romantic.urgent",
		"character": "robot_romantic",
		"text": "She just sent me a safety notification. That's the most affectionate she's been all week.",
		"context": "urgent"
	},
	{
		"id": "street.robot_romantic.traffic",
		"character": "robot_romantic",
		"text": "My girlfriend is a better driver than that. She doesn't even have legs.",
		"context": "traffic"
	},
	{
		"id": "street.nothing_happens.incident",
		"character": "nothing_happens",
		"text": "A whole commotion for that? Nothing ever happens.",
		"context": "incident"
	},
	{
		"id": "street.nothing_happens.urgent",
		"character": "nothing_happens",
		"text": "Okay. That was loud. Still a nothingburger.",
		"context": "urgent"
	},
	{
		"id": "street.nothing_happens.traffic",
		"character": "nothing_happens",
		"text": "Almost got flattened. Anyway, nothing ever happens.",
		"context": "traffic"
	},
	{
		"id": "street.gig_grinder.incident",
		"character": "gig_grinder",
		"text": "Bet somebody's charging a surge fee for this.",
		"context": "incident"
	},
	{
		"id": "street.gig_grinder.urgent",
		"character": "gig_grinder",
		"text": "Well, there goes my on-time delivery bonus.",
		"context": "urgent"
	},
	{
		"id": "street.gig_grinder.traffic",
		"character": "gig_grinder",
		"text": "The app says traffic is light. I would like to invite the app outside.",
		"context": "traffic"
	},
	{
		"id": "street.subscription_skeptic.incident",
		"character": "subscription_skeptic",
		"text": "Watch them introduce a premium tier for peace and quiet.",
		"context": "incident"
	},
	{
		"id": "street.subscription_skeptic.urgent",
		"character": "subscription_skeptic",
		"text": "I swear, if they charge me a public safety convenience fee...",
		"context": "urgent"
	},
	{
		"id": "street.subscription_skeptic.traffic",
		"character": "subscription_skeptic",
		"text": "That car's probably still downloading the brakes.",
		"context": "traffic"
	},
	{
		"id": "street.street_visionary.incident",
		"character": "street_visionary",
		"text": "This is an underserved market for disruption management.",
		"context": "incident"
	},
	{
		"id": "street.street_visionary.urgent",
		"character": "street_visionary",
		"text": "I prefer disruption in the pitch deck. Not out here.",
		"context": "urgent"
	},
	{
		"id": "street.street_visionary.traffic",
		"character": "street_visionary",
		"text": "We're going to monetize near misses. Huge addressable market.",
		"context": "traffic"
	},
	{
		"id": "street.night_regular.incident",
		"character": "night_regular",
		"text": "Is this the queue for somewhere or just a very disappointing street performance?",
		"context": "incident"
	},
	{
		"id": "street.night_regular.urgent",
		"character": "night_regular",
		"text": "I came out for a quiet evening. Wrong district, apparently.",
		"context": "urgent"
	},
	{
		"id": "street.night_regular.traffic",
		"character": "night_regular",
		"text": "Somebody's trying to get to last call a little early.",
		"context": "traffic"
	},
	{
		"id": "street.robot_romantic.exchange.robot_date.1",
		"character": "robot_romantic",
		"text": "My girlfriend and I are thinking about moving in together.",
		"exchange": "robot_date",
		"turn": 0
	},
	{
		"id": "street.nothing_happens.exchange.robot_date.2",
		"character": "nothing_happens",
		"text": "Nothing ever happens.",
		"exchange": "robot_date",
		"turn": 1
	},
	{
		"id": "street.robot_romantic.exchange.robot_date.3",
		"character": "robot_romantic",
		"text": "She sent me the minimum system requirements for marriage.",
		"exchange": "robot_date",
		"turn": 2
	},
	{
		"id": "street.street_visionary.exchange.side_hustle.1",
		"character": "street_visionary",
		"text": "Have you considered monetizing your commute?",
		"exchange": "side_hustle",
		"turn": 0
	},
	{
		"id": "street.gig_grinder.exchange.side_hustle.2",
		"character": "gig_grinder",
		"text": "I already deliver lunch on my way to my second job.",
		"exchange": "side_hustle",
		"turn": 1
	},
	{
		"id": "street.street_visionary.exchange.side_hustle.3",
		"character": "street_visionary",
		"text": "Incredible. You're an ecosystem.",
		"exchange": "side_hustle",
		"turn": 2
	},
	{
		"id": "street.night_regular.exchange.night_subscription.1",
		"character": "night_regular",
		"text": "The club charges for standing still now.",
		"exchange": "night_subscription",
		"turn": 0
	},
	{
		"id": "street.subscription_skeptic.exchange.night_subscription.2",
		"character": "subscription_skeptic",
		"text": "Of course. Moving around is the premium tier.",
		"exchange": "night_subscription",
		"turn": 1
	},
	{
		"id": "street.night_regular.exchange.night_subscription.3",
		"character": "night_regular",
		"text": "I paid extra to leave early.",
		"exchange": "night_subscription",
		"turn": 2
	}
]
const CAST = ["robot_romantic","nothing_happens","gig_grinder","subscription_skeptic","street_visionary","night_regular"]

static func personality(id:String) -> String:
	return CAST[posmod(id.hash(),CAST.size())]

static func line_for(id:String, index:int) -> Dictionary:
	var character:=personality(id)
	return LINES[CAST.find(character)*3+posmod(index,3)].duplicate()

static func contextual_line(id:String,context:String) -> Dictionary:
	if not context in ["incident","urgent","traffic"]:
		return {}
	var character:=personality(id)
	for row in LINES:
		if row["character"]==character and row.get("context","")==context:
			return row.duplicate()
	return {}

## Return only a complete authored exchange for two distinct personalities.
static func exchange_for(first:String,second:String) -> Array[Dictionary]:
	var a:=personality(first)
	var b:=personality(second)
	var result:Array[Dictionary]=[]
	if a==b:
		return result
	for row in LINES:
		if not row.has("exchange") or int(row["turn"])!=0:
			continue
		if row["character"] not in [a,b]:
			continue
		var candidate:Array[Dictionary]=[]
		for beat in LINES:
			if beat.get("exchange","")==row["exchange"]:
				candidate.append(beat.duplicate())
		if candidate.size()==3 and candidate[1]["character"] in [a,b] and candidate[1]["character"]!=candidate[0]["character"]:
			return candidate
	return result

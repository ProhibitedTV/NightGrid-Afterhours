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
	},
	{
		"id": "street.robot_romantic.talk.1",
		"character": "robot_romantic",
		"text": "At a trade show. I asked for her number and she gave me her serial number. We just clicked.",
		"topic": 0,
		"question": "How did you two meet?"
	},
	{
		"id": "street.robot_romantic.talk.2",
		"character": "robot_romantic",
		"text": "No. She's charging. We have separate schedules, but at least she tells me when she's unavailable.",
		"topic": 1,
		"question": "Is she coming out tonight?"
	},
	{
		"id": "street.nothing_happens.talk.1",
		"character": "nothing_happens",
		"text": "It's fine. Everybody online says the end is near. My rent went up, but otherwise nothing ever happens.",
		"topic": 0,
		"question": "What do you think of Morrow Bay?"
	},
	{
		"id": "street.nothing_happens.talk.2",
		"character": "nothing_happens",
		"text": "A software update that actually fixes something. Now that would be historic.",
		"topic": 1,
		"question": "What would actually surprise you?"
	},
	{
		"id": "street.gig_grinder.talk.1",
		"character": "gig_grinder",
		"text": "I'm technically my own boss. My boss just denied my request for a bathroom break.",
		"topic": 0,
		"question": "How's work?"
	},
	{
		"id": "street.gig_grinder.talk.2",
		"character": "gig_grinder",
		"text": "Never accept a job that pays in exposure. Unless your landlord is a photographer.",
		"topic": 1,
		"question": "Any advice for a new courier?"
	},
	{
		"id": "street.subscription_skeptic.talk.1",
		"character": "subscription_skeptic",
		"text": "You used to own things. Now the toaster wants my email address. I'm not building a relationship with breakfast.",
		"topic": 0,
		"question": "What's wrong with subscriptions?"
	},
	{
		"id": "street.subscription_skeptic.talk.2",
		"character": "subscription_skeptic",
		"text": "A screwdriver. No account, no updates. Beautiful piece of technology.",
		"topic": 1,
		"question": "What's the last thing you bought outright?"
	},
	{
		"id": "street.street_visionary.talk.1",
		"character": "street_visionary",
		"text": "We're building a platform to connect people who have free time with people who want to invoice it.",
		"topic": 0,
		"question": "What's your latest startup?"
	},
	{
		"id": "street.street_visionary.talk.2",
		"character": "street_visionary",
		"text": "Absolutely. Compensation is experience, equity in a future entity, and access to our inspirational group chat.",
		"topic": 1,
		"question": "Are you hiring?"
	},
	{
		"id": "street.night_regular.talk.1",
		"character": "night_regular",
		"text": "Find somewhere that plays real music and doesn't scan your credit score at the door. Good luck.",
		"topic": 0,
		"question": "Where's a good place to go?"
	},
	{
		"id": "street.night_regular.talk.2",
		"character": "night_regular",
		"text": "I woke up with three loyalty accounts and a receipt for premium atmosphere.",
		"topic": 1,
		"question": "How was last night?"
	},
	{
		"id": "street.robot_romantic.quest.accept",
		"character": "robot_romantic",
		"text": "It's our anniversary. Auntie Sol at Moon Noodles has my gift, a limited-edition heat sink. I paid already. Could you pick it up? She deserves better thermal management.",
		"quest": "accept"
	},
	{
		"id": "street.robot_romantic.quest.complete",
		"character": "robot_romantic",
		"text": "Look at that copper finish. She's going to be so happy. Or at least her temperature sensors will be. Here's eighty-five bucks. Thanks, choom.",
		"quest": "complete"
	},
	{
		"id": "street.nyx.soundcheck.brief",
		"character": "nyx",
		"text": "People around here say you keep your word. Take this demo to Rae at Blue Hour. No algorithms, no auditions by committee. Just let someone hear it.",
		"venue_job": "soundcheck_pass",
		"beat": "brief"
	},
	{
		"id": "street.rae.soundcheck.ending",
		"character": "rae",
		"text": "Nyx sent you? Good. This city needs more people making music, not more people selling subscriptions to it. I'll keep your name on the list.",
		"venue_job": "soundcheck_pass",
		"beat": "ending"
	},
	{
		"id": "street.daddy_stanky.talk.1",
		"character": "daddy_stanky",
		"question": "Let's hear some bars.",
		"topic": 0,
		"text": "Yo, three dead toes but I still walk the beat. Corporate suits got nothin' on me. I'll beat ya brain, put the bass in your street. Daddy Stanky, underground, never sold a seat."
	},
	{
		"id": "street.daddy_stanky.talk.2",
		"character": "daddy_stanky",
		"question": "What's Humanity about?",
		"topic": 1,
		"text": "Everybody thinks they know me, bro. Calm down, little predatah. I got jokes, I got bars, but I got a heart too. I'll show you my humanity."
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

const PROFILES = {
	"robot_romantic": {
		"name": "Cal Mercer",
		"role": "Robot romantic"
	},
	"nothing_happens": {
		"name": "Dale Voss",
		"role": "Professional skeptic"
	},
	"gig_grinder": {
		"name": "Nina Reyes",
		"role": "App economy veteran"
	},
	"subscription_skeptic": {
		"name": "Frank Bell",
		"role": "Analog holdout"
	},
	"street_visionary": {
		"name": "Tess Park",
		"role": "Serial founder"
	},
	"night_regular": {
		"name": "Milo Crane",
		"role": "Afterhours regular"
	}
}

static func profile(id:String) -> Dictionary:
	var character:=personality(id)
	var result:Dictionary=PROFILES[character].duplicate()
	result["character"]=character
	result["topics"]=[]
	for row in LINES:
		if row["character"]==character and row.has("topic"):
			result["topics"].append(row.duplicate())
	return result

static func cal_quest_line(action:String)->Dictionary:
	for row in LINES:
		if row.get("quest","")==action and row["character"]=="robot_romantic":
			return row.duplicate()
	return {}

static func venue_job_line(id:String,beat:String)->Dictionary:
	for row in LINES:
		if row.get("venue_job","")==id and row.get("beat","")==beat:
			return row.duplicate()
	return {}

# Fixed venue legend, deliberately excluded from the pooled random identities.
const STANKY_ID = "daddy_stanky"
const STANKY_SCOPE = "venue:daddy_stanky"
static func stanky_profile() -> Dictionary:
	var topics: Array[Dictionary] = []
	for line in LINES:
		if line["character"] == STANKY_ID:
			topics.append(line.duplicate())
	return {"name":"Daddy Stanky","role":"Underground legend / HUMANITY mixtape","character":STANKY_ID,"topics":topics}

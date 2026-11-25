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
	}
]
const CAST = ["robot_romantic","nothing_happens","gig_grinder","subscription_skeptic","street_visionary","night_regular"]

static func personality(id:String) -> String:
	return CAST[posmod(id.hash(),CAST.size())]

static func line_for(id:String, index:int) -> Dictionary:
	var character:=personality(id)
	return LINES[CAST.find(character)*3+posmod(index,3)].duplicate()

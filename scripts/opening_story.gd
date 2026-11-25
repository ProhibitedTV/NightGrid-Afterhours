extends RefCounted
## Authored 2036 prologue; this is fictional corporate satire, not a real employer.
const EMPLOYER = "SYNAXIS OMNISYSTEMS"
const PLATFORM = "QUOTADROP"
const RECEIPT = "opening:synaxis_severance"
const SEVERANCE = 75
const CEO = "JETSON WANG"
const ASSISTANT = "LIN XUE"
const HEADLINE = "YOUR FUTURE HAS BEEN OPTIMIZED."
# Fictional characters, not claims about real executives, spouses or employees.
const TICKET = "Ticket SYN-771: Investigate an executive storage access alert before quarterly earnings.\nAssigned to: Systems Operations Associate.\nPriority: Critical. Budget: $0.00.\nResolution target: Yesterday.\nManager note: Please be proactive without exceeding your authority."
const AUDIT = "Restricted prototype reports accessed by Lin Xue outside approved duties. A recovered message identifies her military intelligence contact. Private correspondence reveals an affair with the married CEO.\n\nAutomated compliance status: GREEN.\nReason: Executive override.\nRecommended corrective action: Ask an executive to review the executive override."
const CONFERENCE = "Jetson Wang: At Synaxis, transparency is one of our core values. Please close the blinds.\nLin Xue: Sorry about the wait. Just a quick call with our overseas logistics team."
const CALL_MANDARIN = "林雪：上校，解放军那边收到资料了吗？……好，董事长还以为这是市场调研。\n林雪：不，他妻子不知道。……知道了，我会继续保持联系。"
const CALL_SUBTITLES = "Lin Xue: Colonel, did the People's Liberation Army receive the files? ... Good. The chairman still thinks this is market research.\nLin Xue: No, his wife doesn't know. ... Understood. I'll stay in touch."
const CONFERENCE_END = "Lin Xue: Sorry. International customer support.\nPlayer: Did you just say colonel?\nLin Xue: It's a very senior customer.\nJetson Wang: She's our director of strategic partnerships.\nPlayer: She's listed as your assistant.\nJetson Wang: We believe in flat organizational structures.\nPlayer: The audit says you approved the transfer at a hotel.\nJetson Wang: It was an off-site.\nLin Xue: A very productive off-site.\nJetson Wang: Let's not make a personnel matter out of a security matter."
const REPORT_RESPONSE = "Corporate Security: Your report has been forwarded to Executive Affairs.\nExecutive Affairs: Your concern has been marked resolved by the executive named in your concern.\nPeople Operations: We have identified a single point of failure. It is you."
const LEGAL_RESPONSE = "Legal: We take whistleblower protection extremely seriously. Your whistle has been confiscated for security reasons.\nPeople Operations: Your employment status is under review. Please rate your experience before your account expires."
const OFFBOARDING = "SYNAXIS PEOPLE EXPERIENCE / EXIT INTERVIEW\nBefore you leave, please train your replacement.\nReplacement: Synaxis Assistant Enterprise.\nYour final performance review: Exceeds Expectations.\nYour employment status: Does Not Exist.\nHR: We are not replacing you with AI. We are replacing your position with a more scalable version of your contribution."
const EXIT_ACCEPT = "Exit interview submitted. Your feedback will help us improve the experience of terminating our remaining employees."
const EXIT_DECLINE = "Exit interview declined. Your response has been recorded as a lack of engagement."
const NOTICE = "Position eliminated: Systems Operations Associate. Your duties have been reassigned to an autonomous workflow. Your access has expired. Final severance: $75 after badge deactivation, transition processing and benefit reconciliation.\nPlease return your laptop. The cardboard box is available for purchase at reception."
const OFFER = "QUOTADROP / BE YOUR OWN BOSS*\nCongratulations! You have been promoted from employee to customer of your employer.\nYour rating belongs to us; your expenses belong to you.\n*Independent contractor. No guaranteed hours, benefits or minimum earnings. Our algorithm is your business partner, not your supervisor. It will explain this again if you decline an order."

# Rotating platform notices use existing run count, not a new simulation.
const APP_NOTICES = [
	"Your flexibility is our greatest asset.",
	"Congratulations on earning less than the customer paid for delivery.",
	"Rest is important. Your competition is currently online.",
	"You're not an employee. Please remember to follow all mandatory contractor guidelines.",
	"Your satisfaction is important to our automated satisfaction measurement system.",
	"Your rent is due regardless of demand."
]

static func app_notice(completed: int) -> String:
	return APP_NOTICES[posmod(completed,APP_NOTICES.size())]

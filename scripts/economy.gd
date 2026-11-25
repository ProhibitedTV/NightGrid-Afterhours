extends RefCounted
## Fictional 2036 economy. Never reads live markets or transfers real currency.
## 3% annual compound inflation for ten years, rounded to whole dollars.
const BASE_YEAR = 2026
const SETTING_YEAR = 2036
const INFLATION_FACTOR = 1.343916379
# Fictional exchange convention, $250,000 per BTC; 100,000,000 sats per BTC.
const SATS_PER_USD = 400
const MAX_SATS = 400000000000
const EXCHANGE_USD = 100
const EXCHANGE_FEE_USD = 2

static func price_2036(base_usd: int) -> int:
	return maxi(1,roundi(float(base_usd)*INFLATION_FACTOR)) if base_usd > 0 else 0

static func sats_for_usd(usd: int) -> int:
	return usd*SATS_PER_USD

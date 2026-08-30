--!strict
-- Generic per-player, per-remote token-bucket rate limiter. Every remote
-- handler in Network/* should wrap its body with a check against this
-- before doing any real work, so a malicious or buggy client spamming a
-- RemoteEvent can't burn server CPU (combat resolution, DataStore calls,
-- etc.) far faster than a legitimate player ever could.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local RateLimiter = {}

type Bucket = {
	tokens: number,
	lastRefill: number,
}

local buckets: { [number]: { [string]: Bucket } } = {}

-- Returns true if this call is allowed (and consumes one token), false if
-- the player is over the limit for this key and the call should be
-- dropped/ignored. `maxPerSecond` defaults to
-- Constants.DEFAULT_REMOTE_RATE_LIMIT_PER_SECOND.
function RateLimiter.checkAndConsume(player: Player, key: string, maxPerSecond: number?): boolean
	local limit = maxPerSecond or Constants.DEFAULT_REMOTE_RATE_LIMIT_PER_SECOND
	local playerBuckets = buckets[player.UserId]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player.UserId] = playerBuckets
	end

	local now = os.clock()
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { tokens = limit, lastRefill = now }
		playerBuckets[key] = bucket
	end

	local elapsed = now - bucket.lastRefill
	bucket.tokens = math.min(limit, bucket.tokens + elapsed * limit)
	bucket.lastRefill = now

	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end

	return false
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player.UserId] = nil
end)

return RateLimiter

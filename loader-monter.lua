-- Loads the newest Monter.lua. raw.githubusercontent.com caches the "main" branch for about five minutes
-- (a ?t= query does not help), so resolve the latest commit first and fetch that exact file.
local HttpService = game:GetService("HttpService")
local base = "https://raw.githubusercontent.com/kirisora00/Autokey/"
local ok, sha = pcall(function()
    return HttpService:JSONDecode(game:HttpGet("https://api.github.com/repos/kirisora00/Autokey/commits/main")).sha
end)
local ref = ok and type(sha) == "string" and sha or "main" -- API limit reached: fall back to the cached branch
loadstring(game:HttpGet(base .. ref .. "/Monter.lua"))()

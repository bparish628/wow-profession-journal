local _, PJ = ...

-- Classic skinning needs (level - 10) * 10 skill up to level 20 and level * 5
-- above it. Each band requires the skill for its highest level, so the whole
-- band is skinnable. Yields are the usual leathers for the band, not a loot table.
local function SkinningSkill(level)
  if level <= 10 then return 1 end
  if level <= 20 then return (level - 10) * 10 end
  return level * 5
end

local SKINNING = 393

for _, band in ipairs({
  { minLevel = 1, maxLevel = 10, yields = { 2934, 2318, 783 } },
  { minLevel = 11, maxLevel = 20, yields = { 2318, 783 } },
  { minLevel = 21, maxLevel = 30, yields = { 2319, 4232 } },
  { minLevel = 31, maxLevel = 40, yields = { 4234, 4235 } },
  { minLevel = 41, maxLevel = 50, yields = { 4304, 8169, 8154, 8167 } },
  { minLevel = 51, maxLevel = 60, yields = { 8170, 8171, 15417, 15408 } },
}) do
  band.profession = SKINNING
  band.skill = SkinningSkill(band.maxLevel)
  PJ.RegisterSkinningBand(band)
end

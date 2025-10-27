---@class HeadBlendData
---@field shapeFirst integer
---@field shapeSecond integer
---@field shapeThird integer
---@field skinFirst integer
---@field skinSecond integer
---@field skinThird integer
---@field shapeMix number
---@field skinMix number
---@field thirdMix number

local freemodeModels<const> = {
  [`mp_m_freemode_01`] = 'mp_m_freemode_01',
  [`mp_f_freemode_01`] = 'mp_f_freemode_01'
}

---Is the model either of the freemode models?
---@param modelHash integer
local function isFreemodeModel(modelHash)
  return freemodeModels[modelHash] ~= nil
end

---Gets head blend data
---@param ped integer
---@return HeadBlendData
local function getHeadBlendData(ped)
  local tbl<const> = {
    Citizen.InvokeNative(0x2746BD9D88C5C5D0, ped,
      Citizen.PointerValueIntInitialized(0),
      Citizen.PointerValueIntInitialized(0),
      Citizen.PointerValueIntInitialized(0),
      Citizen.PointerValueIntInitialized(0),
      Citizen.PointerValueIntInitialized(0),
      Citizen.PointerValueIntInitialized(0),
      Citizen.PointerValueFloatInitialized(0),
      Citizen.PointerValueFloatInitialized(0),
      Citizen.PointerValueFloatInitialized(0)
    )
  }

  return {
    shapeFirst = tbl[1],
    shapeSecond = tbl[2],
    shapeThird = tbl[3],
    skinFirst = tbl[4],
    skinSecond = tbl[5],
    skinThird = tbl[6],
    shapeMix = tbl[7],
    skinMix = tbl[8],
    thirdMix = tbl[9]
  }
end

local savedBlendData, savedFaceFeatures

---Restores saved blend data
---@param ped integer
local function restoreSavedBlendData(ped)
  SetPedHeadBlendData(ped,
    savedBlendData.shapeFirst, savedBlendData.shapeSecond, savedBlendData.shapeThird,
    savedBlendData.skinFirst, savedBlendData.skinSecond, savedBlendData.skinThird,
    savedBlendData.shapeMix, savedBlendData.skinMix, savedBlendData.thirdMix,
    false
  )
end

---Restores saved face features
---@param ped integer
local function restoreSavedFaceFeatures(ped)
  for i = 0, 19 do
    SetPedFaceFeature(ped, i, savedFaceFeatures[i])
  end
end

---Shrinks face features
---@param ped integer
local function shrinkFaceFeatures(ped)
  repeat Wait(0) until HasPedHeadBlendFinished(ped)
  for i = 0, 19 do
    if not savedFaceFeatures[i] then savedFaceFeatures[i] = GetPedFaceFeature(ped, i) end
    SetPedFaceFeature(ped, i, 0.0)
  end
end

---Shrink ped head
---@param ped integer
---@param pedModelHash integer
local function shrinkHead(ped, pedModelHash)
  SetPedHeadBlendData(ped,
    freemodeModels[pedModelHash] == 'mp_m_freemode_01' and 0 or 21, 0, 0,
    savedBlendData.skinFirst, savedBlendData.skinSecond, savedBlendData.skinThird,
    0.0, savedBlendData.skinMix, 0.0,
    false
  )
end

---Handles mask fix (with add-on support)
---@param ped integer
---@param pedModelHash integer
local function fixMask(ped, pedModelHash)
  local currentMaskDrawable<const> = GetPedDrawableVariation(ped, 1)
  local currentMaskTexture<const>  = GetPedTextureVariation(ped, 1)

  if currentMaskDrawable > 0 then
    local maskHash<const> = GetHashNameForComponent(ped, 1, currentMaskDrawable, currentMaskTexture)
    local headBlendData<const> = getHeadBlendData(ped)
    
    local shouldShrinkHead = false
    local shouldShrinkFace = false

    if maskHash ~= 0 then
      shouldShrinkHead = DoesShopPedApparelHaveRestrictionTag(maskHash, `SHRINK_HEAD`, 0)
      shouldShrinkFace = not DoesShopPedApparelHaveRestrictionTag(maskHash, `HAT`, 0)
                         and not DoesShopPedApparelHaveRestrictionTag(maskHash, `EAR_PIECE`, 0)
    else
      shouldShrinkHead = true
      shouldShrinkFace = true
    end

    if currentMaskDrawable == 108 or currentMaskDrawable == 30 then
      shouldShrinkHead = true
    end

    if currentMaskDrawable == 11 or currentMaskDrawable == 114 
       or currentMaskDrawable == 145 or currentMaskDrawable == 148 then
      shouldShrinkFace = false
    end

    if shouldShrinkHead then
      if not savedBlendData then savedBlendData = headBlendData end
      shrinkHead(ped, pedModelHash)
    elseif savedBlendData then
      restoreSavedBlendData(ped)
      savedBlendData = nil
    end

    if shouldShrinkFace then
      if not savedFaceFeatures then savedFaceFeatures = {} end
      shrinkFaceFeatures(ped)
    elseif savedFaceFeatures then
      restoreSavedFaceFeatures(ped)
      savedFaceFeatures = nil
    end
  else
    if savedBlendData then
      restoreSavedBlendData(ped)
      savedBlendData = nil
    end

    if savedFaceFeatures then
      restoreSavedFaceFeatures(ped)
      savedFaceFeatures = nil
    end
  end
end

local function fixClothing()
  local ped<const> = PlayerPedId()
  if not DoesEntityExist(ped) then return end

  local pedModelHash<const> = GetEntityModel(ped)
  if not isFreemodeModel(pedModelHash) then return end

  fixMask(ped, pedModelHash)
end

CreateThread(function()
  while true do
    fixClothing()
    Wait(10)
  end
end)

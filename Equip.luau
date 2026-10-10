local EquipModule = {}

------------------------------------------
local WeaponServer = script.Parent.Parent
------------------------------------------

--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServiceScriptService = game:GetService("ServerScriptService")

--//Folders
local Modules = ReplicatedStorage.Modules
local Animations = ReplicatedStorage.Assets.Animations
local Effects = ReplicatedStorage.Assets.Effects
local Sounds = ReplicatedStorage.Assets.Sounds
local Welds = ReplicatedStorage.Assets.Welds

--//Modules
local StateManager = require(Modules.StateManager)
local DataManager = require(ServiceScriptService.Managers.DataManager)

--//Welds
local IdleWeld: Motor6D?=nil
local HoldingWeld: Motor6D?=nil

--//Data
local EquipData = setmetatable({}, { __mode = "k" })

local function GetData(Character)
	local Data = EquipData[Character]
	if not Data then
		Data = { Debounce=false}
		EquipData[Character] = Data
	end
	return Data
end

--//

function OnCharacter(Character:Model)
	local Player = Players:GetPlayerFromCharacter(Character)
	local PlayerData = DataManager.WaitForData(Player)
	
	local WeaponModel = ReplicatedStorage.Assets.Models:FindFirstChild(PlayerData.Weapon)
	:Clone()
	if WeaponModel then
		WeaponModel.Parent = Character
	end
	
	local Part = WeaponModel:IsA("Model") and 
		WeaponModel:FindFirstChild("Handle") or WeaponModel
	
	local WeaponWelds = Welds:FindFirstChild(PlayerData.Weapon)
	IdleWeld = WeaponWelds.Idle:Clone()::Motor6D
	
	IdleWeld.Parent = Character.Torso
	IdleWeld.Part0 = Character.Torso
	IdleWeld.Part1 = Part
end

function EquipModule:Equip(Character:Model)
	local Player = Players:GetPlayerFromCharacter(Character)
	local PlayerData = DataManager.WaitForData(Player)
	local WeaponWelds = Welds:FindFirstChild(PlayerData.Weapon)
	
	local Data = GetData(Character)
	if Data.Debounce then return end
	Data.Debounce = true
	
	local Weapon = Character:FindFirstChild(PlayerData.Weapon)
	local Part = Weapon:IsA("Model") and Weapon:FindFirstChild("Handle") or Weapon
	
	local WeaponWelds = Welds:FindFirstChild(PlayerData.Weapon)
	HoldingWeld = WeaponWelds.Holding:Clone()::Motor6D
	
	StateManager:AddState(Character,"Equipped")
	
	local Humanoid = Character.Humanoid::Humanoid
	local Animator = Humanoid.Animator::Animator
	
	local WeaponAnimations = Animations:FindFirstChild(PlayerData.Weapon)
	
	local EquipTrack = Animator:LoadAnimation(WeaponAnimations.Equip)
	local IdleTrack = Animator:LoadAnimation(WeaponAnimations.Idle)
	IdleTrack.Name = "Idle"
	IdleTrack.Priority = Enum.AnimationPriority.Idle
	
	EquipTrack.Looped = false
	EquipTrack:Play()
	EquipTrack:GetMarkerReachedSignal("Start"):Connect(function()
		HoldingWeld.Parent = Character["Right Arm"]
		HoldingWeld.Part0 = Character["Right Arm"]
		HoldingWeld.Part1 = Part
		
		if IdleWeld then
			IdleWeld.Part1 = nil
			IdleWeld.Part0 = nil
		end
		
		IdleTrack.Looped = true
		IdleTrack:Play()
	end)
	
	task.delay(.5, function()
		Data.Debounce = false
	end)
end

function EquipModule:Unequip(Character:Model)
	local Player = Players:GetPlayerFromCharacter(Character)
	local PlayerData = DataManager.WaitForData(Player)
	local WeaponWelds = Welds:FindFirstChild(PlayerData.Weapon)
	
	local Weapon = Character:FindFirstChild(PlayerData.Weapon)
	if not Weapon then return end
	local Part = Weapon:IsA("Model") and Weapon:FindFirstChild("Handle") or Weapon
	
	StateManager:RemoveState(Character,"Equipped")
	
	local Humanoid = Character.Humanoid::Humanoid
	local Animator = Humanoid.Animator::Animator

	for _, Track in Animator:GetPlayingAnimationTracks() do
		if Track.Name == "Idle" then
			Track:Stop()
		end
	end
	
	local WeaponAnimations = Animations:FindFirstChild(PlayerData.Weapon)

	local UnEquipTrack = Animator:LoadAnimation(WeaponAnimations.UnEquip)
	UnEquipTrack:Play()
	
	UnEquipTrack:GetMarkerReachedSignal("Start"):Connect(function()
		if HoldingWeld then
			HoldingWeld.Part0 = nil
			HoldingWeld.Part1 = nil
			HoldingWeld.Parent = WeaponWelds
		end

		if IdleWeld then
			IdleWeld.Parent = Character.Torso
			IdleWeld.Part0 = Character.Torso
			IdleWeld.Part1 = Part
		end
		
	end)

end


--//

Players.PlayerAdded:Connect(function(plr)
	if plr.Character then
		OnCharacter(plr.Character)
	end
	
	plr.CharacterAdded:Connect(OnCharacter)
end)

return EquipModule

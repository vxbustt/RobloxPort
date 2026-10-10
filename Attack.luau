------------------------------------------
local WeaponServer = script.Parent.Parent
------------------------------------------

--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServiceScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

--//Folders
local Modules = ReplicatedStorage.Modules
local Animations = ReplicatedStorage.Assets.Animations
local Effects = ReplicatedStorage.Assets.Effects
local Sounds = ReplicatedStorage.Assets.Sounds

--//Modules
local StateManager = require(Modules.StateManager)
local DataManager = require(ServiceScriptService.Managers.DataManager)
local Criticals = require(script.Criticals)
local ShapecastHitbox = require(ReplicatedStorage.Packages.ShapecastHitbox)
local MovementEffects = require(ReplicatedStorage.Modules.MovementEffects)

local Types = require(WeaponServer.Types)
local Config = require(WeaponServer.Config)

--//Functions

function GetAnimations(Weapon:string): Types.WeaponAnimations
	local Anims = Animations[Weapon]
	if not Anims then
		warn("{Attack} failed to get weapon anims")
		return nil
	end
	
	return Anims
end

function GetEffects(Weapon:string)
	local Effect = Effects[Weapon]
	if not Effect then
		warn("{Attack} failed to get weapon effects")
		return nil
	end

	return Effect
end

local function HasAnyState(Character, States)
	for _, State in States do
		if StateManager:HasState(Character, State) then
			return true
		end
	end

	return false
end

local function CanAttack(Character)
	return not HasAnyState(Character, {
		"Stunned",
		"Iframes",
		"Blocking",
		"Parrying",
		"Attacking",
		"Ragdolled",
		"Knocked",
		"Dashing",
		"UsingSkill",
	})
end

local function Push(Hrp:BasePart,EnemyHrp:BasePart,Force:number)
	local lv = Instance.new("LinearVelocity")
	lv.MaxForce = math.huge
	lv.VectorVelocity = Hrp.CFrame.LookVector * Force
	lv.Parent = EnemyHrp
	lv.Attachment0 = Instance.new("Attachment",EnemyHrp)
	
	Debris:AddItem(lv, .1)
end

--//Main Module
local Attack = {}
local CombatData = setmetatable({}, { __mode = "k" })

local function GetData(Character)
	local Data = CombatData[Character]
	if not Data then
		Data = { LastHit = 0, Combo = 0, NextAttack = 0 }
		CombatData[Character] = Data
	end
	return Data
end

function Attack:M1(Character: Model)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return end
	local Animator = Humanoid.Animator::Animator
	if not CanAttack(Character) then 
		warn("Cant attack") return end
	
	local Player = Players:GetPlayerFromCharacter(Character)
	
	local Data = GetData(Character)
	local PlayerData = DataManager.WaitForData(Player)
	local Now = os.clock()
	if Now < Data.NextAttack then return end
	if not StateManager:HasState(Character, "Equipped") then
		return
	end
	
	local Hrp = Character.HumanoidRootPart::BasePart
	
	local WeaponAnimations = GetAnimations(PlayerData.Weapon)::Folder

	if Now - Data.LastHit > Config.ComboTimeout or Data.Combo >= Config.MaxCombo then
		Data.Combo = 1
	else
		Data.Combo += 1
	end
	
	Data.LastHit = Now
	
	local cdindex = Data.Combo == Config.MaxCombo and 2 or 1
	Data.NextAttack = Now + Config.ComboCd[cdindex]
	
	StateManager:AddState(Character, "Attacking", Config.ComboCd[cdindex])
	
	local Weapon = Character:FindFirstChild(PlayerData.Weapon)
	if not Weapon then return end
	local Part = Weapon:IsA("Model") and Weapon:FindFirstChild("Handle") or Weapon
	
	local SwingAnim = WeaponAnimations:FindFirstChild("M"..Data.Combo)
	local SwingTrack = Animator:LoadAnimation(SwingAnim)
	SwingTrack.Looped=false
	SwingTrack:Play()
	
	SwingTrack:GetMarkerReachedSignal("Swing"):Connect(function()
		local SoundTrack = Sounds.SwordSwing:Clone()
		SoundTrack.PlayOnRemove = true
		
		SoundTrack:Destroy()
		
		MovementEffects.SlowDown(Humanoid, 2, Config.M1SlowdownDuration)
		
		Push(Hrp, Hrp, Config.Push)
	end)
	
	SwingTrack:GetMarkerReachedSignal("Hit"):Connect(function()
		local Blade = Weapon:FindFirstChild("Blade")::BasePart
		
		local Hitbox = ShapecastHitbox.new(Blade)
		Hitbox:Reconcile()
		
		local HitCharacters = {}
		
		Hitbox:OnHit(function(Result, Point, Direction)
			local HitPart = Result.Instance
			local HitCharacter = HitPart:FindFirstAncestorOfClass("Model")
			local HitHumanoid = HitCharacter and HitCharacter:FindFirstChildOfClass("Humanoid")
			
			if HitHumanoid == Humanoid then return end
			
			if HitHumanoid and HitCharacter ~= Part and not HitCharacters[HitCharacter] then
				print("Hit character:", Character.Name)
				HitHumanoid:TakeDamage(10)
				
				HitCharacters[HitCharacter] = true
				
				local HitHighlight = Effects.HitHighlight:Clone()
				HitHighlight.Parent = HitCharacter
				
				local HitAnimator = HitHumanoid.Animator::Animator
				local HitAnimation = Animations.Reactions:FindFirstChild("Hit".. Data.Combo)
				local HitTrack = HitAnimator:LoadAnimation(HitAnimation)
				HitTrack:Play()
				
				Debris:AddItem(HitTrack, HitTrack.Length)
				Debris:AddItem(HitHighlight, Config.HighlightDuration)

				Push(Hrp, HitCharacter.HumanoidRootPart, 
					Data.Combo == Config.MaxCombo and Config.Knockback[2] or Config.Knockback[1]
				)
			end
		end)
		
		Hitbox:HitStart(.6)
		Hitbox:OnStopped(function()
			
		end)
	end)
end

function Attack:Critical(Character:Model)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return end
	if not CanAttack(Character) then return end

	local Player = Players:GetPlayerFromCharacter(Character)
	
	if not StateManager:HasState(Character, "Equipped") then
		return
	end
	
	local Data = GetData(Character)
	local PlayerData = DataManager.WaitForData(Player)
	
	local EquippedWeapon = PlayerData.Weapon
	
	if Criticals[EquippedWeapon] then
		Criticals[EquippedWeapon]()
	end
end

return Attack

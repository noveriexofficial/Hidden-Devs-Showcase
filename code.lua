-- CREATED BY NOVERIEX
-- This program is utilised in my game as the setup and UI for the ingame delivery upgrade station, you can check it out in SKYLINE.

--------------------------------------------
------------ DEFINE VARIABLES --------------
--------------------------------------------

---------------- SERVICES ------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

---------------- CONSTANTS -----------------

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Events = ReplicatedStorage:WaitForChild("Events")
local LocalEvents = Events:WaitForChild("Local")
local RemoteEvents = Events:WaitForChild("Remote")
local DeliveryRemotes = RemoteEvents:WaitForChild("Delivery")

local SFXLibrary = ReplicatedStorage:WaitForChild("SFXLibrary")
local UISFX = SFXLibrary:WaitForChild("UI")
local FrameSFX = UISFX:WaitForChild("Frame")
local TerminalSFX = FrameSFX:WaitForChild("Terminal")

------------- MODULES/PACKAGES -------------

local TypeDefinitions = require(ReplicatedStorage.Modules.CentralLibrary.CentralL.TypeDefinitions)
local ClientUI: ClientUI = require(ReplicatedStorage.Modules.CentralLibrary.CentralL.ClientUI)

local UpgradeConfig = require(ReplicatedStorage.Configuration.UpgradeConfig)

local Data = Player:WaitForChild("Data", 5) 
local ExperienceConfig = require(ReplicatedStorage.Configuration.AwardModule)

------------------ TYPES -------------------

type CentralLibrary = TypeDefinitions.CentralLibrary
type ClientUI = TypeDefinitions.ClientUI

--------------------------------------------

local DeliveryUI: DeliveryUI = {}
DeliveryUI.__index = DeliveryUI

---------------- COLOR CONSTANTS -----------

local COLOR_ACCEPTED = Color3.fromRGB(229, 255, 222)
local COLOR_DECLINED = Color3.fromRGB(255, 221, 221)
local COLOR_NEUTRAL = Color3.fromRGB(255, 255, 255)

-- Terminal Status Colors
local STATUS_COLOR_WHITE = Color3.fromRGB(255, 255, 255)
local STATUS_COLOR_YELLOW = Color3.fromRGB(255, 255, 120)
local STATUS_COLOR_GREEN = Color3.fromRGB(120, 255, 120)
local STATUS_COLOR_RED = Color3.fromRGB(255, 120, 120)

-- Terminal UI Palette Colors
local UI_COLOR_GREEN = Color3.fromRGB(100, 255, 100)
local UI_COLOR_ORANGE = Color3.fromRGB(255, 170, 0)
local UI_COLOR_RED = Color3.fromRGB(255, 100, 100)
local UI_COLOR_LIGHT_RED = Color3.fromRGB(255, 120, 120)

-- Beam Colors
local BEAM_COLOR_GREEN = ColorSequence.new(Color3.fromRGB(35, 255, 11))
local BEAM_COLOR_YELLOW = ColorSequence.new(Color3.fromRGB(255, 255, 0))

---------------- HELPER FUNCTIONS ----------

local function FormatTime(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	return string.format("%02d:%02d", m, s)
end

local function IsMaxLevel(): boolean
	local currentLevel = 0
	if Data then
		local unlockedUpgrades = Data:FindFirstChild("UnlockedUpgrades")
		if unlockedUpgrades then
			local terminalUpgrade = unlockedUpgrades:FindFirstChild("TerminalUpgrade")
			if terminalUpgrade then
				currentLevel = terminalUpgrade.Value
			end
		end
	end
	return UpgradeConfig["TerminalLevel" .. (currentLevel + 1)] == nil
end

local function CreateColorPalette(baseColor: Color3?)
	if not baseColor then return nil end
	return {
		Text = baseColor:Lerp(Color3.new(1, 1, 1), 0.3),
		UIStroke = baseColor,
		TextStroke = baseColor:Lerp(Color3.new(0, 0, 0), 0.4),
		Image = baseColor,
		Background = baseColor:Lerp(Color3.new(0, 0, 0), 0.6)
	}
end

local function ApplyOptionPalette(optionFrame: Frame?, palette: any, text: string)
	if not optionFrame or not palette then return end

	local textLabel = optionFrame:FindFirstChild("TextLabel") :: TextLabel
	local uiStroke = optionFrame:FindFirstChild("UIStroke") :: UIStroke
	local imageLabel = optionFrame:FindFirstChild("ImageLabel") :: ImageLabel

	if textLabel then
		textLabel.Text = text
		textLabel.TextColor3 = palette.Text
		local textStroke = textLabel:FindFirstChild("UIStroke") :: UIStroke
		if textStroke then textStroke.Color = palette.TextStroke end
	end

	if uiStroke then uiStroke.Color = palette.UIStroke end
	if imageLabel then imageLabel.ImageColor3 = palette.Image end
	optionFrame.BackgroundColor3 = palette.Background
end

local function FlashOfferReceived()
	local statusEffect = Lighting:FindFirstChild("DeliveryStatus") :: ColorCorrectionEffect
	if not statusEffect then return end

	statusEffect.Enabled = true
	statusEffect.Brightness = 0.25
	statusEffect.Contrast = 0.35
	statusEffect.Saturation = 0.1
	statusEffect.TintColor = COLOR_NEUTRAL

	local tween = TweenService:Create(
		statusEffect,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Brightness = 0,
			Contrast = 0,
			Saturation = 0,
		}
	)

	tween:Play()
	tween.Completed:Connect(function()
		statusEffect.Enabled = false
	end)
end

local function FlashDeliveryStatus(targetColor: Color3)
	local statusEffect = Lighting:FindFirstChild("DeliveryStatus") :: ColorCorrectionEffect
	if not statusEffect then return end

	statusEffect.Enabled = true
	statusEffect.Brightness = -0.2
	statusEffect.Contrast = 0.1
	statusEffect.Saturation = 0.2
	statusEffect.TintColor = targetColor

	local fadeTween = TweenService:Create(
		statusEffect,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Brightness = 0,
			Contrast = 0,
			Saturation = 0,
			TintColor = COLOR_NEUTRAL
		}
	)

	fadeTween:Play()
	fadeTween.Completed:Connect(function()
		statusEffect.Enabled = false
	end)
end

--------------------------------------------
-------------- INITIALIZATION --------------
--------------------------------------------

function DeliveryUI.init(CentralLibrary: CentralLibrary)
	local self: DeliveryUI = setmetatable({}, DeliveryUI)

	self.CentralLibrary = CentralLibrary
	self.MainUI = Player.PlayerGui:WaitForChild("MainUI")

	while not _G.PlayerHUD do
		task.wait()
	end
	self.DeliveryUI = _G.PlayerHUD:WaitForChild("Deliveries")

	self.AvailablePackages = self.DeliveryUI:WaitForChild("AvailablePackages")
	self.PackageTemplate = self.AvailablePackages:WaitForChild("PackageTemplate")
	self.PackageTemplate.Visible = false

	self.InformationFrame = self.DeliveryUI:WaitForChild("Information")
	self.TimeLeftText = self.InformationFrame:WaitForChild("TimeLeft")
	self.DistanceNeededText = self.InformationFrame:WaitForChild("DistanceNeeded")

	self.TitleText = self.DeliveryUI:WaitForChild("Title")
	self.PackageText = self.DeliveryUI:WaitForChild("Package")

	self.IsActive = false
	self.IsQueued = false
	self.PendingOffer = nil
	self.CurrentDestinationPosition = Vector3.zero
	self.NearestTerminal = nil
	self.EndTime = 0
	self.TerminalAnimId = 0

	self.TerminalTweens = {}
	self.CurrentTerminalState = "IDLE"

	self.OriginalTimeColor = self.TimeLeftText.TextColor3
	self.OriginalDistanceColor = self.DistanceNeededText.TextColor3
	self.OriginalPackageColor = self.PackageText.TextColor3

	self.DeliveryUI.Visible = false

	self:InitializeTerminals()

	if Player.Character then
		self:OnCharacterAdded(Player.Character)
	end

	Player.CharacterAdded:Connect(function(...)
		self:OnCharacterAdded(...)
	end)

	self:ConnectInputs()
	self:ConnectRemotes()
	CentralLibrary:ConnectToRenderStepped(self, self.OnRenderStepped)

	return self
end

function DeliveryUI:OnCharacterAdded(character)
	self.Character = character
	self.Humanoid = character:WaitForChild("Humanoid")
	self.PrimaryPart = character:WaitForChild("HumanoidRootPart")
end

--------------------------------------------
-------- TERMINAL SCREEN MANAGEMENT --------
--------------------------------------------

function DeliveryUI:SetupTerminalBeams(terminal: Instance)
	local terminalBeam = terminal:FindFirstChild("TerminalBeam", true) or (terminal.Parent and terminal.Parent:FindFirstChild("TerminalBeam", true))
	if not terminalBeam then return end

	local beam = terminalBeam:FindFirstChildOfClass("Beam") or terminalBeam:FindFirstChild("Beam")
	if not beam then return end

	if not terminalBeam:FindFirstChild("BeamFadeProxy") then
		local proxy = Instance.new("NumberValue")
		proxy.Name = "BeamFadeProxy"
		proxy.Value = 1 
		proxy.Parent = terminalBeam

		proxy.Changed:Connect(function(v)
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, math.clamp(v, 0, 1)),
				NumberSequenceKeypoint.new(0.439, math.clamp(0.705 + (1 - 0.705) * v, 0, 1)),
				NumberSequenceKeypoint.new(1, 1)
			})
		end)

		beam.Transparency = NumberSequence.new(1)

		if self.CurrentTerminalState == "QUEUED" or self.CurrentTerminalState == "OFFER" then
			beam.Color = BEAM_COLOR_YELLOW
		else
			beam.Color = BEAM_COLOR_GREEN
		end
	end
end

function DeliveryUI:UpdateAllBeamVisibilities()
	local terminals = CollectionService:GetTagged("DeliveryTerminal")
	for _, terminal in ipairs(terminals) do
		self:UpdateBeamVisibility(terminal)
	end
end

function DeliveryUI:UpdateBeamVisibility(terminal: Instance)
	local terminalBeam = terminal:FindFirstChild("TerminalBeam", true) or (terminal.Parent and terminal.Parent:FindFirstChild("TerminalBeam", true))
	if not terminalBeam then return end

	local proxy = terminalBeam:FindFirstChild("BeamFadeProxy")
	if not proxy then return end

	local shouldHide = self.IsActive or (self.NearestTerminal == terminal)
	local targetValue = shouldHide and 1 or 0

	TweenService:Create(proxy, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = targetValue}):Play()
end

function DeliveryUI:SetupTerminalScreens(terminal: Instance)
	local screens = terminal:FindFirstChild("Screens") or (terminal.Parent and terminal.Parent:FindFirstChild("Screens"))
	if not screens then return end

	local mainScreenPart = screens:FindFirstChild("MainScreen")
	if mainScreenPart and not mainScreenPart:FindFirstChildOfClass("SurfaceGui") then
		local mainScreenUI = script:FindFirstChild("MainScreenUI")
		if mainScreenUI then
			local clone = mainScreenUI:Clone()
			clone.Parent = mainScreenPart
		end
	end

	local topScreenPart = screens:FindFirstChild("TopScreen")
	if topScreenPart and not topScreenPart:FindFirstChildOfClass("SurfaceGui") then
		local topScreenUI = script:FindFirstChild("TopScreenUI")
		if topScreenUI then
			local clone = topScreenUI:Clone()
			clone.Parent = topScreenPart
		end
	end
end

function DeliveryUI:GetCurrentStatusLabel(terminal: Instance)
	local screens = terminal:FindFirstChild("Screens") or (terminal.Parent and terminal.Parent:FindFirstChild("Screens"))
	if not screens then return nil end

	local topScreen = screens:FindFirstChild("TopScreen")
	if topScreen then
		local surfaceGui = topScreen:FindFirstChildOfClass("SurfaceGui")
		if surfaceGui then
			local blackout = surfaceGui:FindFirstChild("Blackout")
			if blackout then
				local mainFrame = blackout:FindFirstChild("Main")
				if mainFrame then
					return mainFrame:FindFirstChild("CurrentStatus") :: TextLabel?
				end
			end
		end
	end

	return nil
end

function DeliveryUI:ApplyStatusToLabel(label: TextLabel, state: string)
	if self.TerminalTweens[label] then
		self.TerminalTweens[label]:Cancel()
		self.TerminalTweens[label] = nil
	end

	local pulseTweenInfo = TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local flashTweenInfo = TweenInfo.new(1.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	if state == "ACTIVE" then
		label.Text = "IN DELIVERY SESSION"
		label.TextColor3 = STATUS_COLOR_WHITE

		local pulseTween = TweenService:Create(label, pulseTweenInfo, {TextColor3 = STATUS_COLOR_YELLOW})
		self.TerminalTweens[label] = pulseTween
		pulseTween:Play()

	elseif state == "QUEUED" then
		label.Text = "IN DELIVERY QUEUE"
		label.TextColor3 = STATUS_COLOR_GREEN

		local flashTween = TweenService:Create(label, flashTweenInfo, {TextColor3 = STATUS_COLOR_WHITE})
		self.TerminalTweens[label] = flashTween
		flashTween:Play()

		flashTween.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				if self.TerminalTweens[label] == flashTween then
					local pulseTween = TweenService:Create(label, pulseTweenInfo, {TextColor3 = STATUS_COLOR_GREEN})
					self.TerminalTweens[label] = pulseTween
					pulseTween:Play()
				end
			end
		end)

	elseif state == "OFFER" then
		label.Text = "DELIVERY FOUND"
		label.TextColor3 = STATUS_COLOR_YELLOW

		local flashTween = TweenService:Create(label, flashTweenInfo, {TextColor3 = STATUS_COLOR_WHITE})
		self.TerminalTweens[label] = flashTween
		flashTween:Play()

	elseif state == "IDLE" then
		label.Text = "DELIVERY TERMINAL"
		label.TextColor3 = STATUS_COLOR_RED

		local flashTween = TweenService:Create(label, flashTweenInfo, {TextColor3 = STATUS_COLOR_WHITE})
		self.TerminalTweens[label] = flashTween
		flashTween:Play()

	elseif state == "UPGRADE" then
		label.Text = "UPGRADE TERMINAL"
		label.TextColor3 = STATUS_COLOR_WHITE

		local flashTween = TweenService:Create(label, flashTweenInfo, {TextColor3 = STATUS_COLOR_WHITE})
		self.TerminalTweens[label] = flashTween
		flashTween:Play()
	end
end

function DeliveryUI:UpdateTerminalState(newState: string)
	self.CurrentTerminalState = newState
	local terminals = CollectionService:GetTagged("DeliveryTerminal")

	local beamColor = BEAM_COLOR_GREEN
	if newState == "QUEUED" or newState == "OFFER" then
		beamColor = BEAM_COLOR_YELLOW
	end

	for _, terminal in ipairs(terminals) do
		local statusLabel = self:GetCurrentStatusLabel(terminal)
		if statusLabel and statusLabel:IsA("TextLabel") then
			self:ApplyStatusToLabel(statusLabel, self.CurrentTerminalState)
		end
		self:UpdateTerminalMainUI(terminal, self.CurrentTerminalState)

		local terminalBeam = terminal:FindFirstChild("TerminalBeam", true) or (terminal.Parent and terminal.Parent:FindFirstChild("TerminalBeam", true))
		if terminalBeam then
			local beam = terminalBeam:FindFirstChildOfClass("Beam") or terminalBeam:FindFirstChild("Beam")
			if beam then
				beam.Color = beamColor
			end
		end

		local targetPart = terminal:IsA("BasePart") and terminal or terminal:FindFirstChildWhichIsA("BasePart")
		if targetPart then
			local sonarPing = targetPart:FindFirstChild("SonarPing")
			if sonarPing then
				if newState == "QUEUED" then
					if not sonarPing.IsPlaying then sonarPing:Play() end
				else
					if sonarPing.IsPlaying then sonarPing:Stop() end
				end
			end
		end

		if newState ~= "OFFER" then
			self:ScaleTerminalDeliveries(terminal, 0)
		end

		if newState ~= "UPGRADE" and self.NearestTerminal then
			for _, mainFrame in ipairs(self:GetTerminalMainFrames(self.NearestTerminal)) do
				local upgradeFrame = mainFrame:FindFirstChild("UpgradeFrame")
				if upgradeFrame then upgradeFrame.Visible = false end
			end
		end
	end

	if self.NearestTerminal then
		self:UpdateTerminalPrompt()
	end
end

function DeliveryUI:UpdateTerminalMainUI(terminal: Instance, state: string)
	local mainFrames = self:GetTerminalMainFrames(terminal)
	for _, mainFrame in ipairs(mainFrames) do
		local actionLabel = mainFrame:FindFirstChild("Action")
		local selector = mainFrame:FindFirstChild("SelectorFrame")

		if actionLabel then
			if state == "OFFER" or state == "UPGRADE" then
				actionLabel.Visible = false
			else
				actionLabel.Visible = true
				if state == "IDLE" then
					actionLabel.Text = "DELIVERIES AVAILABLE"
				elseif state == "QUEUED" then
					actionLabel.Text = "SCANNING DELIVERIES"
				end
			end
		end

		if selector then
			local optionA = selector:FindFirstChild("OptionA")
			local optionB = selector:FindFirstChild("OptionB")

			if state == "IDLE" then
				if optionA then optionA.Visible = true; ApplyOptionPalette(optionA, CreateColorPalette(UI_COLOR_GREEN), "ENTER DELIVERY") end
				if optionB then 
					if IsMaxLevel() then
						optionB.Visible = false
					else
						optionB.Visible = true; ApplyOptionPalette(optionB, CreateColorPalette(UI_COLOR_ORANGE), "UPGRADE DELIVERY") 
					end
				end
			elseif state == "QUEUED" then
				if optionA then optionA.Visible = true; ApplyOptionPalette(optionA, CreateColorPalette(UI_COLOR_LIGHT_RED), "LEAVE QUEUE") end
				if optionB then optionB.Visible = false end
			elseif state == "OFFER" then
				if optionA then optionA.Visible = true; ApplyOptionPalette(optionA, CreateColorPalette(UI_COLOR_GREEN), "ACCEPT DELIVERY") end
				if optionB then optionB.Visible = true; ApplyOptionPalette(optionB, CreateColorPalette(UI_COLOR_RED), "DECLINE DELIVERY") end
			elseif state == "UPGRADE" then
				if optionA then optionA.Visible = true; ApplyOptionPalette(optionA, CreateColorPalette(UI_COLOR_GREEN), "CONFIRM UPGRADE") end
				if optionB then optionB.Visible = true; ApplyOptionPalette(optionB, CreateColorPalette(UI_COLOR_LIGHT_RED), "RETURN") end
			end
		end
	end
end

function DeliveryUI:ScaleTerminalDeliveries(terminal: Instance?, scale: number, offerData: any?)
	local terminals = terminal and {terminal} or CollectionService:GetTagged("DeliveryTerminal")

	for _, term in ipairs(terminals) do
		local mainFrames = self:GetTerminalMainFrames(term)
		for _, mainFrame in ipairs(mainFrames) do
			local deliveriesFrame = mainFrame:FindFirstChild("Deliveries")
			if deliveriesFrame then
				if offerData then
					local infoFrame = deliveriesFrame:FindFirstChild("Information")
					if infoFrame then
						local timeText = infoFrame:FindFirstChild("TimeLeft")
						local distText = infoFrame:FindFirstChild("DistanceNeeded")
						if timeText then timeText.Text = "REWARD: $" .. tostring(offerData.Reward or 0) end
						if distText then distText.Text = "STOPS: " .. tostring(offerData.TotalDeliveries or 1) end
					end
					local packageText = deliveriesFrame:FindFirstChild("Package")
					if packageText then packageText.Text = string.upper(offerData.DisplayName or "Unknown Contract") end
				end

				local uiScale = deliveriesFrame:FindFirstChild("Scale") or deliveriesFrame:FindFirstChildOfClass("UIScale")
				if uiScale and uiScale:IsA("UIScale") then
					TweenService:Create(uiScale, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = scale}):Play()
				end
			end
		end
	end
end

function DeliveryUI:InitializeTerminalUI(terminal: Instance)
	local mainFrames = self:GetTerminalMainFrames(terminal)
	for _, mainFrame in ipairs(mainFrames) do
		local deliveriesFrame = mainFrame:FindFirstChild("Deliveries")
		if deliveriesFrame then
			local uiScale = deliveriesFrame:FindFirstChild("Scale") or deliveriesFrame:FindFirstChildOfClass("UIScale")
			if uiScale and uiScale:IsA("UIScale") then
				uiScale.Scale = 0
			end
		end

		local upgradeFrame = mainFrame:FindFirstChild("UpgradeFrame")
		if upgradeFrame then
			upgradeFrame.BackgroundTransparency = 1
			upgradeFrame.Visible = false
			local upgradeMain = upgradeFrame:FindFirstChild("Main")
			if upgradeMain then
				local uiScale = upgradeMain:FindFirstChildOfClass("UIScale")
				if uiScale then
					uiScale.Scale = 0
				end
			end
		end

		local selector = mainFrame:FindFirstChild("SelectorFrame")
		local leftHitbox = mainFrame:FindFirstChild("LeftHitbox") :: TextButton
		local rightHitbox = mainFrame:FindFirstChild("RightHitbox") :: TextButton

		if selector and leftHitbox and rightHitbox then
			local optionA = selector:FindFirstChild("OptionA") :: Frame
			local optionB = selector:FindFirstChild("OptionB") :: Frame

			leftHitbox.MouseEnter:Connect(function()
				if optionA and optionA.Visible then
					TweenService:Create(optionA, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
				end
			end)
			leftHitbox.MouseLeave:Connect(function()
				if optionA then
					TweenService:Create(optionA, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
				end
			end)
			leftHitbox.Activated:Connect(function()
				if self.CurrentTerminalState == "IDLE" then
					self:ToggleQueue(true)
				elseif self.CurrentTerminalState == "QUEUED" then
					self:ToggleQueue(false)
				elseif self.CurrentTerminalState == "OFFER" then
					self:RespondToOffer(true)
				elseif self.CurrentTerminalState == "UPGRADE" then
					self:CloseUpgradeUI(terminal)
				end
			end)

			rightHitbox.MouseEnter:Connect(function()
				if optionB and optionB.Visible then
					TweenService:Create(optionB, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
				end
			end)
			rightHitbox.MouseLeave:Connect(function()
				if optionB then
					TweenService:Create(optionB, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
				end
			end)
			rightHitbox.Activated:Connect(function()
				if self.CurrentTerminalState == "IDLE" then
					if not IsMaxLevel() then
						self:OpenUpgradeUI(terminal)
					end
				elseif self.CurrentTerminalState == "OFFER" then
					self:RespondToOffer(false)
				elseif self.CurrentTerminalState == "UPGRADE" then
					self:ConfirmUpgrade(terminal)
				end
			end)
		end

		local playerInfo = mainFrame:FindFirstChild("PlayerInformation")

		if playerInfo then
			local playerImageFrame = playerInfo:FindFirstChild("PlayerImage")
			if playerImageFrame then
				local playerImage = playerImageFrame:FindFirstChild("PlayerImage")
				if playerImage then
					task.spawn(function()
						playerImage.Image = Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
					end)
				end
			end
		end

		local function UpdateStats()
			if playerInfo and Data then
				local playerImageFrame = playerInfo:FindFirstChild("PlayerImage")
				local playerData = playerInfo:FindFirstChild("PlayerData")
				local playerXPBar = playerInfo:FindFirstChild("PlayerXPBar")
				local rankData = Data:FindFirstChild("RankData")

				if playerImageFrame and rankData and rankData:FindFirstChild("Level") then
					local playerLevelText = playerImageFrame:FindFirstChild("PlayerLevel")
					if playerLevelText then playerLevelText.Text = tostring(rankData.Level.Value) end
				end

				if playerData then
					local playerName = playerData:FindFirstChild("PlayerName")
					if playerName then playerName.Text = Player.DisplayName:upper() end

					local creditsVal = Data:FindFirstChild("Credits")
					local creditsText = playerData:FindFirstChild("Credits")
					if creditsText and creditsVal then
						creditsText.Text = tostring(creditsVal.Value) .. "CR"
					end
				end

				if playerXPBar and rankData and rankData:FindFirstChild("Experience") and rankData:FindFirstChild("Level") and ExperienceConfig then
					local currentXP = rankData.Experience.Value
					local requiredXP = ExperienceConfig.RequiredXP(rankData.Level.Value)
					local expRatio = math.clamp(currentXP / math.max(1, requiredXP), 0, 1)

					local bar = playerXPBar:FindFirstChild("Bar")
					if bar then bar.Size = UDim2.fromScale(expRatio, 1) end

					local expLeft = playerXPBar:FindFirstChild("EXPLeft")
					if expLeft then
						expLeft.Text = math.round(requiredXP - currentXP) .. "XP LEFT"
						local barGradient = expLeft:FindFirstChild("BarGradient")
						if barGradient then barGradient.Offset = Vector2.new(expRatio, 0) end
					end
				end
			end

			if Data then
				local unlockedUpgrades = Data:FindFirstChild("UnlockedUpgrades")
				local terminalUpgrade = unlockedUpgrades and unlockedUpgrades:FindFirstChild("TerminalUpgrade")

				if terminalUpgrade then
					local currentLevel = terminalUpgrade.Value

					local levelBarOuter = mainFrame:FindFirstChild("LevelBar")
					if levelBarOuter then
						local levelText = levelBarOuter:FindFirstChild("Level")
						if levelText and levelText:IsA("TextLabel") then
							levelText.Text = "LEVEL " .. tostring(currentLevel)
						end

						local levelBarInner = levelBarOuter:FindFirstChild("LevelBar")
						if levelBarInner then
							for i = 1, 5 do
								local blip = levelBarInner:FindFirstChild(tostring(i))
								if blip and blip:IsA("Frame") then
									if i <= currentLevel then
										blip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
										blip.BackgroundTransparency = 0.2
									else
										blip.BackgroundColor3 = Color3.fromRGB(111, 111, 111)
										blip.BackgroundTransparency = 0.8
									end
								end
							end
						end
					end
				end
			end
		end

		UpdateStats()

		if Data then
			local creditsVal = Data:FindFirstChild("Credits")
			if creditsVal then creditsVal:GetPropertyChangedSignal("Value"):Connect(UpdateStats) end

			local rankData = Data:FindFirstChild("RankData")
			if rankData then
				local levelVal = rankData:FindFirstChild("Level")
				if levelVal then levelVal:GetPropertyChangedSignal("Value"):Connect(UpdateStats) end

				local expVal = rankData:FindFirstChild("Experience")
				if expVal then expVal:GetPropertyChangedSignal("Value"):Connect(UpdateStats) end
			end

			local unlockedUpgrades = Data:FindFirstChild("UnlockedUpgrades")
			if unlockedUpgrades then
				local terminalUpgrade = unlockedUpgrades:FindFirstChild("TerminalUpgrade")
				if terminalUpgrade then
					terminalUpgrade:GetPropertyChangedSignal("Value"):Connect(function()
						UpdateStats()
						self:UpdateTerminalMainUI(terminal, self.CurrentTerminalState)
						if self.NearestTerminal == terminal then
							self:UpdateTerminalPrompt()
						end
					end)
				end
			end
		end
	end
end

function DeliveryUI:GetTerminalMainFrames(terminal: Instance?)
	if not terminal then return {} end
	local screens = terminal:FindFirstChild("Screens") or (terminal.Parent and terminal.Parent:FindFirstChild("Screens"))
	if not screens then return {} end

	local mainFrames = {}
	for _, screenName in ipairs({"MainScreen"}) do
		local screenPart = screens:FindFirstChild(screenName)
		if screenPart then
			local surfaceGui = screenPart:FindFirstChildOfClass("SurfaceGui")
			if surfaceGui then
				local blackout = surfaceGui:FindFirstChild("Blackout")
				if blackout then
					local mainFrame = blackout:FindFirstChild("Main")
					if mainFrame then table.insert(mainFrames, mainFrame) end
				end
			end
		end
	end
	return mainFrames
end

function DeliveryUI:ResetTerminalScreens(terminal: Instance)
	local mainFrames = self:GetTerminalMainFrames(terminal)
	for _, frame in ipairs(mainFrames) do
		frame.Size = UDim2.new(0.01, 0, 0.01, 0)
	end

	local screens = terminal:FindFirstChild("Screens") or (terminal.Parent and terminal.Parent:FindFirstChild("Screens"))
	if screens then
		local topScreen = screens:FindFirstChild("TopScreen")
		if topScreen then
			local surfaceGui = topScreen:FindFirstChildOfClass("SurfaceGui")
			if surfaceGui then
				local blackout = surfaceGui:FindFirstChild("Blackout")
				if blackout then
					local topMain = blackout:FindFirstChild("Main")
					if topMain then topMain.Size = UDim2.new(0.98, 0, 0.98, 0) end
				end
			end
		end
	end
end

function DeliveryUI:SetupTerminalHum(terminal: Instance)
	local targetPart = terminal:IsA("BasePart") and terminal or terminal:FindFirstChildWhichIsA("BasePart")
	if targetPart then
		if not targetPart:FindFirstChild("Terminal_Hum") then
			local humSound = TerminalSFX.Terminal_Hum:Clone()
			humSound.Name = "Terminal_Hum"
			humSound.Looped = true
			humSound.Parent = targetPart
			humSound:Play()
		end

		if not targetPart:FindFirstChild("SonarPing") then
			local sourceSonar = TerminalSFX:FindFirstChild("SonarPing")
			if sourceSonar then
				local sonarSound = sourceSonar:Clone()
				sonarSound.Name = "SonarPing"
				sonarSound.Looped = true
				sonarSound.Parent = targetPart
			end
		end
	end
end

function DeliveryUI:InitializeTerminals()
	for _, terminal in ipairs(CollectionService:GetTagged("DeliveryTerminal")) do
		self:SetupTerminalScreens(terminal)
		self:ResetTerminalScreens(terminal)
		self:SetupTerminalHum(terminal)
		self:InitializeTerminalUI(terminal)
		self:SetupTerminalBeams(terminal)
	end

	self:UpdateTerminalState("IDLE")
	self:UpdateAllBeamVisibilities()

	CollectionService:GetInstanceAddedSignal("DeliveryTerminal"):Connect(function(terminal)
		self:SetupTerminalScreens(terminal)
		self:ResetTerminalScreens(terminal)
		self:SetupTerminalHum(terminal)
		self:InitializeTerminalUI(terminal)
		self:SetupTerminalBeams(terminal)

		local statusLabel = self:GetCurrentStatusLabel(terminal)
		if statusLabel and statusLabel:IsA("TextLabel") then
			self:ApplyStatusToLabel(statusLabel, self.CurrentTerminalState)
		end
		self:UpdateTerminalMainUI(terminal, self.CurrentTerminalState)
		self:UpdateBeamVisibility(terminal)
	end)
end

function DeliveryUI:AnimateTerminalScreens(terminal: Instance?, open: boolean)
	if not terminal then return end

	local mainFrames = self:GetTerminalMainFrames(terminal)
	if #mainFrames == 0 then return end

	local targetPart = terminal:IsA("BasePart") and terminal or terminal:FindFirstChildWhichIsA("BasePart")

	if targetPart then
		if open then
			local soundOn = TerminalSFX.Terminal_on:Clone()
			soundOn.Parent = targetPart
			soundOn:Play()
			Debris:AddItem(soundOn, soundOn.TimeLength + 1)

			local soundMenuOpen = TerminalSFX.MenuOpen:Clone()
			soundMenuOpen.Parent = targetPart
			soundMenuOpen:Play()
			Debris:AddItem(soundMenuOpen, soundMenuOpen.TimeLength + 1)
		else
			local soundOff = TerminalSFX.Terminal_off:Clone()
			soundOff.Parent = targetPart
			soundOff:Play()
			Debris:AddItem(soundOff, soundOff.TimeLength + 1)

			local soundHideUI = FrameSFX.HideUI:Clone()
			soundHideUI.Parent = targetPart
			soundHideUI:Play()
			Debris:AddItem(soundHideUI, soundHideUI.TimeLength + 1)
		end
	end

	self.TerminalAnimId = (self.TerminalAnimId or 0) + 1
	local currentAnimId = self.TerminalAnimId

	task.spawn(function()
		local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if open then
			for _, frame in ipairs(mainFrames) do TweenService:Create(frame, tweenInfo, { Size = UDim2.new(0.01, 0, 0.98, 0) }):Play() end
			task.wait(0.2)
			if self.TerminalAnimId ~= currentAnimId then return end
			for _, frame in ipairs(mainFrames) do TweenService:Create(frame, tweenInfo, { Size = UDim2.new(0.98, 0, 0.98, 0) }):Play() end
		else
			for _, frame in ipairs(mainFrames) do TweenService:Create(frame, tweenInfo, { Size = UDim2.new(0.01, 0, 0.98, 0) }):Play() end
			task.wait(0.2)
			if self.TerminalAnimId ~= currentAnimId then return end
			for _, frame in ipairs(mainFrames) do TweenService:Create(frame, tweenInfo, { Size = UDim2.new(0.01, 0, 0.01, 0) }):Play() end
		end
	end)
end

--------------------------------------------
----------- ACTION PROMPT HELPERS ----------
--------------------------------------------

function DeliveryUI:ShowOfferActionPrompts()
	if typeof(_G.ToggleUIAction) == "function" then
		_G.ToggleUIAction("DeliveryAccept", Enum.KeyCode.E, "ACCEPT")
		_G.ToggleUIAction("DeliveryDecline", Enum.KeyCode.R, "DECLINE")

		if self.NearestTerminal == nil then
			_G.ToggleUIAction("DeliveryExitQueue", Enum.KeyCode.X, "EXIT QUEUE")
		else
			_G.RemoveUIAction("DeliveryExitQueue")
		end
	end
end

function DeliveryUI:ClearActionPrompts()
	if typeof(_G.RemoveUIAction) == "function" then
		_G.RemoveUIAction("DeliveryAccept")
		_G.RemoveUIAction("DeliveryDecline")
		_G.RemoveUIAction("DeliveryExitQueue")
	end
end

function DeliveryUI:UpdateTerminalPrompt()
	if typeof(_G.ToggleUIAction) == "function" then
		_G.RemoveUIAction("TerminalInteract")
		_G.RemoveUIAction("DeliveryUpgrade")
		_G.RemoveUIAction("UpgradeConfirm")
		_G.RemoveUIAction("UpgradeReturn")

		if self.CurrentTerminalState == "IDLE" then
			local actionText = self.IsQueued and "LEAVE QUEUE" or "JOIN QUEUE"
			_G.ToggleUIAction("TerminalInteract", Enum.KeyCode.E, actionText)
			if not IsMaxLevel() then
				_G.ToggleUIAction("DeliveryUpgrade", Enum.KeyCode.U, "UPGRADE")
			end
		elseif self.CurrentTerminalState == "QUEUED" then
			_G.ToggleUIAction("TerminalInteract", Enum.KeyCode.X, "LEAVE QUEUE")
		elseif self.CurrentTerminalState == "UPGRADE" then
			_G.ToggleUIAction("UpgradeConfirm", Enum.KeyCode.E, "UPGRADE")
			_G.ToggleUIAction("UpgradeReturn", Enum.KeyCode.R, "RETURN")
		end
	end
end

function DeliveryUI:ClearTerminalPrompt()
	if typeof(_G.RemoveUIAction) == "function" then
		_G.RemoveUIAction("TerminalInteract")
		_G.RemoveUIAction("DeliveryUpgrade")
		_G.RemoveUIAction("UpgradeConfirm")
		_G.RemoveUIAction("UpgradeReturn")
	end
end

--------------------------------------------
-------------- INPUT HANDLING --------------
--------------------------------------------

function DeliveryUI:ConnectInputs()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if self.CurrentTerminalState == "UPGRADE" then
			if input.KeyCode == Enum.KeyCode.E then
				self:ConfirmUpgrade(self.NearestTerminal)
				return
			elseif input.KeyCode == Enum.KeyCode.R then
				self:CloseUpgradeUI(self.NearestTerminal)
				return
			end
		end

		if input.KeyCode == Enum.KeyCode.X and self.IsQueued then
			local isNearTerminal = (self.NearestTerminal ~= nil)
			local hasPendingOffer = (self.PendingOffer ~= nil)

			if isNearTerminal and not hasPendingOffer then
				self:ToggleQueue(false)
				return
			elseif not isNearTerminal and hasPendingOffer then
				self:RespondToOffer(false)
				self:ToggleQueue(false)
				return
			end
		end

		if input.KeyCode == Enum.KeyCode.E and self.NearestTerminal and not self.IsActive and not self.PendingOffer then
			self:ToggleQueue()
			return
		end

		if input.KeyCode == Enum.KeyCode.U and self.NearestTerminal and self.CurrentTerminalState == "IDLE" and not IsMaxLevel() then
			self:OpenUpgradeUI(self.NearestTerminal)
			return
		end

		if self.PendingOffer then
			if input.KeyCode == Enum.KeyCode.E then
				self:RespondToOffer(true)
			elseif input.KeyCode == Enum.KeyCode.R then
				self:RespondToOffer(false)
			end
		end
	end)
end

--------------------------------------------
-------------- QUEUE & OFFERS --------------
--------------------------------------------

function DeliveryUI:ConfirmUpgrade(terminal: Instance?)
	terminal = terminal or self.NearestTerminal
	if not terminal or IsMaxLevel() then return end

	local upgradeFunc = RemoteEvents:WaitForChild("PurchaseRemote")

	local currentLevel = 0
	if Data then
		local unlockedUpgrades = Data:FindFirstChild("UnlockedUpgrades")
		if unlockedUpgrades then
			local terminalUpgrade = unlockedUpgrades:FindFirstChild("TerminalUpgrade")
			if terminalUpgrade then
				currentLevel = terminalUpgrade.Value
			end
		end
	end

	local nextLevel = currentLevel + 1
	print("Current Terminal Level: " .. tostring(currentLevel) .. " | Requesting Upgrade: TerminalLevel" .. tostring(nextLevel))

	task.spawn(function() 
		local success = upgradeFunc:InvokeServer("TerminalLevel" .. tostring(nextLevel)) 

		if success then
			local purchaseSound = FrameSFX:FindFirstChild("Purchase")
			if purchaseSound then
				local soundClone = purchaseSound:Clone()
				soundClone.Parent = workspace
				soundClone:Play()
				Debris:AddItem(soundClone, soundClone.TimeLength + 4)
			end

			local Highlight = Instance.new("Highlight")
			Highlight.Parent = terminal.Parent
			Highlight.FillColor = Color3.fromRGB(124,181,121)
			Highlight.FillTransparency = 0.65
			Highlight.OutlineColor = Color3.fromRGB(159,255,152)
			Highlight.OutlineTransparency = 0.8

			TweenService:Create(Highlight,TweenInfo.new(.35,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{OutlineTransparency = 1,FillTransparency = 1}):Play()
			game.Debris:AddItem(Highlight,.35)
		else
			local ErrorSound = FrameSFX:FindFirstChild("Error")
			if ErrorSound then
				local soundClone = ErrorSound:Clone()
				soundClone.Parent = workspace
				soundClone:Play()
				Debris:AddItem(soundClone, soundClone.TimeLength + 4)
			end

			local Highlight = Instance.new("Highlight")
			Highlight.Parent = terminal.Parent
			Highlight.FillColor = Color3.fromRGB(181, 122, 122)
			Highlight.FillTransparency = 0.65
			Highlight.OutlineColor = Color3.fromRGB(255, 148, 148)
			Highlight.OutlineTransparency = 0.8

			print(Highlight)

			TweenService:Create(Highlight,TweenInfo.new(.35,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{OutlineTransparency = 1,FillTransparency = 1}):Play()
			game.Debris:AddItem(Highlight,.35)
		end

		self:CloseUpgradeUI(terminal)
	end)
end

function DeliveryUI:OpenUpgradeUI(terminal: Instance?)
	terminal = terminal or self.NearestTerminal
	if not terminal then return end

	self:UpdateTerminalState("UPGRADE")

	local currentLevel = 0
	if Data then
		local unlockedUpgrades = Data:FindFirstChild("UnlockedUpgrades")
		if unlockedUpgrades then
			local terminalUpgrade = unlockedUpgrades:FindFirstChild("TerminalUpgrade")
			if terminalUpgrade then
				currentLevel = terminalUpgrade.Value
			end
		end
	end

	local mainFrames = self:GetTerminalMainFrames(terminal)
	for _, mainFrame in ipairs(mainFrames) do
		local upgradeFrame = mainFrame:FindFirstChild("UpgradeFrame") :: Frame
		if not upgradeFrame then continue end

		local main = upgradeFrame:FindFirstChild("Main") :: Frame
		if not main then continue end

		local uiScale = main:FindFirstChildOfClass("UIScale")

		upgradeFrame.BackgroundTransparency = 1
		upgradeFrame.Visible = true
		if uiScale then uiScale.Scale = 0 end

		local TerminalConfig = UpgradeConfig["TerminalLevel"..currentLevel]
		local TerminalInfo = TerminalConfig.Information
		main.CurrentLevel.Level.Text = tostring(currentLevel)

		main.CurrentLevel.Deliveries.Title.Text = string.upper("["..TerminalInfo.Deliveries.Title .."]")
		main.CurrentLevel.Deliveries.Description.Text = TerminalInfo.Deliveries.Description

		main.CurrentLevel.Reward.Title.Text = string.upper("["..TerminalInfo.Reward.Title .."]")
		main.CurrentLevel.Reward.Description.Text = TerminalInfo.Reward.Description

		main.CurrentLevel.Timing.Title.Text = string.upper("[".. TerminalInfo.Timing.Title .."]")
		main.CurrentLevel.Timing.Description.Text = TerminalInfo.Timing.Description

		local NextTerminalConfig = UpgradeConfig["TerminalLevel"..currentLevel+1]
		if NextTerminalConfig then
			local TerminalInfo = NextTerminalConfig.Information
			main.NextLevel.Level.Text = tostring(currentLevel+1)

			main.NextLevel.Deliveries.Title.Text = string.upper("["..TerminalInfo.Deliveries.Title .."]")
			main.NextLevel.Deliveries.Description.Text = TerminalInfo.Deliveries.Description

			main.NextLevel.Reward.Title.Text = string.upper("["..TerminalInfo.Reward.Title .."]")
			main.NextLevel.Reward.Description.Text = TerminalInfo.Reward.Description

			main.NextLevel.Timing.Title.Text = string.upper("[".. TerminalInfo.Timing.Title .."]")
			main.NextLevel.Timing.Description.Text = TerminalInfo.Timing.Description

			main.NextLevel.Price.Text = "["..NextTerminalConfig.Price.."CR]"
		else
			main.NextLevel.Level.Text = "MAX"

			main.NextLevel.Deliveries.Title.Text = "[MAX CAPACITY REACHED]"
			main.NextLevel.Deliveries.Description.Text = "No further capacity upgrades available."

			main.NextLevel.Reward.Title.Text = "[MAX YIELD REACHED]"
			main.NextLevel.Reward.Description.Text = "No further reward upgrades available."

			main.NextLevel.Timing.Title.Text = "[MAX SPEED REACHED]"
			main.NextLevel.Timing.Description.Text = "Terminal processing is fully optimized."

			main.NextLevel.Price.Text = "[N/A]"

			local selector = mainFrame:FindFirstChild("SelectorFrame")
			if selector then
				local optionA = selector:FindFirstChild("OptionA")
				if optionA then optionA.Visible = false end
			end
		end

		TweenService:Create(upgradeFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.2
		}):Play()

		if uiScale then
			TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
				Scale = 1
			}):Play()
		end
	end

	local ShowUI = FrameSFX:WaitForChild("ShowUI"):Clone()
	ShowUI.Parent = workspace
	ShowUI:Play()
	Debris:AddItem(ShowUI, ShowUI.TimeLength + 4)
end

function DeliveryUI:CloseUpgradeUI(terminal: Instance?)
	terminal = terminal or self.NearestTerminal
	if not terminal then return end

	self:UpdateTerminalState("IDLE")

	local mainFrames = self:GetTerminalMainFrames(terminal)
	for _, mainFrame in ipairs(mainFrames) do
		local upgradeFrame = mainFrame:FindFirstChild("UpgradeFrame") :: Frame
		if not upgradeFrame then continue end

		local main = upgradeFrame:FindFirstChild("Main") :: Frame
		local uiScale = main and main:FindFirstChildOfClass("UIScale")

		TweenService:Create(upgradeFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1
		}):Play()

		if uiScale then
			local scaleTween = TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 0
			})
			scaleTween:Play()
			scaleTween.Completed:Connect(function()
				if uiScale.Scale == 0 then
					upgradeFrame.Visible = false
				end
			end)
		else
			upgradeFrame.Visible = false
		end
	end

	local HideUI = FrameSFX:WaitForChild("HideUI"):Clone()
	HideUI.Parent = workspace
	HideUI:Play()
	Debris:AddItem(HideUI, HideUI.TimeLength + 4)
end

function DeliveryUI:ToggleQueue(enable: boolean?)
	if self.IsActive then return end

	if enable == nil then self.IsQueued = not self.IsQueued else self.IsQueued = enable end

	if self.IsQueued then
		self:UpdateTerminalState("QUEUED")
	else
		self:UpdateTerminalState("IDLE")
	end

	local queueFolder = UISFX:FindFirstChild("Queue")
	local queueSFX = self.IsQueued 
		and (queueFolder and queueFolder:FindFirstChild("QueueJoin"))
		or (queueFolder and queueFolder:FindFirstChild("QueueLeave"))

	if queueSFX then
		local soundClone = queueSFX:Clone()
		soundClone.Parent = workspace
		soundClone:Play()
		Debris:AddItem(soundClone, soundClone.TimeLength + 4)
	end

	local toggleFunc = DeliveryRemotes:WaitForChild("ToggleQueue") :: RemoteFunction
	task.spawn(function() toggleFunc:InvokeServer(self.IsQueued) end)

	if not self.IsQueued and self.PendingOffer then
		self.PendingOffer = nil
		self.DeliveryUI.Visible = false
		self:ClearActionPrompts()
		self:UpdateTerminalState("IDLE")
	end

	if self.NearestTerminal then self:UpdateTerminalPrompt() end
end

function DeliveryUI:ShowOffer(offerData: any)
	if not offerData then return end
	self.PendingOffer = offerData
	self.IsActive = false

	self:ClearTerminalPrompt()

	print(offerData)

	self.TitleText.Text = "DELIVERY OFFER"
	self.PackageText.Text = string.upper(offerData.DisplayName or "Unknown Contract")
	self.PackageText.TextColor3 = self.OriginalPackageColor
	self.TimeLeftText.Text = "REWARD: $" .. tostring(offerData.Reward or 0)
	self.TimeLeftText.TextColor3 = self.OriginalTimeColor
	self.DistanceNeededText.Text = "STOPS: " .. tostring(offerData.TotalDeliveries or 1)
	self.DistanceNeededText.TextColor3 = self.OriginalDistanceColor
	self.AvailablePackages.Visible = false

	self.DeliveryUI.Visible = (self.NearestTerminal == nil)

	self:ShowOfferActionPrompts()
	FlashOfferReceived()

	self:UpdateTerminalState("OFFER")
	self:ScaleTerminalDeliveries(self.NearestTerminal, 1.5, offerData)

	local ShowUI = FrameSFX:WaitForChild("ShowUI"):Clone()
	ShowUI.Parent = workspace
	ShowUI:Play()
	Debris:AddItem(ShowUI, ShowUI.TimeLength + 4)
end

function DeliveryUI:RespondToOffer(accept: boolean)
	if not self.PendingOffer then return end
	self.PendingOffer = nil
	self:ClearActionPrompts()

	if accept then
		FlashDeliveryStatus(COLOR_ACCEPTED)
		local ShowUI = FrameSFX:WaitForChild("ShowUI"):Clone()
		ShowUI.Parent = workspace
		ShowUI:Play()
		Debris:AddItem(ShowUI, ShowUI.TimeLength + 4)
	else
		FlashDeliveryStatus(COLOR_DECLINED)
		self.DeliveryUI.Visible = false

		if self.IsQueued then
			self:UpdateTerminalState("QUEUED")
		else
			self:UpdateTerminalState("IDLE")
		end

		local HideUI = FrameSFX:WaitForChild("HideUI"):Clone()
		HideUI.Parent = workspace
		HideUI:Play()
		Debris:AddItem(HideUI, HideUI.TimeLength + 4)
	end

	local respondFunc = DeliveryRemotes:WaitForChild("RespondToOffer") :: RemoteFunction
	task.spawn(function() respondFunc:InvokeServer(accept) end)
end

--------------------------------------------
---------------- UI UPDATES ----------------
--------------------------------------------

function DeliveryUI:UpdateAvailablePackages(totalDeliveries: number, completedDeliveries: number)
	if totalDeliveries >= 2 then
		self.AvailablePackages.Visible = true
		for _, child in self.AvailablePackages:GetChildren() do
			if child:IsA("Frame") and child.Name ~= "PackageTemplate" then child:Destroy() end
		end
		for i = 1, totalDeliveries do
			local packageIcon = self.PackageTemplate:Clone()
			packageIcon.Name = "Package_" .. i
			packageIcon.Visible = true
			if i <= completedDeliveries then
				packageIcon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				packageIcon.BackgroundTransparency = 0.3
			end
			packageIcon.Parent = self.AvailablePackages
		end
	else
		self.AvailablePackages.Visible = false
	end
end

function DeliveryUI:HandlePayload(payload: any)
	if not payload then return end
	self.PendingOffer = nil
	self.IsActive = true
	self:ClearActionPrompts()
	self:ClearTerminalPrompt()

	self.CurrentDestinationPosition = payload.DestinationPosition or Vector3.zero
	self.EndTime = payload.EndTime or 0
	self.TimeLeftText.TextColor3 = self.OriginalTimeColor
	self.DistanceNeededText.TextColor3 = self.OriginalDistanceColor
	self.PackageText.TextColor3 = self.OriginalPackageColor
	self.TitleText.Text = "ACTIVE DELIVERY"
	self.PackageText.Text = string.upper(payload.DisplayName or "Unknown Package")

	self:UpdateAvailablePackages(payload.TotalDeliveries or 1, payload.CompletedDeliveries or 0)
	LocalEvents.DestinationEvent:Fire("DELIVERY DESTINATION", payload.DestinationPosition, Color3.fromRGB(255, 180, 50))
	self:UpdateTerminalState("ACTIVE")
	self:UpdateAllBeamVisibilities()
	self.DeliveryUI.Visible = true
end

function DeliveryUI:EndDelivery(isSuccess: boolean)
	self.IsActive = false
	self.PendingOffer = nil
	self:ClearActionPrompts()

	LocalEvents.DestinationEvent:Fire("DELIVERY DESTINATION", nil)

	if self.IsQueued then
		self:UpdateTerminalState("QUEUED")
	else
		self:UpdateTerminalState("IDLE")
	end

	self:UpdateAllBeamVisibilities()

	task.spawn(function()
		if isSuccess then
			self.TimeLeftText.Text = "X:XX"
			self.DistanceNeededText.Text = "Xm"
			self.TimeLeftText.TextColor3 = Color3.fromRGB(100, 100, 100)
			self.DistanceNeededText.TextColor3 = Color3.fromRGB(100, 100, 100)
			self.PackageText.Text = "DELIVERY COMPLETED"

			local flashGreen = TweenService:Create(self.PackageText, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(130, 255, 130)})
			flashGreen:Play()
			flashGreen.Completed:Wait()

			local flashWhite = TweenService:Create(self.PackageText, TweenInfo.new(0.3), {TextColor3 = Color3.fromRGB(255, 255, 255)})
			flashWhite:Play()
			task.wait(.3)
		else
			self.PackageText.Text = "DELIVERY FAILED"
			self.PackageText.TextColor3 = Color3.fromRGB(255, 100, 100)
			task.wait(.3)
		end
		self.DeliveryUI.Visible = false
	end)
end

--------------------------------------------
--------------- CONNECTIONS ----------------
--------------------------------------------

function DeliveryUI:ConnectRemotes()
	DeliveryRemotes:WaitForChild("OfferReceived").OnClientEvent:Connect(function(offerData)
		self:ShowOffer(offerData)
	end)

	DeliveryRemotes:WaitForChild("DeliveryStarted").OnClientEvent:Connect(function(payload)
		local ShowUI = FrameSFX:WaitForChild("ShowUI"):Clone()
		ShowUI.Parent = workspace
		ShowUI:Play()
		Debris:AddItem(ShowUI, ShowUI.TimeLength + 4)
		self:HandlePayload(payload)
	end)

	DeliveryRemotes:WaitForChild("DeliveryUpdated").OnClientEvent:Connect(function(payload)
		self:HandlePayload(payload)
	end)

	DeliveryRemotes:WaitForChild("DeliveryCompleted").OnClientEvent:Connect(function(payload)
		if Lighting:FindFirstChild("DeliveryCompleted") then
			Lighting.DeliveryCompleted.Brightness = 0.2
			Lighting.DeliveryCompleted.Contrast = 0.3
			Lighting.DeliveryCompleted.Saturation = 0.4
			Lighting.DeliveryCompleted.TintColor = Color3.fromRGB(223, 223, 223)

			TweenService:Create(Lighting.DeliveryCompleted, TweenInfo.new(.65, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
				{Brightness = 0, Contrast = 0, Saturation = 0, TintColor = COLOR_NEUTRAL}
			):Play()

			local DeliveryCompleted = ReplicatedStorage.SFXLibrary.UI.Player:WaitForChild("OnDelivery"):Clone()
			DeliveryCompleted.Parent = workspace
			DeliveryCompleted:Play()
			Debris:AddItem(DeliveryCompleted, DeliveryCompleted.TimeLength + 4)
		end
		self:HandlePayload(payload)
	end)

	DeliveryRemotes:WaitForChild("DeliveryFailed").OnClientEvent:Connect(function(reason, payload)
		self:EndDelivery(false)

		if Lighting:FindFirstChild("ContractCompleted") then
			Lighting.ContractCompleted.Contrast = -0.2
			Lighting.ContractCompleted.Brightness = -0.2
			Lighting.ContractCompleted.Saturation = -0.6
			Lighting.ContractCompleted.TintColor = Color3.fromRGB(175, 175, 175)

			TweenService:Create(Lighting.ContractCompleted, TweenInfo.new(1.65, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut),
				{Brightness = 0, Contrast = 0, Saturation = 0, TintColor = COLOR_NEUTRAL}
			):Play()
		end

		local OminousBoom = ReplicatedStorage.SFXLibrary.UI.Loss:WaitForChild("Defeat"):Clone()
		OminousBoom.Parent = workspace
		OminousBoom:Play()
		Debris:AddItem(OminousBoom, OminousBoom.TimeLength + 4)

		local LowerBoom = ReplicatedStorage.SFXLibrary.UI.Loss:WaitForChild("LowerBoom"):Clone()
		LowerBoom.Parent = workspace
		LowerBoom:Play()
		Debris:AddItem(LowerBoom, LowerBoom.TimeLength + 4)

		local ResultFrame = self.MainUI:FindFirstChild("ResultFrame")
		if ResultFrame then
			ResultFrame.Visible = true
			ResultFrame.Scale.Scale = 1
			ResultFrame.Crown.Visible = false
			ResultFrame.TextHolder.MainOutcome.StatusLabel.Text = "CONTRACT FAILED"

			local failureReason = typeof(reason) == "string" and reason or "CONTRACT FAILED"
			ResultFrame.TextHolder.Reason.StatusLabel.Text = string.upper(failureReason)

			local ShowUI = FrameSFX:WaitForChild("ShowUI"):Clone()
			ShowUI.Parent = workspace
			ShowUI:Play()
			Debris:AddItem(ShowUI, ShowUI.TimeLength + 4)

			task.delay(2, function()
				local HideUI = FrameSFX:WaitForChild("HideUI"):Clone()
				HideUI.Parent = workspace
				HideUI:Play()
				Debris:AddItem(HideUI, HideUI.TimeLength + 4)

				TweenService:Create(ResultFrame.Scale, TweenInfo.new(.55, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = 0}):Play()
				task.wait(.55)
				ResultFrame.Visible = false
			end)
		end
	end)

	DeliveryRemotes:WaitForChild("ContractCompleted").OnClientEvent:Connect(function(payload)
		if Lighting:FindFirstChild("ContractCompleted") then
			Lighting.ContractCompleted.Contrast = 1
			Lighting.ContractCompleted.Brightness = 0.3
			Lighting.ContractCompleted.Saturation = 0.3
			Lighting.ContractCompleted.TintColor = Color3.fromRGB(207, 207, 207)

			TweenService:Create(Lighting.ContractCompleted, TweenInfo.new(1.65, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut),
				{Brightness = 0, Contrast = 0, Saturation = 0, TintColor = COLOR_NEUTRAL}
			):Play()
		end

		local OnWin = ReplicatedStorage.SFXLibrary.UI.Player:WaitForChild("OnWin"):Clone()
		OnWin.Parent = workspace
		OnWin:Play()
		Debris:AddItem(OnWin, OnWin.TimeLength + 4)

		local ResultFrame = self.MainUI:FindFirstChild("ResultFrame")
		if ResultFrame then
			ResultFrame.Visible = true
			ResultFrame.Scale.Scale = 1
			ResultFrame.Crown.Visible = true
			ResultFrame.TextHolder.MainOutcome.StatusLabel.Text = "CONTRACT COMPLETE"

			local winReason = (payload and typeof(payload.Reason) == "string") and payload.Reason or "ALL DELIVERIES FINISHED"
			ResultFrame.TextHolder.Reason.StatusLabel.Text = string.upper(winReason)

			local ShowUI = FrameSFX:WaitForChild("ShowUI"):Clone()
			ShowUI.Parent = workspace
			ShowUI:Play()
			Debris:AddItem(ShowUI, ShowUI.TimeLength + 4)

			task.delay(2, function()
				local HideUI = FrameSFX:WaitForChild("HideUI"):Clone()
				HideUI.Parent = workspace
				HideUI:Play()
				Debris:AddItem(HideUI, HideUI.TimeLength + 4)

				TweenService:Create(ResultFrame.Scale, TweenInfo.new(.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = 0}):Play()
				task.wait(.4)
				ResultFrame.Visible = false
			end)
		end

		self:EndDelivery(true)
	end)
end

--------------------------------------------
--------------- RENDER LOOP ----------------
--------------------------------------------

function DeliveryUI:OnRenderStepped(DeltaTime: number)
	if not self.PrimaryPart or not self.PrimaryPart.Parent then return end

	if not self.IsActive then
		local terminals = CollectionService:GetTagged("DeliveryTerminal")
		local closestTerminal = nil
		local closestDistance = 10

		for _, terminal in ipairs(terminals) do
			local part = terminal:IsA("BasePart") and terminal or terminal:FindFirstChildWhichIsA("BasePart")
			if part then
				local dist = (self.PrimaryPart.Position - part.Position).Magnitude
				if dist <= closestDistance then
					closestDistance = dist
					closestTerminal = terminal
				end
			end
		end

		if closestTerminal ~= self.NearestTerminal then
			local previousTerminal = self.NearestTerminal
			self.NearestTerminal = closestTerminal

			if self.PendingOffer and not self.IsActive then
				self.DeliveryUI.Visible = (self.NearestTerminal == nil)
				self:ShowOfferActionPrompts()
			end

			if previousTerminal then 
				if self.CurrentTerminalState == "UPGRADE" then
					self:CloseUpgradeUI(previousTerminal)
				end

				self:AnimateTerminalScreens(previousTerminal, false) 
				self:UpdateBeamVisibility(previousTerminal)

				if self.CentralLibrary.CentralModules.CameraFramework then
					self.CentralLibrary.CentralModules.CameraFramework:RemoveCameraFace("TerminalLook")
				end
			end

			if self.NearestTerminal then
				if not self.PendingOffer then
					self:UpdateTerminalPrompt()
				end
				self:AnimateTerminalScreens(self.NearestTerminal, true)
				self:UpdateBeamVisibility(self.NearestTerminal)

				local targetPart = self.NearestTerminal:IsA("BasePart") and self.NearestTerminal or self.NearestTerminal:FindFirstChildWhichIsA("BasePart")
				if targetPart and targetPart:FindFirstChild("ViewPosition") then
					if self.CentralLibrary.CentralModules.CameraFramework then
						self.CentralLibrary.CentralModules.CameraFramework:SetCameraFace("TerminalLook", targetPart:FindFirstChild("ViewPosition").WorldPosition, 0.3, 15)
					end
				end
			else
				self:ClearTerminalPrompt()
			end
		end

		if self.CurrentTerminalState == "QUEUED" then
			local timer = Workspace:GetServerTimeNow()
			local dotsCount = (math.floor(timer * 1.5) % 4)
			local dots = string.rep(" .", dotsCount)
			local actionText = "SCANNING DELIVERIES" .. dots

			for _, terminal in ipairs(terminals) do
				for _, mainFrame in ipairs(self:GetTerminalMainFrames(terminal)) do
					local actionLabel = mainFrame:FindFirstChild("Action")
					if actionLabel and actionLabel.Visible then
						actionLabel.Text = actionText
					end
				end
			end
		end

	elseif self.NearestTerminal then
		self:AnimateTerminalScreens(self.NearestTerminal, false)
		self.NearestTerminal = nil
		self:ClearTerminalPrompt()

		if self.CentralLibrary.CentralModules.CameraFramework then
			self.CentralLibrary.CentralModules.CameraFramework:RemoveCameraFace("TerminalLook")
		end
	end

	if self.IsActive then
		local distance = (self.PrimaryPart.Position - self.CurrentDestinationPosition).Magnitude
		self.DistanceNeededText.Text = string.format("%dm", math.floor(distance))

		local timeLeft = math.max(0, self.EndTime - Workspace:GetServerTimeNow())
		self.TimeLeftText.Text = FormatTime(timeLeft)
	end
end

export type DeliveryUI = typeof(DeliveryUI) & {
	CentralLibrary: CentralLibrary,
	Character: TypeDefinitions.Character,
	Humanoid: Humanoid,
	PrimaryPart: BasePart,
	IsActive: boolean,
	IsQueued: boolean,
	PendingOffer: any?,
	NearestTerminal: Instance?,
	CurrentDestinationPosition: Vector3,
	EndTime: number,
	TerminalAnimId: number,
	TerminalTweens: {[TextLabel]: TweenBase},
	CurrentTerminalState: string
}

return DeliveryUI

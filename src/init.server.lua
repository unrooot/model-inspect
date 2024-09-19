local loader = script.Parent:FindFirstChild("LoaderUtils", true).Parent
local require = require(loader).bootstrapPlugin(script)

local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AccelTween = require("AccelTween")
local Blend = require("Blend")
local InstanceList = require("InstanceList")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local SelectionPath = require("SelectionPath")
local SpringObject = require("SpringObject")
local StepUtils = require("StepUtils")
local ValueObject = require("ValueObject")

local SELECTION_MAX_DISTANCE = 1000

local function getShiftPressed()
	local pressedKeys = UserInputService:GetKeysPressed()
	local shiftPressed = false

	for _, inputObject in pressedKeys do
		if inputObject.KeyCode == Enum.KeyCode.LeftShift then
			shiftPressed = true
			break
		end
	end

	return shiftPressed
end

local function getCtrlPressed()
	local pressedKeys = UserInputService:GetKeysPressed()
	local ctrlPressed = false

	for _, inputObject in pressedKeys do
		if inputObject.KeyCode == Enum.KeyCode.LeftControl then
			ctrlPressed = true
			break
		end
	end

	return ctrlPressed
end

local function initialize(plugin)
	local maid = Maid.new()

	local toggleMacro = plugin:CreatePluginAction(
		"[Model Inspect] Enable Selection", -- action id
		"[Model Inspect] Enable Selection", -- action text
		"Toggles the plugin selection", -- action desc
		"", -- plugin icon
		true
	)

	local camera = workspace.CurrentCamera
	local currentRootInstance = maid:Add(ValueObject.new(nil))
	local holdingSelection = maid:Add(ValueObject.new(false))
	local selectionEnabled = maid:Add(ValueObject.new(false))

	local percentAlpha = AccelTween.new(300)
	percentAlpha.t = 0
	percentAlpha.p = 0

	maid:GiveTask(selectionEnabled:ObserveBrio():Subscribe(function(enabledBrio)
		if enabledBrio:IsDead() then
			return
		end

		local isEnabled = enabledBrio:GetValue()
		local enabledMaid = enabledBrio:ToMaid()

		plugin:Activate(isEnabled)

		if isEnabled then
			local currentDepth, modelDepth = 0, 1
			local currentSelectionSet = {}
			local ignoredInstances = {}

			local pluginMouse = plugin:GetMouse()

			local instanceList = enabledMaid:Add(InstanceList.new())
			local modelList = enabledMaid:Add(InstanceList.new())

			enabledMaid:GiveTask(pluginMouse.Button1Down:Connect(function()
				holdingSelection.Value = true

				if getCtrlPressed() then
					local rootInstance = currentRootInstance.Value
					local selectedInstances = Selection:Get()
					local currentIndex = table.find(selectedInstances, rootInstance)

					if currentIndex then
						table.remove(selectedInstances, currentIndex)
					else
						table.insert(selectedInstances, rootInstance)
					end

					Selection:Set(selectedInstances)
				else
					Selection:Set({ currentRootInstance.Value })
				end
			end))

			enabledMaid:GiveTask(pluginMouse.Button1Up:Connect(function()
				holdingSelection.Value = false
			end))

			local mousePosition = enabledMaid:Add(ValueObject.new(Vector2.zero))

			local percentAlphaObservable = Observable.new(function(subscription)
				local startAnimate, stopAnimate = StepUtils.bindToRenderStep(function()
					subscription:Fire(percentAlpha.p)
					return percentAlpha.rtime > 0
				end)

				enabledMaid:GiveTask(currentRootInstance:Observe():Pipe({
					Rx.map(function(instance)
						return instance ~= nil and 1 or 0
					end);
				}):Subscribe(function(target)
					percentAlpha.t = target

					if target == 1 then
						percentAlpha.p = 0.8
					end

					startAnimate()
				end))

				startAnimate()
				enabledMaid:GiveTask(stopAnimate)
			end)

			local transparency = Blend.Computed(percentAlphaObservable, function(percent)
				return 1 - percent
			end)

			enabledMaid:GiveTask(Blend.New "Folder" {
				Name = "ModelInspectHighlight";
				Parent = currentRootInstance;

				Blend.New "Highlight" {
					Adornee = currentRootInstance;
					FillColor = Color3.fromRGB(255, 255, 255);
					OutlineTransparency = transparency;

					FillTransparency = Blend.Computed(transparency, function(percent)
						return 0.7 + percent
					end);
				};

				Blend.New "SelectionBox" {
					Color3 = Color3.fromRGB(5, 188, 255);
					LineThickness = 0.03;
					SurfaceColor3 = Color3.fromRGB(5, 188, 255);

					Adornee = Blend.Computed(currentRootInstance, function(rootInstance)
						if not rootInstance then
							return
						end

						local parent = rootInstance.Parent
						if not parent or parent == workspace then
							return rootInstance
						end

						if not parent:IsA("Model") and parent ~= workspace then
							repeat
								parent = parent.Parent
							until
								parent:IsA("Model") or parent.Parent == workspace
						end

						return parent
					end);

					SurfaceTransparency = Blend.Computed(transparency, function(percent)
						return 0.9 + (percent * 0.1)
					end);

					Transparency = Blend.Computed(transparency, function(percent)
						return 0.75 + (percent * 0.25)
					end);
				};
			}:Subscribe())

			enabledMaid:GiveTask(Blend.New "ScreenGui" {
				Name = "ModelInspectGui";
				Parent = CoreGui;
			}:Subscribe(function(screenGui)
				local path = enabledMaid:Add(SelectionPath.new())

				enabledMaid:GiveTask(currentRootInstance:Observe():Subscribe(function(rootInstance)
					path:SetRootInstance(rootInstance)
				end))

				enabledMaid:GiveTask(UserInputService.InputBegan:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Tab then
						if not currentSelectionSet then
							return
						end

						local shiftPressed = getShiftPressed()

						if shiftPressed then
							if #ignoredInstances > 0 and currentDepth ~= 0 then
								if currentDepth - 1 >= 0 then
									currentDepth -= 1
								else
									return
								end

								table.remove(ignoredInstances, #ignoredInstances)
							end
						else
							if currentDepth + 1 <= #currentSelectionSet then
								currentDepth += 1
							else
								return
							end

							table.insert(ignoredInstances, currentSelectionSet[#currentSelectionSet])
						end

						local currentSelection = currentSelectionSet[#currentSelectionSet]
						if currentDepth ~= 0 then
							local instances = currentSelectionSet[currentDepth]
							if instances then
								currentSelection = instances[1]
							end
						else
							local models = currentSelectionSet[1][2]
							currentSelection = models[#models]
						end

						if currentSelection then
							currentRootInstance.Value = currentSelection
						end
					elseif input.KeyCode == Enum.KeyCode.Space then
						if not currentSelectionSet then
							return
						end

						local currentInstances = {}
						local shiftPressed = getShiftPressed()

						if currentDepth ~= 0 then
							currentInstances = currentSelectionSet[currentDepth]
						else
							currentInstances = currentSelectionSet[1]
						end

						if not currentInstances then
							return
						end

						local models = currentInstances[2]
						if #models == 0 then
							return
						end

						if shiftPressed then
							if modelDepth ~= 1 and modelDepth - 1 >= 1 then
								modelDepth -= 1
							end
						else
							if modelDepth + 1 <= #models then
								modelDepth += 1
							end
						end

						modelList:SetCurrentDepth(modelDepth)

						local targetModel
						if modelDepth <= 1 then
							targetModel = models[1]
						else
							targetModel = models[modelDepth]
						end

						if targetModel then
							currentRootInstance.Value = targetModel
						end
					elseif input.KeyCode == Enum.KeyCode.Escape then
						selectionEnabled.Value = false
					end
				end))

				local positionX = enabledMaid:Add(ValueObject.new(0))
				local positionY = enabledMaid:Add(ValueObject.new(0))

				-- Highlight instances under cursor
				enabledMaid:GiveTask(mousePosition:Observe():Pipe({
					Rx.map(function(mousePosition)
						if not mousePosition then
							return UDim2.new()
						end

						local parts = {}

						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude

						local unitRay = camera:ScreenPointToRay(mousePosition.X, mousePosition.Y)
						local ray = Ray.new(unitRay.Origin, unitRay.Direction * SELECTION_MAX_DISTANCE)
						local raycastResult = workspace:Raycast(ray.Origin, ray.Direction, params)

						if raycastResult then
							local instance = raycastResult.Instance
							local parents = {}
							local parent = instance.Parent

							repeat
								if not table.find(parents, parent) and parent and (parent ~= Workspace and parent:IsA("Model")) then
									table.insert(parents, 1, parent)
								end
								parent = parent.Parent
							until
								not parent or parent == Workspace

							parts[1] = { instance, parents }

							params:AddToFilter(instance)
						end

						local depth = 1

						local function getInstances()
							raycastResult = workspace:Raycast(ray.Origin, ray.Direction, params)

							if raycastResult then
								local instance = raycastResult.Instance
								local parents = {}

								local parent = instance.Parent
								repeat
									if not table.find(parents, parent) and parent and (parent ~= Workspace and parent:IsA("Model")) then
										table.insert(parents, 1, parent)
									end
									parent = parent.Parent
								until
									not parent or parent == Workspace

								depth += 1
								parts[depth] = { instance, parents }
								params:AddToFilter(instance)

								getInstances()
							end
						end

						getInstances()
						currentSelectionSet = parts

						local firstInstance
						if parts and #parts > 0 then
							modelList:SetInstances(parts[1][2])

							if currentDepth == 0 then
								local models = parts[1][2]
								if #models > 0 then
									firstInstance = models[1]
								else
									modelList:SetInstances(nil)
								end
							else
								local current = parts[currentDepth]
								if current then
									firstInstance = current[1]
								end
							end
						else
							instanceList:SetInstances(nil)
							modelList:SetInstances(nil)
						end

						if (parts and #parts > 0) and not firstInstance then
							firstInstance = parts[1][1]
						end

						if #parts == 0 then
							currentRootInstance.Value = nil
						else
							print(firstInstance)
							currentRootInstance.Value = firstInstance
						end

						if holdingSelection.Value then
							Selection:Set({ currentRootInstance.Value })
						end

						positionX.Value = mousePosition.X + 20
						positionY.Value = mousePosition.Y

						return positionX.Value, positionY.Value
					end)
				}):Subscribe())

				local percentX = SpringObject.new(positionX, 80, 0.9);
				local percentY = SpringObject.new(positionY, 80, 0.9);

				percentX.p = positionX
				percentY.p = positionY

				local mousePosition = Blend.Computed(percentX, percentY, function(posX, posY)
					return UDim2.fromOffset(posX, posY)
				end);

				enabledMaid:GiveTask(path:Render({
					Position = mousePosition;
					Parent = screenGui;
				}):Subscribe(function()
					path:Show()
				end))

				enabledMaid:GiveTask(instanceList:Render({
					--
				}))

				enabledMaid:GiveTask(modelList:Render({
					Hotkey = Enum.KeyCode.Space;
					Position = mousePosition;
					HeaderText = "next models under cursor";
					Parent = screenGui;
				}):Subscribe(function()
					modelList:Show()
				end))
			end))

			enabledMaid:GiveTask(RunService.RenderStepped:Connect(function()
				mousePosition.Value = UserInputService:GetMouseLocation()
			end))
		end
	end))

	maid:GiveTask(toggleMacro.Triggered:Connect(function()
		selectionEnabled.Value = not selectionEnabled.Value
	end))

	maid:GiveTask(plugin.Unloading:Connect(function()
		maid:Destroy()
	end))

	return maid
end

if plugin then
	initialize(plugin)
end
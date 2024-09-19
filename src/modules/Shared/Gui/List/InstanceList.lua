local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local InstanceListEntry = require("InstanceListEntry")
local ObservableSortedList = require("ObservableSortedList")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local ValueObject = require("ValueObject")

local InstanceList = setmetatable({}, BasicPane)
InstanceList.ClassName = "InstanceList"
InstanceList.__index = InstanceList

function InstanceList.new()
	local self = setmetatable(BasicPane.new(), InstanceList)

	self._currentDepth = self._maid:Add(ValueObject.new(0))
	self._currentInstances = self._maid:Add(ValueObject.new(nil))
	self._entries = self._maid:Add(ObservableSortedList.new())
	self._percentVisibleTarget = self._maid:Add(ValueObject.new(0))

	self._maid:GiveTask(self._currentInstances:Observe():Subscribe(function(currentInstances)
		local currentEntries = self._entries:GetList()

		if not currentInstances or #currentInstances == 0 then
			for index, entry in currentEntries do
				entry:Destroy()
				self._entries:RemoveByKey(index)
			end

			return
		end

		for index, instance in currentInstances do
			index -= 1

			if index == 0 then
				continue
			end

			local currentEntry = currentEntries[index]

			if currentEntry then
				currentEntry:SetInstance(instance)
				continue
			end

			currentEntry = InstanceListEntry.new()
			currentEntry:SetInstance(instance)
			currentEntry:SetLayoutOrder(index)

			currentEntry._maid:GiveTask(self._currentDepth:Observe():Subscribe(function(depth)
				local modelDepth = currentEntry.LayoutOrder.Value

				currentEntry:SetVisible(depth <= modelDepth)
			end))

			currentEntry._maid:GiveTask(self._entries:Add(currentEntry, currentEntry.LayoutOrder:Observe()))
		end

		if #currentInstances - 1 < #currentEntries then
			for index, entry in self._entries:GetList() do
				index -= 1
				if index >= #currentInstances then
					entry:Destroy()
				end
			end
		end
	end))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function InstanceList:SetCurrentDepth(depth: number)
	self._currentDepth.Value = depth
end

function InstanceList:SetInstances(instanceList: {}?)
	if instanceList and self._currentInstances.Value then
		if instanceList[1] ~= self._currentInstances.Value[1] then
			self._currentDepth.Value = 0
		end
	end

	self._currentInstances.Value = instanceList
end

function InstanceList:Render(props)
	local target = self._percentVisibleTarget:Observe()

	local percentVisible = Blend.Spring(target, 30, 0.7)
	local percentAlpha = Blend.AccelTween(target, 400)
	local transparency = Blend.Computed(percentAlpha, function(percent)
		return 1 - percent
	end)

	self._maid:GiveTask(Blend.Computed(percentVisible, function(percent)
		local list = self._entries:GetList()
		local entryCount = math.max(1, #list)

		for index, button in list do
			local progress = (index - 1) / entryCount + 1e-1
			button:SetVisible(progress <= percent)
		end
	end):Subscribe())

	return Blend.New "Frame" {
		Name = "InstanceList";
		AnchorPoint = Vector2.new(0, 1);
		AutomaticSize = Enum.AutomaticSize.XY;
		BackgroundColor3 = Color3.fromRGB(15, 15, 15);
		Parent = props.Parent;

		Position = props.Position:Pipe({
			Rx.map(function(position)
				return UDim2.fromOffset(position.X.Offset, position.Y.Offset - 5)
			end)
		});

		BackgroundTransparency = Blend.Computed(transparency, function(percent)
			return 0.2 + percent
		end);

		[Blend.Children] = {
			Blend.New "UIPadding" {
				PaddingBottom = UDim.new(0, 10);
				PaddingLeft = UDim.new(0, 10);
				PaddingRight = UDim.new(0, 10);
				PaddingTop = UDim.new(0, 10);
			};

			Blend.New "UIStroke" {
				Color = Color3.fromRGB(255, 255, 255);
				Transparency = Blend.Computed(transparency, function(percent)
					return 0.8 + (percent * 0.2)
				end);
			};

			Blend.New "UICorner" {
				CornerRadius = UDim.new(0, 5);
			};

			Blend.New "UIListLayout" {
				HorizontalAlignment = Enum.HorizontalAlignment.Center;
				Padding = UDim.new(0, 5);
			};

			Blend.New "Frame" {
				Name = "header";
				AutomaticSize = Enum.AutomaticSize.X;
				BackgroundTransparency = 1;
				LayoutOrder = 2;
				Size = UDim2.new(1, 0, 0, 15);

				[Blend.Children] = {
					Blend.New "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal;
						HorizontalAlignment = Enum.HorizontalAlignment.Center;
						HorizontalFlex = Enum.UIFlexAlignment.Fill;
						Padding = UDim.new(0, 5);
						VerticalAlignment = Enum.VerticalAlignment.Center;
					};

					Blend.New "Frame" {
						Name = "key";
						AutomaticSize = Enum.AutomaticSize.X;
						BackgroundColor3 = Color3.fromRGB(175, 175, 175);
						BackgroundTransparency = transparency;
						Size = UDim2.fromScale(0, 1);

						[Blend.Children] = {
							Blend.New "UIPadding" {
								PaddingBottom = UDim.new(0, 5);
								PaddingLeft = UDim.new(0, 5);
								PaddingRight = UDim.new(0, 5);
								PaddingTop = UDim.new(0, 5);
							};

							Blend.New "UICorner" {
								CornerRadius = UDim.new(0, 4);
							};

							Blend.New "UIFlexItem" {
								FlexMode = Enum.UIFlexMode.None;
							};

							Blend.New "TextLabel" {
								Name = "label";
								AutomaticSize = Enum.AutomaticSize.X;
								BackgroundTransparency = 1;
								FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal);
								Size = UDim2.fromScale(0, 1);
								TextColor3 = Color3.fromRGB(50, 50, 50);
								TextSize = 10;
								TextTransparency = transparency;

								Text = Blend.Computed(props.Hotkey, function(hotkey: string | Enum.KeyCode)
									if not hotkey then
										return "?"
									end

									if typeof(hotkey) == "EnumItem" then
										return string.upper(hotkey.Name)
									end

									return string.upper(hotkey)
								end);
							};
						};
					};

					Blend.New "TextLabel" {
						Name = "label";
						AutomaticSize = Enum.AutomaticSize.X;
						BackgroundTransparency = 1;
						FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal);
						Position = UDim2.fromScale(0, 0);
						Size = UDim2.fromScale(0, 1);
						Text = props.HeaderText;
						TextColor3 = Color3.fromRGB(255, 255, 255);
						TextSize = 15;
						TextTransparency = transparency;
						TextXAlignment = Enum.TextXAlignment.Left;
					};
				};
			};

			Blend.New "Frame" {
				Name = "contents";
				AutomaticSize = Enum.AutomaticSize.Y;
				BackgroundTransparency = 1;
				Size = UDim2.fromScale(1, 0);
				LayoutOrder = 1;

				[Blend.Children] = {
					Blend.New "UIListLayout" {
						HorizontalAlignment = Enum.HorizontalAlignment.Center;
						Padding = UDim.new(0, 5);
					};

					self._entries:ObserveItemsBrio():Pipe({
						RxBrioUtils.map(function(entry)
							if self:IsVisible() then
								entry:Show()
							end

							return entry:Render()
						end)
					});
				};
			};
		};
	}
end

return InstanceList
local require = require(script.Parent.loader).load(script)

local StudioService = game:GetService("StudioService")

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local TextServiceUtils = require("TextServiceUtils")
local ValueObject = require("ValueObject")

local InstanceLabel = setmetatable({}, BasicPane)
InstanceLabel.ClassName = "InstanceLabel"
InstanceLabel.__index = InstanceLabel

function InstanceLabel.new()
	local self = setmetatable(BasicPane.new(), InstanceLabel)

	self._percentVisibleTarget = self._maid:Add(ValueObject.new(0))

	self._arrowVisible = self._maid:Add(ValueObject.new(false))
	self._className = self._maid:Add(ValueObject.new(nil))
	self.Instance = self._maid:Add(ValueObject.new(nil))
	self._iconData = self._maid:Add(ValueObject.new({}))
	self._instanceName = self._maid:Add(ValueObject.new(""))
	self._textWidth = self._maid:Add(ValueObject.new(0))

	self.LayoutOrder = self._maid:Add(ValueObject.new(0))

	self._maid:GiveTask(self.Instance:Observe():Subscribe(function(instance)
		self._className.Value = instance and instance.ClassName or nil
		self._instanceName.Value = instance and instance.Name or ""
	end))

	self._maid:GiveTask(TextServiceUtils.observeSizeForLabelProps({
		FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Bold, Enum.FontStyle.Normal);
		MaxSize = Vector2.new(math.huge, 15);
		Text = self._instanceName;
		TextSize = 15;
	}):Subscribe(function(textSize)
		self._textWidth.Value = textSize.X
	end))

	self._maid:GiveTask(self._className:Observe():Subscribe(function(className)
		if not className then
			return
		end

		self._iconData.Value = StudioService:GetClassIcon(className)
	end))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function InstanceLabel:SetArrowVisible(isVisible: boolean)
	self._arrowVisible.Value = isVisible
end

function InstanceLabel:SetInstance(instance: Instance?)
	self.Instance.Value = instance
end

function InstanceLabel:SetLayoutOrder(layoutOrder: number)
	self.LayoutOrder.Value = layoutOrder
end

function InstanceLabel:Render(props)
	local target = self._percentVisibleTarget:Observe()

	local percentVisible = Blend.Spring(target, 30, 0.7)

	local percentAlpha = Blend.AccelTween(target, 400)
	local transparency = Blend.Computed(percentAlpha, function(percent)
		return 1 - percent
	end)

	return Blend.New "Frame" {
		Name = "InstanceLabel";
		AnchorPoint = Vector2.new(0, 1);
		AutomaticSize = Enum.AutomaticSize.X;
		BackgroundColor3 = Color3.fromRGB(163, 162, 165);
		BackgroundTransparency = 1;
		LayoutOrder = self.LayoutOrder;
		Position = UDim2.fromScale(0, 1);
		Size = UDim2.fromScale(0, 1);

		[Blend.Children] = {
			Blend.New "Frame" {
				Name = "wrapper";
				AutomaticSize = Enum.AutomaticSize.X;
				BackgroundTransparency = 1;
				Size = UDim2.fromScale(1, 1);

				[Blend.Children] = {
					Blend.New "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal;
						Padding = UDim.new(0, 3);
						VerticalAlignment = Enum.VerticalAlignment.Center;
					};

					Blend.New "ImageLabel" {
						Name = "icon";
						AnchorPoint = Vector2.new(0.5, 0.5);
						BackgroundTransparency = 1;
						ImageTransparency = transparency;
						LayoutOrder = 1;
						Position = UDim2.fromScale(0.5, 0.5);
						ScaleType = Enum.ScaleType.Slice;
						Size = UDim2.fromScale(1, 1);
						SliceCenter = Rect.new(Vector2.new(0, 0), Vector2.new(16, 16));

						Image = Blend.Computed(self._iconData, function(data)
							return data.Image or ""
						end);

						ImageRectOffset = Blend.Computed(self._iconData, function(data)
							return data.ImageRectOffset or Vector2.new()
						end);

						ImageRectSize = Blend.Computed(self._iconData, function(data)
							return data.ImageRectSize or Vector2.new()
						end);

						[Blend.Children] = {
							Blend.New "UIAspectRatioConstraint" {
								AspectRatio = 1;
							};

							Blend.New "ImageLabel" {
								Name = "shadow";
								AnchorPoint = Vector2.new(0.15, 0.5);
								BackgroundColor3 = Color3.fromRGB(163, 162, 165);
								BackgroundTransparency = 1;
								Image = "rbxassetid://6150493168";
								ImageColor3 = Color3.fromRGB(0, 0, 0);
								Position = UDim2.fromScale(0.5, 0.5);
								ZIndex = -10;

								ImageTransparency = Blend.Computed(transparency, function(percent)
									return 0.9 + percent
								end);

								Size = Blend.Computed(self._iconData, self._textWidth, function(iconData, textWidth)
									local rectSize = iconData and iconData.ImageRectSize
									local iconWidth = rectSize and rectSize.X or 0

									return UDim2.fromScale((textWidth / iconWidth) * 1.7, 1.75);
								end);
							};
						};
					};

					Blend.New "TextLabel" {
						Name = "instanceName";
						AnchorPoint = Vector2.new(0.5, 0.5);
						AutomaticSize = Enum.AutomaticSize.X;
						BackgroundTransparency = 1;
						FontFace = Font.new("rbxassetid://16658221428", Enum.FontWeight.Bold, Enum.FontStyle.Normal);
						LayoutOrder = 2;
						Position = UDim2.fromScale(0.5, 0.5);
						Size = UDim2.fromScale(0, 1);
						Text = self._instanceName;
						TextColor3 = Color3.fromRGB(255, 255, 255);
						TextSize = 15;
						TextTransparency = transparency;
						TextXAlignment = Enum.TextXAlignment.Left;

						TextStrokeTransparency = Blend.Computed(transparency, function(percent)
							return 0.8 + (percent * 0.2)
						end);
					};

					Blend.New "ImageLabel" {
						Name = "arrow";
						BackgroundTransparency = 1;
						Image = "rbxassetid://6034818365";
						ImageTransparency = transparency;
						LayoutOrder = 3;
						Size = UDim2.fromScale(1, 1);
						Visible = self._arrowVisible;

						Blend.New "UIAspectRatioConstraint" {
							AspectRatio = 1;
						};
					};
				};
			};
		};
	}
end

return InstanceLabel
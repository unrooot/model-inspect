local require = require(script.Parent.loader).load(script)

local StudioService = game:GetService("StudioService")

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local ValueObject = require("ValueObject")

local InstanceListEntry = setmetatable({}, BasicPane)
InstanceListEntry.ClassName = "InstanceListEntry"
InstanceListEntry.__index = InstanceListEntry

function InstanceListEntry.new()
	local self = setmetatable(BasicPane.new(), InstanceListEntry)

	self._iconData = self._maid:Add(ValueObject.new({}))
	self._instance = self._maid:Add(ValueObject.new(nil))
	self._instanceName = self._maid:Add(ValueObject.new(""))
	self._percentVisibleTarget = self._maid:Add(ValueObject.new(0))

	self.LayoutOrder = self._maid:Add(ValueObject.new(0))

	self._maid:GiveTask(self._instance:Observe():Subscribe(function(instance)
		if not instance then
			self._instanceName.Value = ""
			self._iconData.Value = nil
			return
		end

		self._instanceName.Value = instance.Name
		self._iconData.Value = StudioService:GetClassIcon(instance.ClassName)
	end))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function InstanceListEntry:SetInstance(instance: Instance?)
	self._instance.Value = instance
end

function InstanceListEntry:SetLayoutOrder(order: number)
	self.LayoutOrder.Value = order
end

function InstanceListEntry:Render(props)
	local target = self._percentVisibleTarget:Observe()

	local percentVisible = Blend.Spring(target, 35, 0.9)

	local percentAlpha = Blend.AccelTween(target, 400)
	local transparency = Blend.Computed(percentAlpha, function(percent)
		return 1 - percent
	end)

	return Blend.New "Frame" {
		Name = "InstanceListEntry";
		BackgroundTransparency = 1;
		ClipsDescendants = true;
		LayoutOrder = self.LayoutOrder;

		Size = Blend.Computed(percentVisible, function(percent)
			return UDim2.new(1, 0, 0, 24 * percent)
		end);

		Visible = Blend.Computed(percentVisible, function(percent)
			return percent > 0.01
		end);

		[Blend.Children] = {
			Blend.New "Frame" {
				Name = "wrapper";
				Size = UDim2.fromScale(1, 1);

				BackgroundTransparency = Blend.Computed(transparency, function(percent)
					return 0.9 + percent
				end);

				Position = Blend.Computed(percentVisible, function(percent)
					return UDim2.fromScale(-0.3 + percent * 0.3, 0)
				end);

				Blend.New "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal;
					HorizontalFlex = Enum.UIFlexAlignment.Fill;
					Padding = UDim.new(0, 2);
					VerticalAlignment = Enum.VerticalAlignment.Center;
				};

				Blend.New "UICorner" {
					CornerRadius = UDim.new(0, 4);
				};

				Blend.New "UIPadding" {
					PaddingBottom = UDim.new(0, 3);
					PaddingLeft = UDim.new(0, 3);
					PaddingRight = UDim.new(0, 3);
					PaddingTop = UDim.new(0, 3);
				};

				Blend.New "TextLabel" {
					Name = "depth";
					AnchorPoint = Vector2.new(0, 1);
					AutomaticSize = Enum.AutomaticSize.X;
					BackgroundTransparency = 1;
					FontFace = Font.new("rbxassetid://16658246179");
					LayoutOrder = -1;
					Position = UDim2.fromScale(0, 1);
					Size = UDim2.fromScale(0, 1);
					Text = self.LayoutOrder;
					TextColor3 = Color3.fromRGB(255, 255, 255);
					TextScaled = true;
					TextSize = 18;
					TextTransparency = transparency;
					TextWrapped = true;
					TextXAlignment = Enum.TextXAlignment.Left;

					TextStrokeTransparency = Blend.Computed(transparency, function(percent)
						return 0.8 + (percent * 0.2)
					end);

					[Blend.Children] = {
						Blend.New "UIFlexItem" {
							FlexMode = Enum.UIFlexMode.None;
						};

						Blend.New "UITextSizeConstraint" {
							MaxTextSize = 14;
						};
					};
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

					Blend.New "UIAspectRatioConstraint" {
						AspectRatio = 1;
					};
				};

				Blend.New "TextLabel" {
					Name = "instanceName";
					AnchorPoint = Vector2.new(0, 1);
					AutomaticSize = Enum.AutomaticSize.X;
					BackgroundTransparency = 1;
					FontFace = Font.new("rbxassetid://16658246179", Enum.FontWeight.Bold, Enum.FontStyle.Normal);
					LayoutOrder = 2;
					Position = UDim2.fromScale(0, 1);
					Size = UDim2.fromScale(0, 0.8);
					Text = self._instanceName;
					TextColor3 = Color3.fromRGB(255, 255, 255);
					TextSize = 14;
					TextTransparency = transparency;
					TextXAlignment = Enum.TextXAlignment.Left;

					TextStrokeTransparency = Blend.Computed(transparency, function(percent)
						return 0.8 + (percent * 0.2)
					end);

					[Blend.Children] = {
						Blend.New "UIFlexItem" {
							FlexMode = Enum.UIFlexMode.None;
						};
					};
				};
			};
		};
	}
end

return InstanceListEntry
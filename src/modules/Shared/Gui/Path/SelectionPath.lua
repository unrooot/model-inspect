local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local InstanceLabel = require("InstanceLabel")
local Maid = require("Maid")
local ObservableSortedList = require("ObservableSortedList")
local RxBrioUtils = require("RxBrioUtils")
local ValueObject = require("ValueObject")

local SelectionPath = setmetatable({}, BasicPane)
SelectionPath.ClassName = "SelectionPath"
SelectionPath.__index = SelectionPath

function SelectionPath.new()
	local self = setmetatable(BasicPane.new(), SelectionPath)

	self._percentVisibleTarget = self._maid:Add(ValueObject.new(0))

	self._labels = self._maid:Add(ObservableSortedList.new())
	self._rootInstance = self._maid:Add(ValueObject.new(nil))
	self._instanceMap = {}

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function SelectionPath:SetRootInstance(instance: Instance?)
	self._rootInstance.Value = instance
end

function SelectionPath:Render(props)
	local target = self._percentVisibleTarget:Observe()

	local percentVisible = Blend.Spring(target, 30, 0.7)

	self._maid:GiveTask(Blend.Computed(percentVisible, function(percent)
		local list = self._labels:GetList()
		local itemCount = math.max(1, #list)

		for index, button in list do
			local progress = (index - 1) / itemCount + 1e-1
			button:SetVisible(progress <= percent)
		end
	end):Subscribe())

	local percentAlpha = Blend.AccelTween(target, 400)
	local transparency = Blend.Computed(percentAlpha, function(percent)
		return 1 - percent
	end)

	self._maid:GiveTask(self._rootInstance:Observe():Subscribe(function(rootInstance)
		if not rootInstance then
			for instance, maid in self._instanceMap do
				maid:Destroy()
				self._instanceMap[instance] = nil
				self._maid[instance] = nil
			end

			return
		end

		local parent = rootInstance.Parent
		local parents = { rootInstance }

		local currentParents = self._labels:GetList()

		if parent ~= workspace then
			repeat
				if parent and parent ~= workspace then
					table.insert(parents, 1, parent)
					parent = parent.Parent
				end
			until
				not parent or parent == workspace
		end

		for index, instance in parents do
			local entryLabel = currentParents[index]
			if entryLabel then
				entryLabel:SetInstance(instance)
				entryLabel:SetLayoutOrder(index)
				entryLabel:SetArrowVisible(index < #parents)

				continue
			end

			local entryMaid = Maid.new()

			entryLabel = InstanceLabel.new()
			entryLabel:SetInstance(instance)
			entryLabel:SetLayoutOrder(index)
			entryLabel:SetArrowVisible(index < #parents)

			entryMaid.Label = entryLabel
			entryMaid:GiveTask(self._labels:Add(entryLabel, entryLabel.LayoutOrder:Observe()))

			self._instanceMap[instance] = entryMaid
			self._maid[instance] = entryMaid
		end

		if #currentParents > #parents then
			for index = #parents + 1, #currentParents do
				local labelEntry = currentParents[index]
				local instance = labelEntry.Instance.Value
				local instanceMaid = self._instanceMap[instance]

				if instanceMaid then
					instanceMaid:Destroy()
				end

				self._instanceMap[instance] = nil
				self._maid[instance] = nil
			end
		end
	end))

	return Blend.New "Frame" {
		Name = "SelectionPath";
		BackgroundTransparency = 1;
		Position = props.Position;
		Size = UDim2.new(1, 0, 0, 15);
		Parent = props.Parent;

		Blend.New "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal;
			Padding = UDim.new(0, 2);
			VerticalAlignment = Enum.VerticalAlignment.Center;
		};

		self._labels:ObserveItemsBrio():Pipe({
			RxBrioUtils.map(function(entry)
				if self:IsVisible() then
					entry:Show()
				end

				return entry:Render()
			end)
		});
	}
end

return SelectionPath
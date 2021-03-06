Rem
	====================================================================
	GUI Slot List
	====================================================================

	Code contains:
	- TGUISlotList: list allowing to place items on a specific slot


	====================================================================
	LICENCE

	Copyright (C) 2002-2014 Ronny Otto, digidea.de

	This software is provided 'as-is', without any express or
	implied warranty. In no event will the authors be held liable
	for any	damages arising from the use of this software.

	Permission is granted to anyone to use this software for any
	purpose, including commercial applications, and to alter it
	and redistribute it freely, subject to the following restrictions:

	1. The origin of this software must not be misrepresented; you
	   must not claim that you wrote the original software. If you use
	   this software in a product, an acknowledgment in the product
	   documentation would be appreciated but is not required.
	2. Altered source versions must be plainly marked as such, and
	   must not be misrepresented as being the original software.
	3. This notice may not be removed or altered from any source
	   distribution.
	====================================================================
End Rem
SuperStrict
Import "base.gfx.gui.list.base.bmx"



Type TGUISlotList Extends TGUIListBase
	Field _slotMinDimension:TVec2D = new TVec2D.Init(0,0)
	'slotAmount: <=0 means dynamically, else it is fixed
	Field _slotAmount:Int = -1
	Field _slots:TGUIobject[0]
	Field _slotsState:Int[0]
	Field _autofillSlots:Int = False
	Field _fixedSlotDimension:Int = False


    Method Create:TGUISlotList(position:TVec2D = null, dimension:TVec2D = null, limitState:String = "")
		Super.Create(position, dimension, limitState)

		autoSortItems = False

		Return Self
	End Method


	Method ClearSlotsState:Int()
		_slotsState = New Int[_slots.length]
	End Method


	Method GetSlotState:Int(slot:Int)
		If slot >= _slotsState.length Then Return -1
		Return _slotsState[slot]
	End Method


	Method SetSlotState:Int(slot:Int, state:Int)
		If slot >= _slotsState.length Then Return False
		_slotsState[slot] = state
		Return True
	End Method


	Method EmptyList:Int()
		Super.EmptyList()

		For Local i:Int = 0 To _slots.length-1
			'skip empty slots
			If _slots[i]=null then continue
			'call the objects cleanup-method and unsets afterwards
			_slots[i].Remove()
			_slots[i] = null
			_slotsState[i] = 0
		Next
	End Method


	'returns how many slots that list has at all
	Method GetSlotAmount:Int()
		Return _slotAmount
	End Method


	'returns how many slots of that list are not occupied
	Method GetUnusedSlotAmount:Int()
		Local amount:Int = 0
		For Local i:Int = 0 To _slots.length-1
			If _slots[i] Then amount:+1
		Next
		Return amount
	End Method


	Method SetAutofillSlots(bool:Int=True)
		Self._autofillSlots = bool
	End Method


	'override
	Method HasItem:Int(item:TGUIobject)
		Return (getSlot(item) >= 0)
	End Method


	'override
	Method SetItemLimit:Int(limit:Int)
		Super.SetItemLimit(limit)
		_slotAmount = limit

		'maybe better "drag" items before if resizing to smaller slot amounts
		_slots = _slots[..limit]
		_slotsState = _slotsState[..limit]
	End Method


	Method SetSlotMinDimension:Int(width:Float=0.0, height:Float=0.0)
		_slotMinDimension.setXY(width, height)
	End Method


	'which slot is occupied by the given item?
	Method getSlot:Int(item:TGUIobject)
		For Local i:Int = 0 To _slots.length-1
			If _slots[i] = item Then Return i
		Next
		Return -1
	End Method


	'return the next free slot (for autofill)
	Method getFreeSlot:Int()
		For Local i:Int = 0 To _slots.length-1
			If _slots[i] Then Continue
			Return i
		Next
		Return -1
	End Method


	Method GetSlotOrCoord:TVec3D(slot:Int=-1, coord:TVec2D=Null)
		Local baseRect:TRectangle = Null
		If _fixedSlotDimension
			baseRect = new TRectangle.Init(0, 0, _slotMinDimension.getX(), _slotMinDimension.getY())
		Else
			If _orientation = GUI_OBJECT_ORIENTATION_VERTICAL
				baseRect = new TRectangle.Init(0, 0, rect.GetW(), _slotMinDimension.getY())
			ElseIf _orientation = GUI_OBJECT_ORIENTATION_HORIZONTAL
				baseRect = new TRectangle.Init(0, 0, _slotMinDimension.getX(), rect.GetH())
			Else
				TLogger.log("TGUISlotList.GetSlotOrCoord", "unknown orientation : " + _orientation, LOG_ERROR)
			EndIf
		EndIf

		'set startpos at point of block displacement
		Local currentPos:TVec3D = _entriesBlockDisplacement.copy()
		Local currentRect:TRectangle 'used to check if a given coord is within
		Local slotW:Int
		Local slotH:Int
		For Local i:Int = 0 To _slots.length-1
			'size the slot dimension accordingly
			slotW = _slotMinDimension.getX()
			slotH = _slotMinDimension.getY()
			'only use slots real dimension if occupied and not fixed
			If _slots[i] And Not _fixedSlotDimension
				slotW = Max(slotW, _slots[i].rect.getW())
				slotH = Max(slotH, _slots[i].rect.getH())
			EndIf

			'move base rect
			baseRect.position.CopyFrom(currentPos.ToVec2D())

			'if the current position + dimension contains the given
			'coord or is of this slot - return this position
			'1. GIVEN SLOT
			If slot >= 0 And i = slot Then Return currentPos
			'2. GIVEN COORD
			If coord
				If _slots[i] And Not _fixedSlotDimension
					currentRect = _slots[i].rect
				Else
					currentRect = baseRect
				EndIf
				If currentRect.containsXY(coord.getX(),coord.getY())
					'print "currentRect: "+currentRect.position.getIntX()+","+currentRect.position.getIntY()+" "+currentRect.dimension.getIntX()+","+currentRect.dimension.getIntY() + " minW:"+_slotMinDimension.getX()+" minH:"+_slotMinDimension.getY() +" slot:"+i
					currentPos.z = i
					Return currentPos
				EndIf
			EndIf


			'move to the next one
			If _orientation = GUI_OBJECT_ORIENTATION_VERTICAL
				currentPos.AddXY(0, slotH )
			ElseIf _orientation = GUI_OBJECT_ORIENTATION_HORIZONTAL
				currentPos.AddXY(slotW, 0)
			EndIf

			'add the displacement, z-value is stepping, not for LAST element
			If (i+1) Mod _entryDisplacement.z = 0 And i < _slots.length-1
				currentPos.AddXY(_entryDisplacement.x, _entryDisplacement.y)
			EndIf
		Next
		'return the end of the list coordinate ?!
		Return currentPos
	End Method


	Method GetSlotCoord:TVec3D(slot:Int)
		Return GetSlotOrCoord(slot, Null)
	End Method


	'get a slot by a (global/screen) coord
	Method GetSlotByCoord:Int(coord:TVec2D, isScreenCoord:Int=True)
		'create a copy of the given coord - avoids modifying it
		Local useCoord:TVec2D = coord.copy()

		'convert global/screen to local coords
		If isScreenCoord Then useCoord.AddXY(-Self.GetScreenX(),-Self.GetScreenY())
		Return GetSlotOrCoord(-1, useCoord).z
	End Method


	Method GetItemByCoord:TGUIobject(coord:TVec2D)
		Local slot:Int = Self.GetSlotByCoord(coord)
		Return Self.GetItemBySlot(slot)
	End Method


	'returns the slot of the previous occupied slot
	Method GetPreviousUsedSlot:Int(slot:Int)
		Local previousSlot:Int = slot-1
		If previousSlot < 0  Or previousSlot > Self._slots.length-1 Then Return -1
		While previousSlot >= 0
			If Self._slots[previousSlot] Then Return previousSlot
			previousSlot:-1
		Wend
		Return -1
	End Method


	'returns the slot of the next occupied slot
	Method GetNextUsedSlot:Int(slot:Int)
		Local nextSlot:Int = slot+1
		If nextSlot < 0  Or nextSlot > Self._slots.length-1 Then Return -1
		While nextSlot <= Self._slots.length-1
			If Self._slots[nextSlot] Then Return nextSlot
			nextSlot:+1
		Wend
		Return -1
	End Method


	Method GetItemBySlot:TGUIobject(slot:Int)
		If slot < 0 Or slot > Self._slots.length-1 Then Return Null

		Return Self._slots[slot]
	End Method


	'set the slots and emits events
	Method _SetSlot:Int(slot:Int, item:TGUIobject)
		If slot < 0 Or slot > Self._slots.length-1 Then Return False

		If item
			EventManager.triggerEvent(TEventSimple.Create("guiList.addItem", new TData.Add("item", item).AddNumber("slot",slot) , Self))
			Self._slots[slot] = item
		Else
			If Self._slots[slot]
				EventManager.triggerEvent(TEventSimple.Create("guiList.removeItem", new TData.Add("item", Self._slots[slot]).AddNumber("slot",slot) , Self))
				Self._slots[slot] = Null
			EndIf
		EndIf
		Return True
	End Method


	'may return a object which was on the place where the new item is to position
	Method SetItemToSlot:Int(item:TGUIobject,slot:Int)
		Local itemSlot:Int = Self.GetSlot(item)
		'somehow we try to place an item at the place where the item
		'already resides
		If itemSlot = slot Then Return True

		'is there another item?
		Local dragItem:TGUIobject = TGUIobject(Self.getItemBySlot(slot))

		If dragItem
			'do not allow if the underlying item cannot get dragged
			If Not dragItem.isDragable() Then Return False

			'ask others if they want to intercept that exchange
			Local event:TEventSimple = TEventSimple.Create( "guiSlotList.onBeginReplaceSlotItem", new TData.Add("source", item).Add("target", dragItem).AddNumber("slot",slot), Self)
			EventManager.triggerEvent(event)

			If Not event.isVeto()
				'remove the other one from the panel - and add back to guimanager
				If dragItem._parent Then dragItem._parent.RemoveChild(dragItem)

				'drag the other one
				dragItem.drag()
				'unset the occupied slot
				Self._SetSlot(slot, Null)

				EventManager.triggerEvent(TEventSimple.Create( "guiSlotList.onReplaceSlotItem", new TData.Add("source", item).Add("target", dragItem).AddNumber("slot",slot) , Self))
			EndIf
		EndIf

		'if the item is already on the list, remove it from the former slot
		If itemSlot >= 0 Then Self._SetSlot(itemSlot, Null)

		'set the item to the new slot
		Self._SetSlot(slot, item)

		guiEntriesPanel.addChild(item)

		Self.RecalculateElements()

		Return True
	End Method


	'override default handler for the case of dropping something back to
	'its parent
	Method HandleDropBack:Int(triggerEvent:TEventBase)
		'as slotlists can easily compare "old slot" and "dropzone"-slot
		'we use this to check if the slot is changing..
		Local dropCoord:TVec2D = TVec2D(triggerEvent.GetData().get("coord"))
		Local item:TGUIobject = TGUIobject(triggerEvent.GetSender())
		'skip handling if important data is missing/incorrect
		If Not dropCoord Or Not item Then Return False

		'the drop-coordinate is the same one as the original slot, so we
		'handled that situation
		If dropCoord And GetSlotByCoord(dropCoord) = GetSlot(item)
			Return True
		EndIf

		Return False
	End Method



	'overrideable AddItem-Handler
	Method AddItem:Int(item:TGUIobject, extra:Object=Null)
		Local addToSlot:Int = -1
		Local extraIsRawSlot:Int = False
		If String(extra) <> ""
			addToSlot = Int( String(extra) )
			extraIsRawSlot = True
		Endif

		'search for first free slot
		If Self._autofillSlots Then addToSlot = Self.getFreeSlot()
		'auto slot requested
		If extraIsRawSlot And addToSlot = -1 Then addToSlot = Self.getFreeSlot()

		'no free slot or none given? find out on which slot we are dropping
		'if possible, drag the other one and drop the new
		If addToSlot < 0
			Local data:TData = TData(extra)
			If Not data Then Return False

			Local dropCoord:TVec2D = TVec2D(data.get("coord"))
			If Not dropCoord Then Return False

			'set slot to land
			addToSlot = Self.GetSlotByCoord(dropCoord)
			'no slot was hit
			If addToSlot < 0 Then Return False
		EndIf

		'ask if an add to this slot is ok
		Local event:TEventSimple =  TEventSimple.Create("guiList.TryAddItem", new TData.Add("item", item).AddNumber("slot",addtoSlot) , Self)
		EventManager.triggerEvent(event)
		If event.isVeto() Then Return False

		'return if there is an underlying item which cannot get dragged
		Local dragItem:TGUIobject = TGUIobject(Self.getItemBySlot(addToSlot))
		If dragItem And Not dragItem.isDragable() Then Return False

		Return Self.SetItemToSlot(item, addToSlot)
	End Method


	'overrideable RemoveItem-Handler
	Method RemoveItem:Int(item:TGUIobject)
		Local slot:Int = GetSlot(item)
		If slot >=0
			'ask if a removal from this slot is ok
			Local event:TEventSimple =  TEventSimple.Create("guiList.TryRemoveItem", new TData.Add("item", item).AddNumber("slot",slot) , Self)
			EventManager.triggerEvent(event)
			If event.isVeto() Then Return False


			'remove from list - and add back to guimanager
			'do not call Remove() as Remove() could call RemoveItem() again
			'item.Remove()

			'remove it
			Self._SetSlot(slot, Null)
			'remove from panel - and add back to guimanager
			'guiEntriesPanel.removeChild(item)

			Self.RecalculateElements()
			Return True
		EndIf
		Return False
	End Method


	Method DrawDebug()
		If _debugMode
			Local atPoint:TVec2D = GetScreenPos()
			'restrict by scrollable panel - if not possible, there is no "space left"
			If guiEntriesPanel.RestrictViewPort()
				Local pos:TVec3D = Null
				SetAlpha 0.4
				For Local i:Int = 0 To Self._slots.length-1
					pos = GetSlotOrCoord(i)
					'print "slot "+i+": "+pos.GetX()+","+pos.GetY() +" result: "+(atPoint.GetX()+pos.getX())+","+(atPoint.GetY()+pos.getY()) +" h:"+self._slotMinDimension.getY()
					SetColor 0,0,0
					DrawRect(atPoint.GetX()+pos.getX(), atPoint.GetY()+pos.getY(), _slotMinDimension.getX(), _slotMinDimension.getY())
					SetColor 255,255,255
					DrawRect(atPoint.GetX()+pos.getX()+1, atPoint.GetY()+pos.getY()+1, _slotMinDimension.getX()-2, _slotMinDimension.getY()-2)
					SetColor 0,0,0
					DrawText("slot "+i+"|"+GetSlotByCoord(pos.ToVec2D()), atPoint.GetX()+pos.getX(), atPoint.GetY()+pos.getY())
					SetColor 255,255,255
				Next
				SetAlpha 1.0
				ResetViewPort()
			EndIf
		EndIf
	End Method


	Method RecalculateElements:Int()
		'set startpos at point of block displacement
		Local currentPos:TVec3D = _entriesBlockDisplacement.copy()
		Local coveredArea:TRectangle = new TRectangle.Init(0,0,_entriesBlockDisplacement.x,_entriesBlockDisplacement.y)
		For Local i:Int = 0 To Self._slots.length-1
			Local slotW:Int = _slotMinDimension.getX()
			Local slotH:Int = _slotMinDimension.getY()
			'only use slots real dimension if occupied and not fixed
			If _slots[i] And Not _fixedSlotDimension
				slotW = Max(slotW, _slots[i].rect.getW())
				slotH = Max(slotH, _slots[i].rect.getH())
			EndIf

			'move entry's position to current one
			If _slots[i] Then _slots[i].rect.position.CopyFrom(currentPos.ToVec2D())

			'resize covered area
			coveredArea.position.setXY( Min(coveredArea.position.x, currentPos.x), Min(coveredArea.position.y, currentPos.y) )
			coveredArea.dimension.setXY( Max(coveredArea.dimension.x, currentPos.x+slotW), Max(coveredArea.dimension.y, currentPos.y+slotH) )


			If _orientation = GUI_OBJECT_ORIENTATION_VERTICAL
				currentPos.AddXY(0, slotH )
			ElseIf Self._orientation = GUI_OBJECT_ORIENTATION_HORIZONTAL
				currentPos.AddXY(slotW, 0)
			EndIf

			'add the displacement, z-value is stepping, not for LAST element
			If (i+1) Mod Self._entryDisplacement.z = 0 And i < _slots.length-1
				currentPos.AddXY(_entryDisplacement.x, _entryDisplacement.y)
			EndIf
		Next

		'resize container panel
		Local dimension:TVec2D = new TVec2D.Init(coveredArea.getW() - coveredArea.getX(), coveredArea.getH() - coveredArea.getY())
		guiEntriesPanel.minSize.setXY(dimension.getX(), dimension.getY() )
		guiEntriesPanel.resize(dimension.getX(), dimension.getY() )

		If _orientation = GUI_OBJECT_ORIENTATION_VERTICAL
			'set scroll limits:
			'maximum is at the bottom of the area, not top - so subtract height
			guiEntriesPanel.SetLimits(0, -(dimension.getY() - guiEntriesPanel.rect.GetH()) )
		ElseIf _orientation = GUI_OBJECT_ORIENTATION_HORIZONTAL
			'set scroll limits:
			'maximum is at the bottom of the area, not top - so subtract height
			guiEntriesPanel.SetLimits(-(dimension.getX() - guiEntriesPanel.rect.GetW()), 0 )
		EndIf

		'if not all entries fit on the panel, enable scroller
		SetScrollerState(dimension.getX() > guiEntriesPanel.rect.GetW(), ..
		                 dimension.getY() > guiEntriesPanel.rect.GetH() ..
		                )
	End Method
End Type
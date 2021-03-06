Rem
	====================================================================
	class providing a graphical tooltip functionality
	====================================================================

	Basic tooltip


	====================================================================
	If not otherwise stated, the following code is available under the
	following licence:

	LICENCE: zlib/libpng

	Copyright (C) 2002-2015 Ronny Otto, digidea.de

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
EndRem
SuperStrict
Import "base.framework.entity.bmx"
Import "base.gfx.bitmapfont.bmx"

'tooltips containing headline and text, updated and drawn by Tinterface
Type TTooltip Extends TEntity
	Field lifetime:Float		= 0.1		'how long this tooltip is existing
	Field fadeValue:Float		= 1.0		'current fading value (0-1.0)
	Field _startLifetime:Float	= 1.0		'initial lifetime value
	Field _startFadingTime:Float= 0.20		'at which lifetime fading starts
	Field title:String
	Field content:String
	Field minContentWidth:int	= 120
	'left (2) and right (4) is for all elements
	'top (1) and bottom (3) padding for content
	Field padding:TRectangle	= new TRectangle.Init(3,5,4,7)
	Field image:TImage			= Null
	Field dirtyImage:Int		= 1
	Field tooltipImage:Int		=-1
	Field titleBGtype:Int		= 0
	Field enabled:Int			= 0

	Global tooltipHeader:TSprite
	Global tooltipIcons:TSprite

	Global useFontBold:TBitmapFont
	Global useFont:TBitmapFont
	Global imgCacheEnabled:Int	= True


	Function Create:TTooltip(title:String = "", content:String = "unknown", x:Int = 0, y:Int = 0, w:Int = -1, h:Int = -1, lifetime:Int = 300)
		Local obj:TTooltip = New TTooltip
		obj.Initialize(title, content, x, y, w, h, lifetime)

		Return obj
	End Function


	Method Initialize:Int(title:String="", content:String="unknown", x:Int=0, y:Int=0, w:Int=-1, h:Int=-1, lifetime:Int=50)
		Self.title				= title
		Self.content			= content
		Self.area				= new TRectangle.Init(x, y, w, h)
		Self.tooltipimage		= -1
		Self.lifetime			= lifetime
		Self._startLifetime		= Float(lifetime) / 1000.0 	'in seconds
		Self._startFadingTime	= Min(_startLifetime/2.0, 0.1)
		Self.Hover()
	End Method


	'sort tooltips according lifetime (dying ones behind)
	Method Compare:Int(other:Object)
		Local otherTip:TTooltip = TTooltip(other)
		'no weighting
		If Not otherTip then Return 0
		If otherTip = Self then Return 0
		If otherTip.GetLifePercentage() = GetLifePercentage() Then Return 0
		'below me
		If otherTip.GetLifePercentage() < GetLifePercentage() Then Return 1
		'on top of me
		Return -1
	End Method


	'returns (in percents) how many lifetime is left
	Method GetLifePercentage:float()
		return Min(1.0, Max(0.0, lifetime / _startLifetime))
	End Method


	'reset lifetime
	Method Hover()
		lifeTime = _startLifetime
		fadeValue = 1.0
	End Method


	Method Update:Int()
		if not enabled then return False
		
		lifeTime :- GetDeltaTimer().GetDelta()

		'start fading if lifetime is running out (lower than fade time)
		If lifetime <= _startFadingTime
			fadeValue :- GetDeltaTimer().GetDelta()
			fadeValue :* 0.8 'speed up fade
		EndIf

		If lifeTime <= 0 ' And enabled 'enabled - as pause sign?
			Image	= Null
			enabled	= False
			Return False
		EndIf

		'limit to visible areas
		'-> moves tooltip  so that everything is visible on screen
		local outOfScreenLeft:int = Min(0, GetScreenX())
		local outOfScreenRight:int = Max(0, GetScreenX() + GetWidth() - GraphicsWidth())
		local outOfScreenTop:int = Min(0, GetScreenY())
		local outOfScreenBottom:int = Max(0, GetScreenY() + GetHeight() - GraphicsHeight())
		if outOfScreenLeft then area.position.SetX( area.GetX() + outOfScreenLeft )
		if outOfScreenRight then area.position.SetX( area.GetX() - outOfScreenRight )
		if outOfScreenTop then area.position.SetY( area.GetY() + outOfScreenTop )
		if outOfScreenBottom then area.position.SetY( area.GetY() - outOfScreenBottom )

		Return True
	End Method


	Method getWidth:Int()
		If Not DirtyImage And Image And imgCacheEnabled Then Return image.width

		'manual config
		If area.GetW() > 0 Then Return area.GetW()

		'auto width calculation
		If area.GetW() <= 0
			Local result:Int = 0
			local paddingLeftRight:int = 6
			'width from title + content + spacing
			result = UseFontBold.getWidth(title)
			'add icon to width
			If tooltipimage >=0 Then result:+ ToolTipIcons.framew + 2
			'compare with content text width
			result = Max(GetContentWidth(), result)
			'add padding
			result:+ padding.GetLeft() + padding.GetRight()

			Return result
		EndIf
	End Method


	Method getHeight:Int()
		If Not DirtyImage And Image And imgCacheEnabled Then Return image.height

		'manual config
		If area.GetH() > 0 Then Return area.GetH()

		'auto height calculation
		If area.GetH() <= 0
			Local result:Int = 0
			'height from title + content + spacing
			result:+ getTitleHeight()
			result:+ getContentHeight(GetWidth())
			Return result
		EndIf
	End Method


	Method getTitleHeight:Int()
		Local result:Int = TooltipHeader.area.GetH()
		'add icon to height of caption
		'If tooltipimage >= 0 Then result :+ 2
		Return result
	End Method


	Method SetTitle:Int(value:String)
		if title = value then return FALSE

		title = value
		'force redraw/cache reset
		dirtyImage = True
	End Method


	Method SetContent:Int(value:String)
		if content = value then return FALSE

		content = value
		'force redraw/cache reset
		dirtyImage = True
	End Method


	Method getContentWidth:Int()
		'only add a line if there is text
		if content <> "" then return minContentWidth
		return 0

		'If Len(content)>1 Then Return UseFont.getWidth(content)
		'Return 0
	End Method


	Method GetContentInnerWidth:Int()
		return getContentWidth() - padding.GetLeft() - padding.GetRight()
	End Method


	Method GetContentHeight:Int(width:int)
		local result:int = 0
		local maxTextWidth:int = width - padding.GetLeft() - padding.GetRight()

		'only add a line if there is text
		If content <> ""
			result :+ UseFont.getBlockHeight(content, maxTextWidth, -1)
			result :+ padding.GetTop() + padding.GetBottom()
		endif
		Return result
	End Method


	Method DrawShadow(width:Float, height:Float)
		SetColor 0, 0, 0
		SetAlpha getFadeAmount() * 0.3
		DrawRect(GetScreenX()+2, GetScreenY()+2, width, height)

		SetAlpha getFadeAmount() * 0.1
		DrawRect(GetScreenX()+1, GetScreenY()+1, width, height)
		SetColor 255,255,255
	End Method


	Method getFadeAmount:Float()
		Return fadeValue
	End Method


	Method SetHeaderColor:int()
		If TitleBGtype = 0 Then SetColor 250,250,250
		If TitleBGtype = 1 Then SetColor 200,250,200
		If TitleBGtype = 2 Then SetColor 250,150,150
		If TitleBGtype = 3 Then SetColor 200,200,250
	End Method


	Method DrawHeader:Int(x:Float, y:Float, width:Int, height:Int)
		SetHeaderColor()
		TooltipHeader.TileDraw(x, y, width, height)

		SetColor 255,255,255
		Local displaceX:Float = 0.0
		If tooltipimage >=0
			TTooltip.ToolTipIcons.Draw(x, y, tooltipimage)
			displaceX = TTooltip.ToolTipIcons.framew
		EndIf
'		SetAlpha getFadeAmount()
		'caption
		useFontBold.drawStyled(title, x + padding.GetLeft() + displaceX, y + (height - useFontBold.getMaxCharHeight())/2 , TColor.Create(50,50,50), 2, 1, 0.1)
'		SetAlpha 1.0
	End Method


	Method DrawContent:Int(x:Int, y:Int, width:Int, height:Int)
		If content = "" then return FALSE
		local maxTextWidth:int = width - padding.GetLeft() - padding.GetRight()
		SetColor 90,90,90
		Usefont.drawBlock(content, x + padding.GetLeft(), y + padding.GetTop(), maxTextWidth, -1)
		SetColor 255, 255, 255
	End Method


	Method DrawBackground:int(x:int, y:int, w:int, h:int)
		local oldCol:TColor = new TColor.Get()

		'bright background
		SetColor 255,255,255
		DrawRect(x, y, w, h)

		oldCol.SetRGB()
	End Method


	Method Render:Int(xOffset:Float = 0, yOffset:Float=0, alignment:TVec2D = Null)
		If Not enabled Then Return 0

		local col:TColor = TColor.Create().Get()

		If DirtyImage Or Not Image Or Not imgCacheEnabled
			local boxWidth:int = GetWidth()
			Local boxHeight:Int	= GetHeight()
			Local boxInnerWidth:Int	= boxWidth - 2
			Local boxInnerHeight:Int = boxHeight - 2
			Local innerX:int = GetScreenX() + 1
			Local innerY:int = GetScreenY() + 1
			Local captionHeight:Int = GetTitleHeight()
			DrawShadow(boxWidth, boxHeight)

			SetAlpha col.A * getFadeAmount()
			SetColor 0,0,0
			'border
			DrawRect(GetScreenX(), GetScreenY(), boxWidth, boxHeight)
			SetColor 255,255,255

			'draw background of whole tooltip
			DrawBackground(innerX, innerY, boxInnerWidth, boxInnerHeight)

			'draw header including caption and header background
			DrawHeader(innerX, innerY, boxInnerWidth, captionHeight)

			'draw content - do not use contentHeight here..
			'if boxHeight was defined manually we just give it the left space
			'as a caption has to get drawn in all cases...
			DrawContent(innerX, innerY + captionHeight, boxInnerWidth, boxInnerHeight - captionHeight)
rem
			If imgCacheEnabled 'And lifetime = startlifetime
				local startX:int = Max(GetScreenX(), 0)
				local startY:int = Max(GetScreenY(), 0)
				local endX:int = Min(800, boxWidth - startX)
				local endY:int = Min(600, boxHeight - startY)
				boxWidth = endX - startX
				boxHeight = endY - startY

				Image = TImage.Create(boxWidth, boxHeight, 1, 0, 255, 0, 255)
				'old without border check: image.pixmaps[0] = VirtualGrabPixmap(Self.area.GetX(), Self.area.GetY(), boxWidth, boxHeight)
				image.pixmaps[0] = VirtualGrabPixmap(startX, startY, boxWidth, boxHeight)
				DirtyImage = False
			EndIf
endrem
		Else 'not dirty
			DrawShadow(ImageWidth(image),ImageHeight(image))
			SetAlpha col.a * getFadeAmount()
			SetColor 255,255,255
			DrawImage(image, GetScreenX(), GetScreenY())
			SetAlpha 1.0
		EndIf

		col.SetRGBA()

		'=== DRAW CHILDREN ===
		RenderChildren(xOffset, yOffset, alignment)
	End Method
End Type
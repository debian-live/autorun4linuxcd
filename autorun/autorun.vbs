' Copyright (C) 2007 Franklin Piat <fpiat@bigfoot.com>
'
' This program is free software; you can redistribute it and/or modify
' it under the terms of the GNU General Public License as published by
' the Free Software Foundation; either version 2 of the License, or
' (at your option) any later version.
'
' This program is distributed in the hope that it will be useful, but
' WITHOUT ANY WARRANTY; without even the implied warranty of
' MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
' General Public License for more details.

Option Explicit
Const FsoOpenForReading = 1, FsoOpenForWriting = 2, FsoOpenForAppending = 8
Const TristateFalse = -2
Dim CurrentTab
Dim DefaultTab
Dim WshShell
Dim fso
Dim oScriptFile
Dim oScriptFolder

Sub About_callBack()
	' nothing to do
End Sub

Sub Refs_callBack()
	' nothing to do
End Sub

Sub MainPage_callBack()
	' nothing to do
End Sub

Sub QemuPage_callBack()
	' nothing to do
End Sub

Sub QemuOptions_callBack()
	' nothing to do
End Sub

' ///////////////////////////////////////////////////////////////

Function Between( ByRef x, ByRef minVal, ByRef maxVal )
	Between = Min(Max( minVal, x),maxVal)
End Function

Function Max(ByRef a, ByRef b)
	If (a>b) Then
		Max = a
	Else
		Max = b
	End If
End Function

Public Function Min(ByRef a,ByRef b)
	If (a>b) Then
		Min = b
	Else
		Min = a
	End If
End Function

' ///////////////////////////////////////////////////////////////

Sub buildMenu()
	Dim td, action,title, node
	For each td in document.getElementById("main").childNodes
		title = td.title
		action = td.id
		action = left(action,len(action)-7)
		Set node = document.createElement("<input id=""" & action & "Tab"" type=""button"" href=""#" & td.id & """ class=""tabTitle"" value=""" & title & """ />")
		menu.appendChild(node)
		Set document.getElementById(action & "Tab").onclick =  GetRef("ShowHideTab")
	Next
End Sub

Sub DOM_removeChildren(obj)
	Dim subObj
	For Each subObj in obj.childNodes
		If (subObj.hasChildNodes()) Then
			DOM_removeChildren(subObj)
		End If
		obj.removeChild(subObj)
	 Next
End Sub

Sub ShowHideTab()
	Dim action, Sub_exists

	if (window.event.type = "click" ) Then
		action = window.event.srcElement.id
		If (Not  right(action ,3) = "Tab") Then
			Exit Sub
		End If
		action = left(action,len(action)-3)
	Else
		action = DefaultTab
	End If

	If (CurrentTab <> "") Then
		window.document.getElementById(CurrentTab & "Content").style.display = "none"
		window.document.getElementById(CurrentTab & "Tab").style.borderColor = ""
		window.document.getElementById(CurrentTab & "Tab").style.backgroundColor = ""
  		window.document.getElementById(CurrentTab & "Tab").style.color = ""
	End If
	window.document.getElementById(action & "Content").style.display = "block"
	window.document.getElementById(action & "Tab").style.borderColor  = ""
	window.document.getElementById(action & "Tab").style.backgroundColor = "highlight"
	window.document.getElementById(action & "Tab").style.color = "CaptionText"
	CurrentTab = action
	Execute("Call " & action & "_callBack()")
End Sub

Function checkRunningInHTA()
	checkRunningInHTA = not IsNull(myHta.getAttribute("commandLine"))
End Function

Sub ParseArgs
	'Parse Args:
	'http://www.microsoft.com/technet/scriptcenter/resources/qanda/apr05/hey0420.mspx
	arrCommands = Split(oHTA.commandLine, chr(34))
	For i = 3 to (Ubound(arrCommands) - 1) Step 2
		Msgbox arrCommands(i)
	Next
End Sub


Sub Could_Not_Load_AutorunVBS()
	' XXX.VBS has been fount.. fine !
	' This sub is for debug purpose only
End Sub

' ///////////////////////////////////////////////////////////////


Sub runVM()
	Dim cmd, Drive
	Drive = oDrive.driveLetter
	'Drive = "D"
	cmd = """" & oScriptFolder.Path & "\qemu\qemu.exe"" -L " & oScriptFolder.Path & "\qemu\ -no-kqemu " _
		& " -hda \\.\" & Drive  & ": -snapshot "_
		& " -kernel """ & Drive &":\" & Replace(bKernel.value,"/","\") & """ "
	If (Trim(bInitrd.value) <> "") Then
		cmd = cmd & " -initrd """ & Drive &":\" & Replace(Trim(bInitrd.value),"/","\") & """ "
	End If

	If (Trim(bAppend.value) <> "") Then
		cmd = cmd & " -append """ & Trim(bAppend.value) & """ "
	End If

	WshShell.run  cmd
End Sub


Sub keyEventHandler()
	key = window.event.Keycode
	If (key >= 48 And key <= 57) Then
		key = key - 48
		If (helpPages.Exists("F" & key) And VarType(WshShell) = 9) Then
			WshShell.exec "notepad " & oDrive.driveLetter &":\"& helpPages.item("F" & key)
		End If
	End If
End Sub

sub configListChanged()
	dim s, p
	bKernel.value = bootConfigs.item(configList.value).item("KERNEL")
	bIPAppend.value = bootConfigs.item(configList.value).item("IPAPPEND")
	s = " " &bootConfigs.item(configList.value).item("APPEND")
	p = InStr(s,"initrd=")
	If (p>0) Then
		bAppend.value = Trim( Left(s,p-1) & Mid(s,InStr(p,s," ")))
		bInitrd.value = Mid(s,p+7,InStr(p,s," ")-1 -7)
	Else
		bInitrd.value = ""
		bAppend.value = bootConfigs.item(configList.value).item("APPEND")
	End If
	Call localeChanged()
End Sub


' ## LOAD SYSCONF FILE
Sub LoadSysConfFile()
	Dim ts, currentLabel, s, p, keyword, args, bootConfigs_default, keynames,i, myOpt, lastline
	Set helpPages = CreateObject("Scripting.Dictionary")
	Set bootConfigs = CreateObject("Scripting.Dictionary")
	On Error Resume next
	Err.Clear
	Set ts = fso.OpenTextFile(oDrive.driveLetter & ":\syslinux.cfg", FsoOpenForReading, false, TristateFalse)
	If (Err.Number > 0) Then
		Err.Clear
		Set ts = fso.OpenTextFile(oDrive.driveLetter & ":\syslinux\syslinux.cfg", FsoOpenForReading, false, TristateFalse)
	End If
	If (Err.Number > 0) Then
		Err.Clear
		Set ts = fso.OpenTextFile(oDrive.driveLetter & ":\isolinux\isolinux.cfg", FsoOpenForReading, false, TristateFalse)
	End If
	If (Err.Number > 0) Then
		runVmBtn.disabled = "disabled"
		Exit Sub
	End If
	On Error Goto 0
	currentLabel=""
	bootConfigs.add currentLabel, CreateObject("Scripting.Dictionary")
	bootConfigs.item(currentLabel).add "KERNEL",   "linux"
	bootConfigs.item(currentLabel).add "APPEND",   ""
	bootConfigs.item(currentLabel).add "IPAPPEND", ""
	Do While Not ts.AtEndOfStream
		s = Trim(Replace(ts.ReadLine,vbTab," "))
		p = InStr(s," ")
		If (( Left(s,1) <> "#" ) And (s <> "") And (p>1) ) Then
			keyword = UCase(Left(s, p - 1 ))
			If (keyword = "MENU") Then
				p = InStr(p+1,s," ")
				keyword = UCase(Left(s, p - 1 ))
				' If (keyword = "MENU LABEL") Then keyword="LABEL"
			End If
			args = Ltrim(Mid(s, p + 1))
			Select Case keyword
				Case "DEFAULT"
					bootConfigs_default = args
				Case "LABEL"
					currentLabel = args
					If Not bootConfigs.Exists(args) Then
						bootConfigs.add args, CreateObject("Scripting.Dictionary")
						If ((Left(lastline,2) = "# ") and (Trim(Mid(lastline,2,99)) <> "")) Then
							bootConfigs.item(args).add "LABEL", Trim(Mid(lastline,2,99))
						Else
							bootConfigs.item(args).add "LABEL", Trim(args)
						End If
						bootConfigs.item(args).add "KERNEL", bootConfigs.item("").item("KERNEL")
						bootConfigs.item(args).add "APPEND", bootConfigs.item("").item("APPEND")
						bootConfigs.item(args).add "IPAPPEND", bootConfigs.item("").item("IPAPPEND")
					End If
				Case "MENU LABEL"
					bootConfigs.item(currentLabel).item("LABEL") = Trim(args)
				Case "KERNEL"
					bootConfigs.item(currentLabel).item("KERNEL") = args
				Case "APPEND"
					If (args="-") Then
						bootConfigs.item(currentLabel).item("APPEND") = ""
					Else
						bootConfigs.item(currentLabel).item("APPEND") = args
					End If
				Case "IPAPPEND"
					If (args="-") Then
						bootConfigs.item(currentLabel).item("APPEND") = ""
					Else
						bootConfigs.item(currentLabel).item("APPEND") = args
					End If
				Case "F1","F2","F3","F4","F5","F6","F7","F8","F9","F0"
					If Not helpPages.Exists(keyword) Then
						helpPages.add keyword, args
					Else
						helpPages.item(keyword) = args
					End If
				Case "SAY"
					'TODO
				Case "DISPLAY"
					'TODO
				Case "ALLOWOPTIONS"
				Case "IMPLICIT"
				Case "PROMPT"
					'TODO
				Case "TIMEOUT"
					'Ignored !
				Case Else
					MsgBox "Ignored Line :" & vBcRlF & "'" & keyword & "' '" & args & "'"
			End Select
		End If
		lastline = s
	Loop


	' ## insert syslinux menu entries in the dropdown list
	If (bootConfigs.count > 1) Then
		configList.style.Visibility= "visible"
		keynames = bootConfigs.Keys
		For i = 0 to bootConfigs.count -1
			If ((keyNames(i) <> "" Or keyNames(i) = bootConfigs_default) _
				AND Not ( InStr(LCase(bootConfigs.item(keyNames(i)).item("KERNEL")),"memtest") >=1 )) Then
				Set myOpt = Document.createElement("OPTION")
				myOpt.Text = bootConfigs.item(keyNames(i)).item("LABEL")
				myOpt.Value = keyNames(i)
				If (keyNames(i) = bootConfigs_default) Then
					myOpt.selected="selected"
				End If
				configList.add(myOpt)
			End If
		Next
	Else
		configList.style.Display = "none"
		configList.style.Visibility= "hidden"
	End if
	' ## trigger an event, to reload "options" page.
	Call configListChanged()
End Sub

Sub localeChanged()
	Dim locale , p, p2
	locale = localesList.value
	If (InStr(locale,".")>0) Then
		locale = Left (locale, InStr(locale,".")-1)
	End If
	p = inStr(Lcase(bAppend.value), "lang=")
	if (p >= 1) Then
		p2 = inStr(p, Lcase(bAppend.value), " ")
		if (p2 >= 1) Then
			bAppend.value = Left(bAppend.value,p -1) & "lang=" & locale & Mid(bAppend.value,p, p2-p)
		Else
			bAppend.value = Left(bAppend.value,p -1) & "lang=" & locale
		End If
	Else
		bAppend.value = bAppend.value & " lang=" & locale
	End if

End Sub


' ##Let's pick a keyboard and language (according to current windows session)
Sub ChooseLang()
	Dim lang,i,j,myOpt
	If (InStr("PAD," & availableLocales & ",",  "," & Left(navigator.userLanguage,5)) > 1) Then
		lang = Left(navigator.userLanguage,5)
	ElseIf (InStr("PAD," & availableLocales & ",",  "," & Left(navigator.userLanguage,2)) > 1) Then
		lang = Left(navigator.userLanguage,2)
	Else
		lang = ""
	End If

	Dim ts, s
	On Error Resume next
	Err.Clear
	Set ts = fso.OpenTextFile(oDrive.driveLetter & ":\autorun\language.txt", FsoOpenForReading, false, TristateFalse)
	If (Err.Number = 0) Then
		On Error GoTo 0
		Do While Not ts.AtEndOfStream
			s = Split(Trim(Replace(ts.ReadLine,vbTab," ")),";",-1, vbTextCompare)
			If (UBound(s) >= 6) Then
				Set myOpt = Document.createElement("OPTION")
				myOpt.Value = s(4)
				myOpt.Text = s(0)
				localesList.add(myOpt)
				If (s(2) = lang) Then
					myOpt.selected="selected"
				End If
			End If
		Loop
	Else
		On Error GoTo 0
		i = 1
		Do While (inStr(i,availableLocales,",") <> False)
			j = inStr(i,availableLocales,",")
			Set myOpt = Document.createElement("OPTION")
			myOpt.Value = Mid(availableLocales,i,j-i)
			myOpt.Text = myOpt.Value
			localesList.add(myOpt)
			i = j+1
		Loop
		localesList.Value = lang
	End If
End Sub

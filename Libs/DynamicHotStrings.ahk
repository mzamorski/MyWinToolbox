#Requires AutoHotkey v2.0

DynamicHotStrings_Register(json)
{
	if !IsSet(json)
	{
		return
	}

	config := DynamicHotStrings_ParseConfiguration(json)
	if !IsObject(config)
	{
		return
	}

	definitions := config["HotStrings"]
	if !IsObject(definitions) || (definitions.Length = 0)
	{
		return
	}

	items := []
	for definition in definitions
	{
		items.Push(Map(
			"Priority", DynamicHotString_GetPriority(definition)
			, "Definition", definition
		))
	}

	;https://biga-ahk.github.io/biga.ahk/#/?id=count
	;Sort(items, "F", CompareByPriorityDesc)

	for item in items
	{
		DynamicHotString_RegisterDefinition(item["Definition"], config)
	}
}

DynamicHotString_RegisterDefinition(definition, config)
{
	if !IsObject(definition)
	{
		return
	}

	try
	{
		if DynamicHotString_HasProperty(definition, ["Enabled", "enabled"])
		{
			enabledValue := ""
			if ArrayUtils.TryGet(definition, ["Enabled", "enabled"], &enabledValue)
			{
				if !DynamicHotString_IsTruthy(enabledValue)
				{
					return
				}
			}
		}

		pattern := DynamicHotString_BuildPattern(definition, config["Defaults"])
		if (pattern = "")
		{
			return
		}

		replacementValue := ""
		if !ArrayUtils.TryGet(definition, ["Text", "text", "Replacement", "replacement", "Content", "content"], &replacementValue)
		{
			return
		}

		replacement := "" . replacementValue
		replacement := DynamicHotString_ApplyPlaceholders(replacement)

		sendMode := ""
		if ArrayUtils.TryGet(definition, ["SendMode", "sendMode"], &sendMode)
		{
			sendMode := StrLower(Trim("" . sendMode))
		}

		scopeInfo := DynamicHotString_PrepareScopeContext(definition, config)
		if !scopeInfo["ShouldRegister"]
		{
			return
		}

		predicate := scopeInfo["Predicate"]
		if predicate
		{
			HotIf(predicate)
		}

		try
		{
			switch sendMode
			{
				case "text":
					Hotstring(pattern, (*) => SendText(replacement))
				case "raw":
					Hotstring(pattern, (*) => Send("{Raw}" . replacement))
				default:
					Hotstring(pattern, replacement)
			}
		}
		catch Error as e
		{
			OutputDebug(Format("[DynamicHotString] Failed to register hotstring. Message: {1}, What: {2}", e.Message, e.What))
		}
		finally
		{
			if predicate
			{
				HotIf()
			}
		}
	}
	catch Error as e
	{
		OutputDebug(Format("[DynamicHotString] Failed to process definition. Message: {1}, What: {2}", e.Message, e.What))
	}
}

DynamicHotString_PrepareScopeContext(definition, config)
{
	result := Map("ShouldRegister", true, "Predicate", 0)

	defaults := config.Has("Defaults") ? config["Defaults"] : Map()
	aliases := config.Has("ScopeAliases") ? config["ScopeAliases"] : Map()

	includeData := DynamicHotString_NormalizeScopeItems(definition, aliases, ["IncludeScopes", "includeScopes"])
	excludeData := DynamicHotString_NormalizeScopeItems(definition, aliases, ["ExcludeScopes", "excludeScopes"])

	includeScopes := includeData["Scopes"]
	excludeScopes := excludeData["Scopes"]
	hasWildcard := includeData["HasWildcard"]
	hasIncludeProperty := DynamicHotString_HasProperty(definition, ["IncludeScopes", "includeScopes"])
	hasExcludeProperty := DynamicHotString_HasProperty(definition, ["ExcludeScopes", "excludeScopes"])

	allowEverywhere := false
	if !hasIncludeProperty && !hasExcludeProperty
	{
		allowEverywhere := true
	}
	else if hasWildcard
	{
		allowEverywhere := true
	}
	else if (includeScopes.Length = 0)
	{
		if (excludeScopes.Length > 0)
		{
			allowEverywhere := true
		}
		else
		{
			scopeMode := defaults.Has("ScopeMode") ? defaults["ScopeMode"] : "include"
			scopeMode := StrLower("" . scopeMode)
			if (scopeMode = "exclude")
			{
				allowEverywhere := true
			}
			else
			{
				result["ShouldRegister"] := false
				return result
			}
		}
	}

	predicate := DynamicHotString_CreateScopePredicate(includeScopes, excludeScopes, allowEverywhere)
	result["Predicate"] := predicate
	return result
}

DynamicHotString_CreateScopePredicate(includeScopes, excludeScopes, allowEverywhere)
{
	hasInclude := includeScopes.Length > 0
	hasExclude := excludeScopes.Length > 0

	if allowEverywhere && !hasInclude && !hasExclude
	{
		return 0
	}

	if !allowEverywhere && !hasInclude
	{
		return 0
	}

	return (*) => DynamicHotString_EvaluateScope(includeScopes, excludeScopes, allowEverywhere)
}

DynamicHotString_EvaluateScope(includeScopes, excludeScopes, allowEverywhere)
{
	info := DynamicHotString_GetActiveWindowInfo()

	for scope in excludeScopes
	{
		if DynamicHotString_WindowMatchesScope(scope, info)
		{
			return false
		}
	}

	if allowEverywhere
	{
		if (includeScopes.Length = 0)
		{
			return true
		}

		for scope in includeScopes
		{
			if DynamicHotString_WindowMatchesScope(scope, info)
			{
				return true
			}
		}

		return true
	}

	for scope in includeScopes
	{
		if DynamicHotString_WindowMatchesScope(scope, info)
		{
			return true
		}
	}

	return false
}

DynamicHotString_GetActiveWindowInfo()
{
	info := Map("Process", "", "Class", "", "Title", "")

	try
	{
		info["Process"] := StrLower("" . WinGetProcessName("A"))
	}
	catch
	{
		info["Process"] := ""
	}

	try
	{
		info["Class"] := "" . WinGetClass("A")
	}
	catch
	{
		info["Class"] := ""
	}

	try
	{
		info["Title"] := "" . WinGetTitle("A")
	}
	catch
	{
		info["Title"] := ""
	}

	return info
}

DynamicHotString_WindowMatchesScope(scope, info)
{
	if !IsObject(scope)
	{
		return false
	}

	if scope.Has("Processes")
	{
		processes := scope["Processes"]
		if (processes.Length > 0)
		{
			if !DynamicHotString_ArrayContains(processes, info["Process"])
			{
				return false
			}
		}
	}

	if scope.Has("Classes")
	{
		classes := scope["Classes"]
		if (classes.Length > 0)
		{
			if !DynamicHotString_ArrayContains(classes, info["Class"], false)
			{
				return false
			}
		}
	}

	if scope.Has("TitleRegex")
	{
		titlePattern := scope["TitleRegex"]
		if (titlePattern != "")
		{
			if !RegExMatch(info["Title"], "" . titlePattern)
			{
				return false
			}
		}
	}

	return true
}

DynamicHotString_ArrayContains(collection, value, caseInsensitive := true)
{
	if !IsObject(collection)
	{
		return false
	}

	needle := "" . value
	needle := caseInsensitive ? StrLower(needle) : needle

	for item in collection
	{
		candidate := "" . item
		candidate := caseInsensitive ? StrLower(candidate) : candidate
		if (candidate = needle)
		{
			return true
		}
	}

	return false
}

DynamicHotString_NormalizeScopeItems(definition, aliases, propertyNames)
{
	result := Map("Scopes", [], "HasWildcard", false)
	value := ""
	if !ArrayUtils.TryGet(definition, propertyNames, &value)
	{
		return result
	}

	for item in value
	{
		if item is String
		{
			scopeName := Trim("" . item)
			if (scopeName = "")
			{
				continue
			}

			if (scopeName = "*")
			{
				result["HasWildcard"] := true
				continue
			}

			aliasKey := StrLower(scopeName)
			if aliases.Has(aliasKey)
			{
				result["Scopes"].Push(aliases[aliasKey])
			}
			else
			{
				OutputDebug(Format("[DynamicHotString] Unknown scope alias: {1}", scopeName))
			}
		}
		else if IsObject(item)
		{
			scopeDefinition := DynamicHotStrings_NormalizeScope(item)
			if IsObject(scopeDefinition)
			{
				result["Scopes"].Push(scopeDefinition)
			}
		}
	}

	return result
}

DynamicHotStrings_ParseConfiguration(rawConfig)
{
	if !IsObject(rawConfig)
	{
		return ""
	}

	config := Map()
	config["Defaults"] := DynamicHotStrings_ParseDefaults(rawConfig)
	config["ScopeAliases"] := DynamicHotStrings_ParseScopeAliases(rawConfig)
	config["HotStrings"] := DynamicHotStrings_ParseDefinitionList(rawConfig)

	return config
}

DynamicHotStrings_ParseDefaults(rawConfig)
{
	defaults := Map("Options", "*", "ScopeMode", "include")

	if (Type(rawConfig) = "OrderedMap") && rawConfig.Has("Defaults")
	{
		defaultsObject := rawConfig["Defaults"]
		if IsObject(defaultsObject)
		{
			value := ""
			if ArrayUtils.TryGet(defaultsObject, ["Options", "options"], &value)
			{
				defaults["Options"] := "" . value
			}

			if ArrayUtils.TryGet(defaultsObject, ["ScopeMode", "scopeMode"], &value)
			{
				scopeMode := StrLower(Trim("" . value))
				if !(scopeMode = "include" || scopeMode = "exclude")
				{
					scopeMode := "include"
				}

				defaults["ScopeMode"] := scopeMode
			}
		}
	}

	return defaults
}

DynamicHotStrings_ParseScopeAliases(rawConfig)
{
	aliases := Map()

	if (Type(rawConfig) = "OrderedMap") && rawConfig.Has("Scopes")
	{
		scopesValue := rawConfig["Scopes"]
		if IsObject(scopesValue) && scopesValue.Has("Aliases")
		{
			aliasContainer := scopesValue["Aliases"]
			if IsObject(aliasContainer)
			{
				for aliasName, aliasDefinition in aliasContainer
				{
					normalized := DynamicHotStrings_NormalizeScope(aliasDefinition)
					if IsObject(normalized)
					{
						normalized["Name"] := aliasName
						aliases[StrLower("" . aliasName)] := normalized
					}
				}
			}
		}
	}

	return aliases
}

DynamicHotStrings_NormalizeScope(scopeDefinition)
{
	if !IsObject(scopeDefinition)
	{
		return ""
	}

	result := Map()

	processValue := ""
	if ArrayUtils.TryGet(scopeDefinition, ["Process", "process", "Processes", "processes"], &processValue)
	{
		processes := DynamicHotStrings_ToArray(processValue)
		if (processes.Length > 0)
		{
			list := []
			for item in processes
			{
				list.Push(StrLower(Trim("" . item)))
			}
			result["Processes"] := list
		}
	}

	classValue := ""
	if ArrayUtils.TryGet(scopeDefinition, ["Class", "class", "Classes", "classes"], &classValue)
	{
		classes := DynamicHotStrings_ToArray(classValue)
		if (classes.Length > 0)
		{
			list := []
			for item in classes
			{
				list.Push("" . item)
			}
			result["Classes"] := list
		}
	}

	titleValue := ""
	if ArrayUtils.TryGet(scopeDefinition, ["TitleRegex", "titleRegex"], &titleValue)
	{
		titlePattern := Trim("" . titleValue)
		if (titlePattern != "")
		{
			result["TitleRegex"] := titlePattern
		}
	}

	return result.Count > 0 ? result : Map()
}

DynamicHotStrings_ParseDefinitionList(rawConfig)
{
	definitions := []
	typeName := Type(rawConfig)

	switch typeName
	{
		case "Array":
			for item in rawConfig
			{
				if IsObject(item)
				{
					definitions.Push(item)
				}
			}

		case "OrderedMap":
			if rawConfig.Has("HotStrings")
			{
				list := rawConfig["HotStrings"]
				if IsObject(list) && Type(list) = "Array"
				{
					for item in list
					{
						if IsObject(item)
						{
							definitions.Push(item)
						}
					}
				}
			}
			else
			{
				for _, item in rawConfig
				{
					if IsObject(item)
					{
						definitions.Push(item)
					}
				}
			}
	}

	return definitions
}

DynamicHotStrings_ToArray(value)
{
	result := []
	if !IsSet(value)
	{
		return result
	}

	if IsObject(value) && (Type(value) = "Array")
	{
		for item in value
		{
			result.Push(item)
		}
	}
	else
	{
		if (value != "")
		{
			result.Push(value)
		}
	}

	return result
}

DynamicHotString_BuildPattern(definition, defaults)
{
	patternValue := ""
	if ArrayUtils.TryGet(definition, ["Pattern", "pattern"], &patternValue)
	{
		return DynamicHotString_NormalizePattern(patternValue)
	}

	triggerValue := ""
	if !ArrayUtils.TryGet(definition, ["Trigger", "trigger"], &triggerValue)
	{
		return ""
	}

	trigger := Trim("" . triggerValue)
	if (trigger = "")
	{
		return ""
	}

	optionsValue := ""
	if ArrayUtils.TryGet(definition, ["Options", "options"], &optionsValue)
	{
		options := "" . optionsValue
	}
	else
	{
		options := defaults.Has("Options") ? ("" . defaults["Options"]) : ""
	}

	pattern := DynamicHotString_ComposePattern(options, trigger)
	return DynamicHotString_NormalizePattern(pattern)
}

DynamicHotString_ComposePattern(options, trigger)
{
	options := Trim("" . options)
	if (options = "")
	{
		return "::" . trigger
	}

	if (SubStr(options, 1, 1) != ":")
	{
		options := ":" . options
	}

	if (SubStr(options, -1) != ":")
	{
		options .= ":"
	}

	return options . trigger
}

; ArrayUtils.TryGet(source, propertyNames, &value)
; {
; 	if !IsObject(propertyNames)
; 	{
; 		return false
; 	}

; 	if !IsObject(source)
; 	{
; 		return false
; 	}

; 	for propertyName in propertyNames
; 	{
; 		if source.Has(propertyName)
; 		{
; 			value := source[propertyName]
; 			return true
; 		}
; 	}

; 	return false
; }

DynamicHotString_HasProperty(source, propertyNames)
{
	value := ""
	return ArrayUtils.TryGet(source, propertyNames, &value)
}

DynamicHotString_GetPriority(definition)
{
	priorityValue := 0

	;if ArrayUtils.TryGet(definition, ["Priority", "priority"], &priorityValue)
	if ArrayUtils.TryGet(definition, ["Priority", "priority"], &priorityValue)
	{
		throw NotImplementedError(A_ThisFunc, "TODO: Priority")
	}

	return 0
}

DynamicHotString_ApplyPlaceholders(value)
{
	result := "" . value

	while RegExMatch(result, "%\{DateTime:([^}]+)\}", &match)
	{
		format := Trim(match[1])
		replacement := ""
		if (format != "")
		{
			try
			{
				replacement := FormatTime(A_Now, format)
			}
			catch
			{
				replacement := ""
			}
		}

		result := StrReplace(result, match[0], replacement, , 1)
	}

	return result
}

DynamicHotString_NormalizePattern(pattern)
{
	pattern := "" . pattern
	pattern := Trim(pattern)

	while (StrLen(pattern) > 0 && SubStr(pattern, -1) = ":")
	{
		pattern := SubStr(pattern, 1, StrLen(pattern) - 1)
	}

	if (pattern != "" && !InStr(pattern, ":"))
	{
		pattern := "::" . pattern
	}

	return pattern
}

DynamicHotString_IsTruthy(value)
{
	if value is String
	{
		normalized := StrLower(Trim(value))
		switch normalized
		{
			case "", "0", "false", "no", "off":
				return false
			default:
				return true
		}
	}

	return value ? true : false
}
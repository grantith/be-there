LoadConfig(config_path, default_config := Map()) {
    config := CloneMap(default_config)
    errors := []

    if FileExist(config_path) {
        json_text := FileRead(config_path)
        try {
            user_config := Jxon_Load(&json_text)
            config := DeepMergeMaps(config, user_config)
        } catch as err {
            errors.Push("config.parse: " err.Message)
            return Map(
                "config", config,
                "errors", errors
            )
        }
    }

    errors := ValidateConfig(config, ConfigSchema())

    return Map(
        "config", config,
        "errors", errors
    )
}

ConfigSchema() {
    return Map(
        "config_version", "number",
        "super_key", "string",
        "apps", [Map(
            "id", "string",
            "hotkey", "string",
            "win_title", "string",
            "run", "string",
            "run_paths", OptionalSpec(["string"])
        )],
        "global_hotkeys", [Map(
            "enabled", "bool",
            "hotkey", "string",
            "target_exes", OptionalSpec(["string"]),
            "send_keys", "string"
        )],
        "window", Map(
            "resize_step", "number",
            "move_step", "number",
            "super_double_tap_ms", "number",
            "move_mode", Map(
                "enable", "bool",
                "cancel_key", "string"
            ),
            "cycle_app_windows_hotkey", "string",
            "center_width_cycle_hotkey", "string"
        ),
        "window_selector", Map(
            "enabled", "bool",
            "hotkey", "string",
            "max_results", "number",
            "title_preview_len", "number",
            "match_title", "bool",
            "match_exe", "bool",
            "include_minimized", "bool",
            "close_on_focus_loss", "bool"
        ),
        "window_manager", Map(
            "grid_size", "number",
            "margins", Map(
                "top", "number",
                "left", "number",
                "right", "number"
            ),
            "gap_px", "number",
            "exceptions_regex", "string"
        ),
        "focus_border", Map(
            "enabled", "bool",
            "border_color", "string",
            "move_mode_color", "string",
            "border_thickness", "number",
            "corner_radius", "number",
            "update_interval_ms", "number"
        ),
        "helper", Map(
            "enabled", "bool",
            "overlay_opacity", "number"
        ),
        "reload", Map(
            "enabled", "bool",
            "hotkey", "string",
            "super_key_required", "bool",
            "watch_enabled", "bool",
            "watch_interval_ms", "number",
            "mode_enabled", "bool",
            "mode_hotkey", "string",
            "mode_timeout_ms", "number"
        )
    )
}

ValidateConfig(config, schema) {
    errors := []
    ValidateNode(config, schema, "config", errors)
    return errors
}

ValidateNode(value, spec, path, errors) {
    if (spec is Map) {
        if spec.Has("__optional__") {
            if (value = "")
                return
            return ValidateNode(value, spec["spec"], path, errors)
        }
        if !(value is Map) {
            errors.Push(path " should be an object")
            return
        }

        for key, _ in spec {
            if !value.Has(key) {
                if (spec[key] is Map && spec[key].Has("__optional__") && spec[key]["__optional__"])
                    continue
                errors.Push(path "." key " is missing")
            }
        }

        for key, val in value {
            if !spec.Has(key) {
                errors.Push(path "." key " is unknown")
                continue
            }
            if (spec[key] is Map && spec[key].Has("__optional__") && spec[key]["__optional__"]) {
                ValidateNode(val, spec[key]["spec"], path "." key, errors)
            } else {
                ValidateNode(val, spec[key], path "." key, errors)
            }
        }
        return
    }

    if (spec is Array) {
        if !(value is Array) {
            errors.Push(path " should be an array")
            return
        }
        if (spec.Length = 0)
            return
        item_spec := spec[1]
        for i, item in value {
            ValidateNode(item, item_spec, path "[" i "]", errors)
        }
        return
    }

    if (spec = "string") {
        if !(value is String)
            errors.Push(path " should be a string")
        return
    }

    if (spec = "number") {
        if !IsNumber(value)
            errors.Push(path " should be a number")
        return
    }

    if (spec = "integer") {
        if !IsInteger(value)
            errors.Push(path " should be an integer")
        return
    }

    if (spec = "bool") {
        if !IsBooleanValue(value)
            errors.Push(path " should be a boolean")
        return
    }
}


OptionalSpec(spec) {
    return Map(
        "__optional__", true,
        "spec", spec
    )
}

IsBooleanValue(value) {
    if (value is Integer)
        return (value = 0 || value = 1)
    return (value = true || value = false)
}

DeepMergeMaps(base_map, override_map) {
    if !(override_map is Map)
        return base_map

    for key, val in override_map {
        if (val is Array) {
            base_map[key] := val
            continue
        }
        if base_map.Has(key) && (base_map[key] is Map) && (val is Map) {
            base_map[key] := DeepMergeMaps(base_map[key], val)
        } else {
            base_map[key] := val
        }
    }
    return base_map
}

CloneMap(source) {
    if !(source is Map)
        return source

    clone := Map()
    for key, val in source {
        if (val is Map)
            clone[key] := CloneMap(val)
        else if (val is Array)
            clone[key] := CloneArray(val)
        else
            clone[key] := val
    }
    return clone
}

CloneArray(source) {
    if !(source is Array)
        return source

    clone := []
    for _, val in source {
        if (val is Map)
            clone.Push(CloneMap(val))
        else if (val is Array)
            clone.Push(CloneArray(val))
        else
            clone.Push(val)
    }
    return clone
}

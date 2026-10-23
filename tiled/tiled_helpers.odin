package tiled

import json "core:encoding/json"
import fmt "core:fmt"

// This file includes optional helper procedures for parsing Tiled map data. This file was not included in the original tiled package.

// Returns the tileset and its index associated with a gid.
// The index is useful if storing a slice of textures that corresponds to each tileset.
get_tileset_from_gid :: proc(tilesets: []Tileset, gid: i32) -> (tileset: ^Tileset, index: int) {
	if len(tilesets) == 1 {
		return &tilesets[0], 0
	} else {
		gid := gid & 0x0FFFFFFF
		for &ts, idx in tilesets {
			if gid >= ts.first_gid && gid < ts.first_gid + ts.tile_count {
				return &ts, idx
			}
		}
	}
	return nil, 0
}

Flip :: enum {
	flip_horizontal,
	flip_vertical,
	flip_diagonal,
}
FlippingFlags :: bit_set[Flip]

Flip_Hex :: enum {
	flip_horizontal,
	flip_vertical,
	rotate_60,
	rotate_120,
}
FlippingFlags_Hex :: bit_set[Flip_Hex]

strip_flags :: proc(gid: i32) -> (i32, FlippingFlags) {
	ugid := cast(u32)gid
	flags := ugid & 0xF0000000
	cleared_gid := ugid & 0x0FFFFFFF

	flip_flags: FlippingFlags

	if flags & 0x80000000 != 0 do flip_flags += {.flip_horizontal}
	if flags & 0x40000000 != 0 do flip_flags += {.flip_vertical}
	if flags & 0x20000000 != 0 do flip_flags += {.flip_diagonal}

	return i32(cleared_gid), flip_flags
}

strip_flags_hex :: proc(gid: i32) -> (i32, FlippingFlags_Hex) {
	ugid := cast(u32)gid
	flags := ugid & 0xF0000000
	cleared_gid := ugid & 0x0FFFFFFF

	flip_flags: FlippingFlags_Hex

	if flags & 0x80000000 != 0 do flip_flags += {.flip_horizontal}
	if flags & 0x40000000 != 0 do flip_flags += {.flip_vertical}
	if flags & 0x20000000 != 0 do flip_flags += {.rotate_60}
	if flags & 0x10000000 != 0 do flip_flags += {.rotate_120}

	return i32(cleared_gid), flip_flags
}

get_layer_by_name :: proc(name: string, t_map: Map) -> (Layer, bool) {
	for layer in t_map.layers {
		if layer.name == name do return layer, true
	}
	return {}, false
}

get_layer_pointer_by_name :: proc(name: string, t_map: Map) -> (^Layer, bool) {
	for &layer in t_map.layers {
		if layer.name == name do return &layer, true
	}
	return nil, false
}

get_object_by_id :: proc(id: i32, t_map: Map) -> (Object, bool) {
	if id <= 0 do return {}, false
	for layer in t_map.layers do for obj in layer.objects {
		if obj.id == id do return obj, true
	}
	return {}, false
}

get_object_pointer_by_id :: proc(id: i32, t_map: Map) -> (^Object, bool) {
	if id <= 0 do return nil, false
	for layer in t_map.layers do for &obj in layer.objects {
		if obj.id == id do return &obj, true
	}
	return nil, false
}

get_property_by_name :: proc(name: string, properties: []Property) -> (Property, bool) {
	for prop in properties {
		if name == prop.name do return prop, true
	}
	return {}, false
}

get_bool_property :: proc(property: PropertyData) -> bool {
	#partial switch data in property {
	case bool:
		return data
	// case string:
	case:
		panic("Data can't be parsed as a boolean!")
	}
}

// this is needed because Tiled will save whole numbers without a trailing ".0,"
// and the value will be parsed in the order of the PropertyData union, returning the first match (i32 in the case of a whole number).
// see: https://github.com/odin-lang/Odin/blob/master/core/encoding/json/unmarshal.odin#L266-L292
get_float_property :: proc(property: PropertyData) -> f32 {
	#partial switch data in property {
	case f32:
		return data
	case i32:
		return cast(f32)data
	case:
		panic("Data can't be parsed as a float!")
	}
}

//shouldn't be needed unless PropertyData order is changed, added for completeness
get_int_property :: proc(property: PropertyData) -> i32 {
	#partial switch data in property {
	case i32:
		return data
	case f32:
		return cast(i32)data
	case:
		panic("Data can't be parsed as an integer!")
	}
}

//return enum from string or integer value
get_enum_property :: proc(property: PropertyData, $T: typeid) -> T {
	#partial switch data in property {
	case i32:
		if data >= 0 && data < len(T) {
			return cast(T)data
		} else do panic("Integer value outside range of enum")
	case string:
		if strenum, ok := fmt.string_to_enum_value(T, data); ok {
			return strenum
		} else do panic(fmt.tprintf("String '%v' not found in enum!", property))
	case:
		panic("Data can't be parsed as provided type!")
	}
}

//try to return enum from string or integer value, won't panic.
try_get_enum_property :: proc(property: PropertyData, $T: typeid) -> (T, bool) {
	#partial switch data in property {
	case i32:
		if data >= 0 && data < len(T) {
			return cast(T)data, true
		} else {
			fmt.printfln("JSON PARSE WARNING: Integer '%v' value outside range of enum", data)
			return {}, false
		}
	case string:
		if strenum, ok := fmt.string_to_enum_value(T, data); ok {
			return strenum, true
		} else {
			fmt.printfln("JSON PARSE WARNING: String '%v' not found in enum!", property)
			return {}, false
		}
	case:
		fmt.printfln("JSON PARSE WARNING: Enum can't be parse from provided type")
		return {}, false
	}
}


// shouldn't be needed, added for completeness
get_string_property :: proc(property: PropertyData) -> string {
	#partial switch data in property {
	case string:
		return data
	case:
		panic("Data can't be parsed as string!")
	}
}

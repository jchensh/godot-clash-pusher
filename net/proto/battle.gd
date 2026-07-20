#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2026, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	extends RefCounted
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	extends RefCounted
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	extends RefCounted
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && (varint[8] & 0x80 != 0):
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		if data_type == PB_DATA_TYPE.FLOAT:
			return bytes.decode_float(index)
		elif data_type == PB_DATA_TYPE.DOUBLE:
			return bytes.decode_double(index)
		elif data_type == PB_DATA_TYPE.FIXED32:
			return bytes.decode_u32(index)
		elif data_type == PB_DATA_TYPE.SFIXED32:
			return bytes.decode_s32(index)
		elif data_type == PB_DATA_TYPE.FIXED64:
			return bytes.decode_u64(index)
		elif data_type == PB_DATA_TYPE.SFIXED64:
			return bytes.decode_s64(index)
		else:
			var value : int = 0
			for i in range(count):
				value |= bytes[index + i] << (8 * i)
			return value

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		var i: int = varint_bytes.size() - 1
		while i > -1:
			value = (value << 7) | (varint_bytes[i] & 0x7F)
			i -= 1
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var i: int = index
		while i <= index + 10 && i < bytes.size(): # Protobuf varint max size is 10 bytes
			if !(bytes[i] & 0x80):
				return bytes.slice(index, i + 1)
			i += 1
		return [] # Unreachable

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func skip_unknown_field(bytes : PackedByteArray, offset : int, type : int) -> int:
		if type == PB_TYPE.VARINT:
			return offset + isolate_varint(bytes, offset).size()
		if type == PB_TYPE.FIX64:
			return offset + 8
		if type == PB_TYPE.LENGTHDEL:
			var length_bytes : PackedByteArray = isolate_varint(bytes, offset)
			var length : int = unpack_varint(length_bytes)
			return offset + length_bytes.size() + length
		if type == PB_TYPE.FIX32:
			return offset + 4
		return PB_ERR.UNDEFINED_STATE

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
				else:
					var res : int = skip_unknown_field(bytes, offset, tt.type)
					if res > 0:
						offset = res
						if offset == limit:
							return offset
						elif offset > limit:
							return PB_ERR.PACKAGE_SIZE_MISMATCH
					elif res < 0:
						return res
					else:
						break							
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


class JoinRoomReq:
	extends RefCounted
	func _init():
		var service
		
		__room_id = PBField.new("room_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __room_id
		data[__room_id.tag] = service
		
		var __deck_default: Array[String] = []
		__deck = PBField.new("deck", PB_DATA_TYPE.STRING, PB_RULE.REPEATED, 2, true, __deck_default)
		service = PBServiceField.new()
		service.field = __deck
		data[__deck.tag] = service
		
	var data = {}
	
	var __room_id: PBField
	func has_room_id() -> bool:
		if __room_id.value != null:
			return true
		return false
	func get_room_id() -> String:
		return __room_id.value
	func clear_room_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__room_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_room_id(value : String) -> void:
		__room_id.value = value
	
	var __deck: PBField
	func get_deck() -> Array[String]:
		return __deck.value
	func clear_deck() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__deck.value.clear()
	func add_deck(value : String) -> void:
		__deck.value.append(value)
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class CardProgress:
	extends RefCounted
	func _init():
		var service
		
		__card_id = PBField.new("card_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __card_id
		data[__card_id.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__rank = PBField.new("rank", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __rank
		data[__rank.tag] = service
		
	var data = {}
	
	var __card_id: PBField
	func has_card_id() -> bool:
		if __card_id.value != null:
			return true
		return false
	func get_card_id() -> String:
		return __card_id.value
	func clear_card_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__card_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_card_id(value : String) -> void:
		__card_id.value = value
	
	var __level: PBField
	func has_level() -> bool:
		if __level.value != null:
			return true
		return false
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __rank: PBField
	func has_rank() -> bool:
		if __rank.value != null:
			return true
		return false
	func get_rank() -> int:
		return __rank.value
	func clear_rank() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__rank.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_rank(value : int) -> void:
		__rank.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class TowerBonus:
	extends RefCounted
	func _init():
		var service
		
		__hp_pct = PBField.new("hp_pct", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __hp_pct
		data[__hp_pct.tag] = service
		
		__dmg_pct = PBField.new("dmg_pct", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __dmg_pct
		data[__dmg_pct.tag] = service
		
	var data = {}
	
	var __hp_pct: PBField
	func has_hp_pct() -> bool:
		if __hp_pct.value != null:
			return true
		return false
	func get_hp_pct() -> int:
		return __hp_pct.value
	func clear_hp_pct() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__hp_pct.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_hp_pct(value : int) -> void:
		__hp_pct.value = value
	
	var __dmg_pct: PBField
	func has_dmg_pct() -> bool:
		if __dmg_pct.value != null:
			return true
		return false
	func get_dmg_pct() -> int:
		return __dmg_pct.value
	func clear_dmg_pct() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__dmg_pct.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_dmg_pct(value : int) -> void:
		__dmg_pct.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class JoinRoomResp:
	extends RefCounted
	func _init():
		var service
		
		__ok = PBField.new("ok", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __ok
		data[__ok.tag] = service
		
		__opponent = PBField.new("opponent", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __opponent
		service.func_ref = Callable(self, "new_opponent")
		data[__opponent.tag] = service
		
		__your_side = PBField.new("your_side", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __your_side
		data[__your_side.tag] = service
		
		__start_tick = PBField.new("start_tick", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __start_tick
		data[__start_tick.tag] = service
		
		__seed = PBField.new("seed", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __seed
		data[__seed.tag] = service
		
		var __side1_deck_default: Array[String] = []
		__side1_deck = PBField.new("side1_deck", PB_DATA_TYPE.STRING, PB_RULE.REPEATED, 6, true, __side1_deck_default)
		service = PBServiceField.new()
		service.field = __side1_deck
		data[__side1_deck.tag] = service
		
		var __side2_deck_default: Array[String] = []
		__side2_deck = PBField.new("side2_deck", PB_DATA_TYPE.STRING, PB_RULE.REPEATED, 7, true, __side2_deck_default)
		service = PBServiceField.new()
		service.field = __side2_deck
		data[__side2_deck.tag] = service
		
		__level_id = PBField.new("level_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __level_id
		data[__level_id.tag] = service
		
		var __side1_progress_default: Array[CardProgress] = []
		__side1_progress = PBField.new("side1_progress", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 9, true, __side1_progress_default)
		service = PBServiceField.new()
		service.field = __side1_progress
		service.func_ref = Callable(self, "add_side1_progress")
		data[__side1_progress.tag] = service
		
		var __side2_progress_default: Array[CardProgress] = []
		__side2_progress = PBField.new("side2_progress", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 10, true, __side2_progress_default)
		service = PBServiceField.new()
		service.field = __side2_progress
		service.func_ref = Callable(self, "add_side2_progress")
		data[__side2_progress.tag] = service
		
		__side1_towers = PBField.new("side1_towers", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __side1_towers
		service.func_ref = Callable(self, "new_side1_towers")
		data[__side1_towers.tag] = service
		
		__side2_towers = PBField.new("side2_towers", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __side2_towers
		service.func_ref = Callable(self, "new_side2_towers")
		data[__side2_towers.tag] = service
		
	var data = {}
	
	var __ok: PBField
	func has_ok() -> bool:
		if __ok.value != null:
			return true
		return false
	func get_ok() -> bool:
		return __ok.value
	func clear_ok() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ok.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_ok(value : bool) -> void:
		__ok.value = value
	
	var __opponent: PBField
	func has_opponent() -> bool:
		if __opponent.value != null:
			return true
		return false
	func get_opponent() -> ProfileSummary:
		return __opponent.value
	func clear_opponent() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__opponent.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_opponent() -> ProfileSummary:
		__opponent.value = ProfileSummary.new()
		return __opponent.value
	
	var __your_side: PBField
	func has_your_side() -> bool:
		if __your_side.value != null:
			return true
		return false
	func get_your_side() -> int:
		return __your_side.value
	func clear_your_side() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__your_side.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_your_side(value : int) -> void:
		__your_side.value = value
	
	var __start_tick: PBField
	func has_start_tick() -> bool:
		if __start_tick.value != null:
			return true
		return false
	func get_start_tick() -> int:
		return __start_tick.value
	func clear_start_tick() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__start_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_start_tick(value : int) -> void:
		__start_tick.value = value
	
	var __seed: PBField
	func has_seed() -> bool:
		if __seed.value != null:
			return true
		return false
	func get_seed() -> int:
		return __seed.value
	func clear_seed() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__seed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_seed(value : int) -> void:
		__seed.value = value
	
	var __side1_deck: PBField
	func get_side1_deck() -> Array[String]:
		return __side1_deck.value
	func clear_side1_deck() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__side1_deck.value.clear()
	func add_side1_deck(value : String) -> void:
		__side1_deck.value.append(value)
	
	var __side2_deck: PBField
	func get_side2_deck() -> Array[String]:
		return __side2_deck.value
	func clear_side2_deck() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__side2_deck.value.clear()
	func add_side2_deck(value : String) -> void:
		__side2_deck.value.append(value)
	
	var __level_id: PBField
	func has_level_id() -> bool:
		if __level_id.value != null:
			return true
		return false
	func get_level_id() -> String:
		return __level_id.value
	func clear_level_id() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__level_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_level_id(value : String) -> void:
		__level_id.value = value
	
	var __side1_progress: PBField
	func get_side1_progress() -> Array[CardProgress]:
		return __side1_progress.value
	func clear_side1_progress() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__side1_progress.value.clear()
	func add_side1_progress() -> CardProgress:
		var element = CardProgress.new()
		__side1_progress.value.append(element)
		return element
	
	var __side2_progress: PBField
	func get_side2_progress() -> Array[CardProgress]:
		return __side2_progress.value
	func clear_side2_progress() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__side2_progress.value.clear()
	func add_side2_progress() -> CardProgress:
		var element = CardProgress.new()
		__side2_progress.value.append(element)
		return element
	
	var __side1_towers: PBField
	func has_side1_towers() -> bool:
		if __side1_towers.value != null:
			return true
		return false
	func get_side1_towers() -> TowerBonus:
		return __side1_towers.value
	func clear_side1_towers() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__side1_towers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_side1_towers() -> TowerBonus:
		__side1_towers.value = TowerBonus.new()
		return __side1_towers.value
	
	var __side2_towers: PBField
	func has_side2_towers() -> bool:
		if __side2_towers.value != null:
			return true
		return false
	func get_side2_towers() -> TowerBonus:
		return __side2_towers.value
	func clear_side2_towers() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__side2_towers.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_side2_towers() -> TowerBonus:
		__side2_towers.value = TowerBonus.new()
		return __side2_towers.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DeployCmd:
	extends RefCounted
	func _init():
		var service
		
		__tick = PBField.new("tick", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __tick
		data[__tick.tag] = service
		
		__card_id = PBField.new("card_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __card_id
		data[__card_id.tag] = service
		
		__x_milli = PBField.new("x_milli", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __x_milli
		data[__x_milli.tag] = service
		
		__y_milli = PBField.new("y_milli", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __y_milli
		data[__y_milli.tag] = service
		
	var data = {}
	
	var __tick: PBField
	func has_tick() -> bool:
		if __tick.value != null:
			return true
		return false
	func get_tick() -> int:
		return __tick.value
	func clear_tick() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_tick(value : int) -> void:
		__tick.value = value
	
	var __card_id: PBField
	func has_card_id() -> bool:
		if __card_id.value != null:
			return true
		return false
	func get_card_id() -> String:
		return __card_id.value
	func clear_card_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__card_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_card_id(value : String) -> void:
		__card_id.value = value
	
	var __x_milli: PBField
	func has_x_milli() -> bool:
		if __x_milli.value != null:
			return true
		return false
	func get_x_milli() -> int:
		return __x_milli.value
	func clear_x_milli() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__x_milli.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_x_milli(value : int) -> void:
		__x_milli.value = value
	
	var __y_milli: PBField
	func has_y_milli() -> bool:
		if __y_milli.value != null:
			return true
		return false
	func get_y_milli() -> int:
		return __y_milli.value
	func clear_y_milli() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__y_milli.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_y_milli(value : int) -> void:
		__y_milli.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class TickBundle:
	extends RefCounted
	func _init():
		var service
		
		__tick = PBField.new("tick", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __tick
		data[__tick.tag] = service
		
		var __deploys_default: Array[TickBundle.SideDeploy] = []
		__deploys = PBField.new("deploys", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __deploys_default)
		service = PBServiceField.new()
		service.field = __deploys
		service.func_ref = Callable(self, "add_deploys")
		data[__deploys.tag] = service
		
	var data = {}
	
	var __tick: PBField
	func has_tick() -> bool:
		if __tick.value != null:
			return true
		return false
	func get_tick() -> int:
		return __tick.value
	func clear_tick() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_tick(value : int) -> void:
		__tick.value = value
	
	var __deploys: PBField
	func get_deploys() -> Array[TickBundle.SideDeploy]:
		return __deploys.value
	func clear_deploys() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__deploys.value.clear()
	func add_deploys() -> TickBundle.SideDeploy:
		var element = TickBundle.SideDeploy.new()
		__deploys.value.append(element)
		return element
	
	class SideDeploy:
		extends RefCounted
		func _init():
			var service
			
			__side = PBField.new("side", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
			service = PBServiceField.new()
			service.field = __side
			data[__side.tag] = service
			
			__deploy = PBField.new("deploy", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
			service = PBServiceField.new()
			service.field = __deploy
			service.func_ref = Callable(self, "new_deploy")
			data[__deploy.tag] = service
			
		var data = {}
		
		var __side: PBField
		func has_side() -> bool:
			if __side.value != null:
				return true
			return false
		func get_side() -> int:
			return __side.value
		func clear_side() -> void:
			data[1].state = PB_SERVICE_STATE.UNFILLED
			__side.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
		func set_side(value : int) -> void:
			__side.value = value
		
		var __deploy: PBField
		func has_deploy() -> bool:
			if __deploy.value != null:
				return true
			return false
		func get_deploy() -> DeployCmd:
			return __deploy.value
		func clear_deploy() -> void:
			data[2].state = PB_SERVICE_STATE.UNFILLED
			__deploy.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		func new_deploy() -> DeployCmd:
			__deploy.value = DeployCmd.new()
			return __deploy.value
		
		func _to_string() -> String:
			return PBPacker.message_to_string(data)
			
		func to_bytes() -> PackedByteArray:
			return PBPacker.pack_message(data)
			
		func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
			var cur_limit = bytes.size()
			if limit != -1:
				cur_limit = limit
			var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
			if result == cur_limit:
				if PBPacker.check_required(data):
					if limit == -1:
						return PB_ERR.NO_ERRORS
				else:
					return PB_ERR.REQUIRED_FIELDS
			elif limit == -1 && result > 0:
				return PB_ERR.PARSE_INCOMPLETE
			return result
		
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class StateHashUp:
	extends RefCounted
	func _init():
		var service
		
		__tick = PBField.new("tick", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __tick
		data[__tick.tag] = service
		
		__hash = PBField.new("hash", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = __hash
		data[__hash.tag] = service
		
	var data = {}
	
	var __tick: PBField
	func has_tick() -> bool:
		if __tick.value != null:
			return true
		return false
	func get_tick() -> int:
		return __tick.value
	func clear_tick() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_tick(value : int) -> void:
		__tick.value = value
	
	var __hash: PBField
	func has_hash() -> bool:
		if __hash.value != null:
			return true
		return false
	func get_hash() -> PackedByteArray:
		return __hash.value
	func clear_hash() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__hash.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_hash(value : PackedByteArray) -> void:
		__hash.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class BattleEndReport:
	extends RefCounted
	func _init():
		var service
		
		__tick = PBField.new("tick", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __tick
		data[__tick.tag] = service
		
		__winner = PBField.new("winner", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __winner
		data[__winner.tag] = service
		
		__reason = PBField.new("reason", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __reason
		data[__reason.tag] = service
		
		__side_1_score = PBField.new("side_1_score", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __side_1_score
		data[__side_1_score.tag] = service
		
		__side_2_score = PBField.new("side_2_score", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __side_2_score
		data[__side_2_score.tag] = service
		
	var data = {}
	
	var __tick: PBField
	func has_tick() -> bool:
		if __tick.value != null:
			return true
		return false
	func get_tick() -> int:
		return __tick.value
	func clear_tick() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_tick(value : int) -> void:
		__tick.value = value
	
	var __winner: PBField
	func has_winner() -> bool:
		if __winner.value != null:
			return true
		return false
	func get_winner() -> int:
		return __winner.value
	func clear_winner() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__winner.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_winner(value : int) -> void:
		__winner.value = value
	
	var __reason: PBField
	func has_reason() -> bool:
		if __reason.value != null:
			return true
		return false
	func get_reason() -> int:
		return __reason.value
	func clear_reason() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_reason(value : int) -> void:
		__reason.value = value
	
	var __side_1_score: PBField
	func has_side_1_score() -> bool:
		if __side_1_score.value != null:
			return true
		return false
	func get_side_1_score() -> int:
		return __side_1_score.value
	func clear_side_1_score() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__side_1_score.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_side_1_score(value : int) -> void:
		__side_1_score.value = value
	
	var __side_2_score: PBField
	func has_side_2_score() -> bool:
		if __side_2_score.value != null:
			return true
		return false
	func get_side_2_score() -> int:
		return __side_2_score.value
	func clear_side_2_score() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__side_2_score.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_side_2_score(value : int) -> void:
		__side_2_score.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class BattleResultPush:
	extends RefCounted
	func _init():
		var service
		
		__winner = PBField.new("winner", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __winner
		data[__winner.tag] = service
		
		__reason = PBField.new("reason", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __reason
		data[__reason.tag] = service
		
		__side_1_score = PBField.new("side_1_score", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __side_1_score
		data[__side_1_score.tag] = service
		
		__side_2_score = PBField.new("side_2_score", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __side_2_score
		data[__side_2_score.tag] = service
		
		__trophies_delta_side_1 = PBField.new("trophies_delta_side_1", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __trophies_delta_side_1
		data[__trophies_delta_side_1.tag] = service
		
		__trophies_delta_side_2 = PBField.new("trophies_delta_side_2", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __trophies_delta_side_2
		data[__trophies_delta_side_2.tag] = service
		
	var data = {}
	
	var __winner: PBField
	func has_winner() -> bool:
		if __winner.value != null:
			return true
		return false
	func get_winner():
		return __winner.value
	func clear_winner() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__winner.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_winner(value) -> void:
		__winner.value = value
	
	var __reason: PBField
	func has_reason() -> bool:
		if __reason.value != null:
			return true
		return false
	func get_reason():
		return __reason.value
	func clear_reason() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_reason(value) -> void:
		__reason.value = value
	
	var __side_1_score: PBField
	func has_side_1_score() -> bool:
		if __side_1_score.value != null:
			return true
		return false
	func get_side_1_score() -> int:
		return __side_1_score.value
	func clear_side_1_score() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__side_1_score.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_side_1_score(value : int) -> void:
		__side_1_score.value = value
	
	var __side_2_score: PBField
	func has_side_2_score() -> bool:
		if __side_2_score.value != null:
			return true
		return false
	func get_side_2_score() -> int:
		return __side_2_score.value
	func clear_side_2_score() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__side_2_score.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_side_2_score(value : int) -> void:
		__side_2_score.value = value
	
	var __trophies_delta_side_1: PBField
	func has_trophies_delta_side_1() -> bool:
		if __trophies_delta_side_1.value != null:
			return true
		return false
	func get_trophies_delta_side_1() -> int:
		return __trophies_delta_side_1.value
	func clear_trophies_delta_side_1() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__trophies_delta_side_1.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_trophies_delta_side_1(value : int) -> void:
		__trophies_delta_side_1.value = value
	
	var __trophies_delta_side_2: PBField
	func has_trophies_delta_side_2() -> bool:
		if __trophies_delta_side_2.value != null:
			return true
		return false
	func get_trophies_delta_side_2() -> int:
		return __trophies_delta_side_2.value
	func clear_trophies_delta_side_2() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__trophies_delta_side_2.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_trophies_delta_side_2(value : int) -> void:
		__trophies_delta_side_2.value = value
	
	enum Winner {
		DRAW = 0,
		SIDE_1 = 1,
		SIDE_2 = 2
	}
	
	enum Reason {
		REASON_UNKNOWN = 0,
		KING_DESTROYED = 1,
		TIMEOUT = 2,
		SURRENDER = 3,
		DISCONNECT = 4,
		HASH_DIVERGENCE = 5
	}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class HeartbeatPing:
	extends RefCounted
	func _init():
		var service
		
		__client_time = PBField.new("client_time", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __client_time
		data[__client_time.tag] = service
		
	var data = {}
	
	var __client_time: PBField
	func has_client_time() -> bool:
		if __client_time.value != null:
			return true
		return false
	func get_client_time() -> int:
		return __client_time.value
	func clear_client_time() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__client_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_client_time(value : int) -> void:
		__client_time.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class HeartbeatPong:
	extends RefCounted
	func _init():
		var service
		
		__server_time = PBField.new("server_time", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __server_time
		data[__server_time.tag] = service
		
	var data = {}
	
	var __server_time: PBField
	func has_server_time() -> bool:
		if __server_time.value != null:
			return true
		return false
	func get_server_time() -> int:
		return __server_time.value
	func clear_server_time() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__server_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_server_time(value : int) -> void:
		__server_time.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
enum MsgId {
	MSG_UNKNOWN = 0,
	PING = 1,
	PONG = 2,
	ERROR_RESP = 3,
	LOGIN_REQ = 10,
	LOGIN_RESP = 11,
	REFRESH_REQ = 12,
	REFRESH_RESP = 13,
	PROFILE_GET_REQ = 20,
	PROFILE_GET_RESP = 21,
	DECK_UPDATE_REQ = 22,
	DECK_UPDATE_RESP = 23,
	PROFILE_UPDATE_REQ = 24,
	PROFILE_UPDATE_RESP = 25,
	PROFILE_TUTORIAL_DONE_REQ = 26,
	FIND_MATCH_REQ = 30,
	FIND_MATCH_RESP = 31,
	CANCEL_MATCH_REQ = 32,
	CANCEL_MATCH_RESP = 33,
	MATCH_FOUND_PUSH = 34,
	JOIN_ROOM_REQ = 40,
	JOIN_ROOM_RESP = 41,
	DEPLOY_CMD = 42,
	TICK_BUNDLE = 43,
	STATE_HASH_UP = 44,
	BATTLE_RESULT_PUSH = 45,
	HEARTBEAT_PING = 46,
	HEARTBEAT_PONG = 47,
	BATTLE_END_REPORT = 48,
	LEADERBOARD_TOP_REQ = 50,
	LEADERBOARD_TOP_RESP = 51,
	CONFIG_PUSH = 60,
	ECONOMY_STATE_REQ = 61,
	ECONOMY_STATE_RESP = 62,
	ECONOMY_UPGRADE_REQ = 63,
	ECONOMY_RANK_UP_REQ = 64,
	ECONOMY_UNLOCK_REQ = 65,
	ECONOMY_STAGE_CLEAR_REQ = 66,
	ECONOMY_COLLECT_IDLE_REQ = 67,
	PVE_START_REQ = 68,
	PVE_REPORT_REQ = 69,
	KINGDOM_STATE_REQ = 70,
	KINGDOM_STATE_RESP = 71,
	KINGDOM_UPGRADE_REQ = 72,
	KINGDOM_COLLECT_REQ = 73,
	KINGDOM_SPEEDUP_REQ = 74
}

enum ErrorCode {
	ERR_OK = 0,
	ERR_INTERNAL = 1,
	ERR_INVALID_ARG = 2,
	ERR_UNAUTHORIZED = 3,
	ERR_RATE_LIMITED = 4,
	ERR_NOT_FOUND = 5,
	ERR_AUTH_INVALID_TOKEN = 100,
	ERR_AUTH_EXPIRED = 101,
	ERR_AUTH_BANNED = 102,
	ERR_PROFILE_VERSION_MISMATCH = 200,
	ERR_PROFILE_DECK_INVALID = 201,
	ERR_MATCH_ALREADY_QUEUED = 300,
	ERR_MATCH_NOT_QUEUED = 301,
	ERR_BATTLE_ROOM_NOT_FOUND = 400,
	ERR_BATTLE_INVALID_DEPLOY = 401,
	ERR_BATTLE_HASH_MISMATCH = 402,
	ERR_ECONOMY_INSUFFICIENT = 500,
	ERR_ECONOMY_AT_CAP = 501,
	ERR_ECONOMY_LOCKED = 502,
	ERR_ECONOMY_STAGE_LOCKED = 503,
	ERR_PVE_BATTLE_INVALID = 504
}

class ErrorResp:
	extends RefCounted
	func _init():
		var service
		
		__code = PBField.new("code", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __code
		data[__code.tag] = service
		
		__detail = PBField.new("detail", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __detail
		data[__detail.tag] = service
		
		__in_reply_to = PBField.new("in_reply_to", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __in_reply_to
		data[__in_reply_to.tag] = service
		
	var data = {}
	
	var __code: PBField
	func has_code() -> bool:
		if __code.value != null:
			return true
		return false
	func get_code():
		return __code.value
	func clear_code() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__code.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_code(value) -> void:
		__code.value = value
	
	var __detail: PBField
	func has_detail() -> bool:
		if __detail.value != null:
			return true
		return false
	func get_detail() -> String:
		return __detail.value
	func clear_detail() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__detail.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_detail(value : String) -> void:
		__detail.value = value
	
	var __in_reply_to: PBField
	func has_in_reply_to() -> bool:
		if __in_reply_to.value != null:
			return true
		return false
	func get_in_reply_to():
		return __in_reply_to.value
	func clear_in_reply_to() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__in_reply_to.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_in_reply_to(value) -> void:
		__in_reply_to.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ProfileSummary:
	extends RefCounted
	func _init():
		var service
		
		__account_id = PBField.new("account_id", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __account_id
		data[__account_id.tag] = service
		
		__nickname = PBField.new("nickname", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __nickname
		data[__nickname.tag] = service
		
		__avatar_id = PBField.new("avatar_id", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __avatar_id
		data[__avatar_id.tag] = service
		
		__level = PBField.new("level", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __level
		data[__level.tag] = service
		
		__trophies = PBField.new("trophies", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = __trophies
		data[__trophies.tag] = service
		
		__avatar_card_id = PBField.new("avatar_card_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __avatar_card_id
		data[__avatar_card_id.tag] = service
		
	var data = {}
	
	var __account_id: PBField
	func has_account_id() -> bool:
		if __account_id.value != null:
			return true
		return false
	func get_account_id() -> int:
		return __account_id.value
	func clear_account_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__account_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_account_id(value : int) -> void:
		__account_id.value = value
	
	var __nickname: PBField
	func has_nickname() -> bool:
		if __nickname.value != null:
			return true
		return false
	func get_nickname() -> String:
		return __nickname.value
	func clear_nickname() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__nickname.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_nickname(value : String) -> void:
		__nickname.value = value
	
	var __avatar_id: PBField
	func has_avatar_id() -> bool:
		if __avatar_id.value != null:
			return true
		return false
	func get_avatar_id() -> int:
		return __avatar_id.value
	func clear_avatar_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__avatar_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_avatar_id(value : int) -> void:
		__avatar_id.value = value
	
	var __level: PBField
	func has_level() -> bool:
		if __level.value != null:
			return true
		return false
	func get_level() -> int:
		return __level.value
	func clear_level() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__level.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level(value : int) -> void:
		__level.value = value
	
	var __trophies: PBField
	func has_trophies() -> bool:
		if __trophies.value != null:
			return true
		return false
	func get_trophies() -> int:
		return __trophies.value
	func clear_trophies() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__trophies.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_trophies(value : int) -> void:
		__trophies.value = value
	
	var __avatar_card_id: PBField
	func has_avatar_card_id() -> bool:
		if __avatar_card_id.value != null:
			return true
		return false
	func get_avatar_card_id() -> String:
		return __avatar_card_id.value
	func clear_avatar_card_id() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__avatar_card_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_avatar_card_id(value : String) -> void:
		__avatar_card_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################

extends RefCounted
class_name ExportHelper

enum BROTLI_POLICY {
	AUTO=0,
	FAST=1,
	SIZE=2
}
const BROTLI_POLICY_HIT_STRING:  = "Auto,Fast,Size"
static func export_pack(platform: EditorExportPlatform, preset: EditorExportPreset, debug: bool, export_pck_path: String, brotli_on: bool, brotli_policy: BROTLI_POLICY, report: ExportReport = null) -> Error:
	var res = platform.save_pack(preset, debug, export_pck_path);
	if res.result != Error.OK:
		return res.result
	for so in res.so_files:
		print("so_files: " + so.path + " [" + str(so.tags) + "] " + so.target_folder)

	var file_name = export_pck_path.get_file()
	
	var pack_bytes = FileAccess.get_file_as_bytes(export_pck_path)
	var export_bin_path = export_pck_path.substr(0, export_pck_path.length() - 4) + ".bin"
	var file_access_pack_bin = FileAccess.open(export_bin_path, FileAccess.WRITE)
	file_access_pack_bin.store_buffer(pack_bytes)
	file_access_pack_bin.close()
	if report != null:
		report.pack_file = export_bin_path
	
	var export_br_path = export_pck_path.substr(0, export_pck_path.length() - 4) + ".br"
	if brotli_on:
		if brotli_policy == BROTLI_POLICY.AUTO:
			brotli_policy = BROTLI_POLICY.FAST if debug else BROTLI_POLICY.SIZE
		
		Brotli.compress_file(export_bin_path, export_br_path, 5 if brotli_policy == BROTLI_POLICY.FAST else 9)
		DirAccess.remove_absolute(export_bin_path)
		if report != null:
			report.pack_file = export_br_path
	else:
		if FileAccess.file_exists(export_br_path):
			DirAccess.remove_absolute(export_br_path)
	return Error.OK
	
	



static func download_file_text(url: String, save_file_path: String) -> Error:
	var parsed = _parse_url(url)
	var recv = PackedByteArray()
	var err = tls_get_sync(parsed.host, parsed.path, {}, recv)
	if err != OK:
		printerr(get_http_error())
		return err
	var text = recv.get_string_from_utf8()
	if text.length() == 0:
		return Error.FAILED
	var fa = FileAccess.open(save_file_path, FileAccess.WRITE)
	fa.store_string(text)
	fa.close()
	return Error.OK

static func download_file(url: String, save_file_path: String) -> Error:
	var parsed = _parse_url(url)
	var recv := PackedByteArray()
	var err = tls_get_sync(parsed.host, parsed.path, {}, recv)
	if err != OK:
		printerr(get_http_error())
		return err
	if recv.size() == 0:
		return Error.FAILED
	var fa = FileAccess.open(save_file_path, FileAccess.WRITE)
	fa.store_buffer(recv)
	fa.close()
	return Error.OK


static var _http_error: String;

static func get_http_error()-> String:
	return _http_error;

static func tls_get_sync(host: String, path: String, query: Dictionary, recv: PackedByteArray) -> Error:
	_http_error = ""
	var http = HTTPClient.new()
	var err = http.connect_to_host(host, 443, TLSOptions.client())
	if err != OK:
		_http_error = "connect_to_host failed"
		return err
	
	var start = Time.get_ticks_msec()
	# Wait until resolved and connected.
	while Time.get_ticks_msec() - start < 3000 && http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(10)
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		_http_error = "http status error: " + str(http.get_status())
		return Error.FAILED

	if query.size() > 0:
		path = "%s?%s" % [path, http.query_string_from_dict(query)]
	err = http.request(HTTPClient.METHOD_GET, path, []) # Request a page from the site (this one was chunked..)
	if err != OK:
		_http_error = "http request failed"
		return err;

	while Time.get_ticks_msec() - start < 3000 && http.get_status() == HTTPClient.STATUS_REQUESTING:
		# Keep polling for as long as the request is being processed.
		http.poll()
		OS.delay_msec(10)
	if http.get_status() == HTTPClient.STATUS_REQUESTING:
		_http_error = "http request timeout"
		return Error.ERR_TIMEOUT;
		
	assert(http.has_response())

	var rb = PackedByteArray()
	if http.has_response():
		 # Array that will hold the data.
		while Time.get_ticks_msec() - start < 3000 && http.get_status() == HTTPClient.STATUS_BODY:
			# While there is body left to be read
			http.poll()
			# Get a chunk.
			var chunk = http.read_response_body_chunk()
			if chunk.size() == 0:
				OS.delay_msec(10)
			else:
				rb = rb + chunk # Append to read buffer.
		if http.get_status() == HTTPClient.STATUS_BODY:
			_http_error = "http response timeout"
			return Error.ERR_TIMEOUT;

	http.close()
	recv.clear()
	recv.append_array(rb)
	return OK
	
static func _parse_url(url: String) -> Dictionary:
	var result := {
		"scheme": "",
		"host": "",
		"port": -1,
		"path": "",
		"query": "",
		"fragment": ""
	}

	var work := url.strip_edges()

	# 1) scheme
	var scheme_split := work.split("://", false, 1)
	if scheme_split.size() == 2:
		result.scheme = scheme_split[0]
		work = scheme_split[1]
	else:
		work = scheme_split[0]  # no scheme

	# 2) fragment (#xxx)
	var frag_idx := work.find("#")
	if frag_idx != -1:
		result.fragment = work.substr(frag_idx + 1)
		work = work.substr(0, frag_idx)

	# 3) query (?xxx)
	var query_idx := work.find("?")
	if query_idx != -1:
		result.query = work.substr(query_idx + 1)
		work = work.substr(0, query_idx)

	# 4) host + optional port + path
	# find first slash (path start)
	var slash_idx := work.find("/")
	var host_port := ""
	if slash_idx != -1:
		host_port = work.substr(0, slash_idx)
		result.path = work.substr(slash_idx)  # keep leading "/"
	else:
		host_port = work
		result.path = "/"

	# 5) host:port
	var colon_idx := host_port.find(":")
	if colon_idx != -1:
		result.host = host_port.substr(0, colon_idx)
		var port_str := host_port.substr(colon_idx + 1)
		result.port = int(port_str)
	else:
		result.host = host_port
		result.port = -1  # unspecified

	return result

// Feather disable all

/// @param {String} fname
/// @param {Struct} struct
function __gltfSaveStructToFile(fname, struct, encode=false) { //Not used, consider removing
	var buffer = buffer_create(1024, buffer_grow, 1);
	if (encode) {
		buffer_write(buffer, buffer_string, base64_encode(json_stringify(struct)));
	}
	else {
		buffer_write(buffer, buffer_string, json_stringify(struct));
	}
	buffer_save(buffer, fname);
	buffer_delete(buffer);
}

/// @param {String} fname
/// @return {Struct}
function __gltfLoadStructFromFile(fname, decode=false) {
	if (file_exists(fname)) {
		var f = buffer_load(fname);
		var json = buffer_read(f, buffer_string);
		if (decode) json = base64_decode(json);
		buffer_delete(f);
		
		return json_parse(json);
	}
	show_error("file not found: "+fname, true);
	return { };
}

function __gltfSprites__() {
	static spr = { };
	return spr;
}
function __gltfTextures__() {
	static tex = { };
	return tex;
}

function __load_texture(fname) {
	var spr = sprite_add(fname, 0, false, false, 0, 0);
	var tex = sprite_get_texture(spr, 0);
	__gltfSprites__()[$ fname] = spr;
	__gltfTextures__()[$ fname] = tex;
	return tex;
}

function __gltfGetTexture(fname) {
	return __gltfTextures__()[$ "fname"] ?? __load_texture(fname);
}

function __gltfClearLoadedTextures() {
	var sprites = __gltfSprites__();
	var textures = __gltfTextures__();
	var names = variable_struct_get_names(sprites);
	var i = 0; repeat(array_length(names)) {
		var name = names[i++];
		var sprite = sprites[$ name];
		if (!is_undefined(sprite) && sprite_exists(sprite)) {
			sprite_delete(sprite);
		}
		__gltfDebugPrint("removing texture: {0}", [ name ]);
		variable_struct_remove(sprites, name);
		variable_struct_remove(textures, name);
	}
}

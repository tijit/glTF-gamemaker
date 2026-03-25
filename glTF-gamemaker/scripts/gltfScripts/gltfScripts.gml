/// Feather disable all

/// load meshes and skins from the given filename
/// @param {string} fname file name
function gltfLoad(fname) {
	static results = { };
	// dont load the same file twice
	if (!is_undefined(results[$ fname])) {
		return results[$ fname];
	}
	
	var dat = __gltfLoadStructFromFile(fname);
	
	// returned struct which stores the names of all meshes and skinnedMeshes
	var result = {
		skinnedMeshes : [ ],
		meshes : [ ],
	};
	
	results[$ fname] = result;
	
	var buffers = [ ];
	
	// for each buffer
		// skip header info and put into a gamemaker Buffer for reading
	
	for (var i = 0; i < array_length(dat.buffers); i++) {
		buffers[i] = -1;
		var uri = dat.buffers[i].uri;
		if (string_starts_with(uri, "data:")) {
			uri = string_delete(uri, 1, string_pos(",", uri));
			buffers[i] = buffer_base64_decode(uri);
		}
	}
	
	var nodes = dat.nodes;
	
	/*		accessing animation samplers
	
		animations[]
			channels[]
				sampler : SAMPLER ID
				target{}
					node : IND (bone index)
					path : TYPE (eg "rotation", "translation")
			name : ARMATURE_NAME
			samplers[]
				input : ACCESSOR ID
				interpolation : TYPE ("STEP", "LINEAR", or "CUBICSPLINE")
				output : ACCESSOR ID
				
	*/
	
	// iterate over animation data FIRST
	// so i can add it to bones as i go instead of reverse lookup bullshit
	var boneAnimationData = array_create(array_length(nodes), undefined);
	var animations = dat[$ "animations"];
	if (!is_undefined(animations)) {
		for (var i = 0; i < array_length(animations); i++) {
			var channels = animations[i][$ "channels"];
			var name = animations[i].name;
			
			__gltfDebugPrint("animation {0} name is {1}!", [ i, name ?? "missing" ]);
			
			for (var j = 0; j < array_length(channels); j++) {
				var c = channels[j];
				var type = c.target.path;
				var nodeID = c.target.node;
				var samplerID = c.sampler;
				var sampler = animations[i].samplers[samplerID];
				
				var sInput = sampler.input;
				var sOutput = sampler.output;
				var sInterp = sampler[$ "interpolation"];
				
				var bAnim = {
					in : __gltfAccessBuffer(sInput, dat, buffers), // keyframe
					out : __gltfAccessBuffer(sOutput, dat, buffers), // transform information
					interp : sInterp,
				};
				
				boneAnimationData[nodeID] = boneAnimationData[nodeID] ?? { };
				boneAnimationData[nodeID][$ name] = boneAnimationData[nodeID][$ name] ?? { };
				// [nodeID]			[name]				[type]
				// ->
				// [bone index]		[animation name]	[channel/type (T R or S)]
				boneAnimationData[nodeID][$ name][$ type] = bAnim;
			}
		}
	}
	
	for (var i = 0; i < array_length(nodes); i++) {
		var node = nodes[i];
		var meshID = node[$ "mesh"];
		if (!is_undefined(meshID)) {
			var skinID = node[$ "skin"];
			if (is_undefined(skinID)) {
				// load mesh
				__gltfLoadMesh(dat, buffers, meshID);
				// store name for returning
				array_push(result.meshes, dat.meshes[meshID].name);
			}
			else {
				// load skinned mesh
				__gltfLoadMesh(dat, buffers, meshID, skinID, boneAnimationData);
				// store name for returning
				array_push(result.skinnedMeshes, dat.skins[skinID].name);
			}
		}
	}
	
	
	
	// clear all buffers
	for (var i = 0; i < array_length(buffers); i++) {
		if (buffers[i] > -1) buffer_delete(buffers[i]);
	}
	
	return result;
	//return dat;
}

/// get vertex buffer of [index]th primitive of mesh
function gltfGetMesh(name, index=0) {
	return __gltfMeshes__()[$ name].primitives[index].vbuff;
}

/// get default texture of [index]th primitive of mesh
function gltfMeshTexture(meshName, index) {
	return __gltfMeshes__()[$ name].primitives[index].tex;
}

/// returns array of mesh primitives [{vbuff, tex, uv}]
function gltfGetMeshPrimitives(name) {
	return __gltfMeshes__()[$ name].primitives;
}

/// draw a mesh. can optionally override textures each primitive uses
function gltfDrawMesh(name, textures=[]) {
	var prims = gltfGetMeshPrimitives(name);
	var texCount = array_length(textures);
	var i = 0; repeat(array_length(prims)) {
		var prim = prims[i++];
		var tex = (i < texCount) ? textures[i] : prim.texture;
		vertex_submit(prim.vbuff, pr_trianglelist, tex);
	}
}

/// how many primitives does a mesh have - essentially how many times is the mesh broken up for different materials
function gltfMeshPrimitiveCount(name) {
	return array_length(__gltfMeshes__()[$ name].primitives);
}

/// get size of bounding box of mesh as vec(x,y,z)
function gltfMeshSize(name) {
	return __gltfMeshes__()[$ name].sizeGet();
}

/// get midpoint of bounding box of a mesh
function gltfMeshMidpoint(name) {
	return __gltfMeshes__()[$ name].dimensions.midPoint();
}

/// called automatically by gltfLoad()
function __gltfLoadMesh(dat, buffers, meshID, skinID=undefined, animData=undefined) {
	var nodes = dat.nodes;
	
	var mesh = dat.meshes[meshID];
	
	var name = mesh.name;
	
	var skinned = !is_undefined(skinID);
	
	var textures = [ ];
	
	for (var i = 0; i < array_length(mesh.primitives); i++) {
		var prim = mesh.primitives[i];
		var a = prim.attributes;
		
		textures[i] = sprite_get_texture(__gltfSprCube, 0);
		
		// are there images?
		var mat = prim[$ "material"];
		if (!is_undefined(mat)) {
			/*		accessing materials (just for the textures)
			
				materials[]
					<MATERIAL TYPE>{}				<- eg pbrMetallicRoughness which is the default in blender
						baseColorTexture{}
							index : TEXTURE ID

				textures[]
					source : IMAGE ID
				
				images[]
					bufferView : BUFFERVIEW ID
					mimeType : FILE TYPE			<- eg "image/png"
					name : FILE NAME
				
			*/
			mat = dat.materials[mat];
			// hack to get it working for now
			var roughness = mat[$ "pbrMetallicRoughness"];
			if (!is_undefined(roughness)) {
				if (!is_undefined(roughness[$ "baseColorTexture"])) {
					mat = roughness.baseColorTexture.index;
					var fname = __gltfBufferExportImage(mat, dat, buffers, false);
					textures[i] = __gltfGetTexture(fname);
				}
			}
		}
		
		/*		accessing dimensions of a mesh
		
			meshes[]
				primitives[]
					attributes{}
						POSITION : ACCESSOR ID
		
			accessors[]
				min : [x,y,z]
				max : [x,y,z]
		
		*/
		
		var aPos = a.POSITION;
		var dMin = dat.accessors[aPos].min;
		var dMax = dat.accessors[aPos].max;
		__gltfDebugPrint("dMin: {0}, dMax: {1}", [ string(dMin), string(dMax) ]);
		var dims = new __gltfAabb(__gltfArrayToVec3(dMin), __gltfArrayToVec3(dMax));
		__gltfDebugPrint("dimensions of primitive {0}: {1}", [ i, string(dims) ]);
		
		// extract v, vn, vt (vertex position, normal, texcoord)
	
		var v = __gltfAccessBuffer(a.POSITION, dat, buffers);
		var vn = __gltfAccessBuffer(a.NORMAL, dat, buffers);
		var vt = __gltfAccessBuffer(a.TEXCOORD_0, dat, buffers);
		var indices = __gltfAccessBuffer(prim.indices, dat, buffers);
		
		// TODO: slurp the vertex colour data in case ppl need it for shaders
		
		if (!skinned) {
			// extract just the mesh
			var m = __gltfGenerateMesh(v, vn, vt, indices);
			__gltfStoreMesh(name, m, i, textures[i], dims);
		}
		else {
			// if the mesh is skinned,
			// extract JOINTS_0 and WEIGHTS_0 for the skinning matrix
			var joints = __gltfAccessBuffer(a.JOINTS_0, dat, buffers);
			var weights = __gltfAccessBuffer(a.WEIGHTS_0, dat, buffers);
			var m = __gltfGenerateSkinnedMesh(v, vn, vt, indices, joints, weights);
			__gltfStoreMesh(name, m, i, textures[i], dims);
		}
	}
	
	if (skinned) {
		var skin = dat.skins[skinID];
		var inverseBindMatrices = __gltfAccessBuffer(skin.inverseBindMatrices, dat, buffers);
		var joints = skin.joints;
		var jointsCount = array_length(joints);
		var parentJoints = array_create(jointsCount, undefined);
		
		// reverse the joint node/indices for easy lookup
		var jointNodeMap = array_create(array_length(nodes), undefined);
		for (var j = 0; j < jointsCount; j++) {
			jointNodeMap[joints[j]] = j;
		}
		
		// build joint parent hierarchy
		for (var j = 0; j < jointsCount; j++) {
			var node = nodes[joints[j]];
			var children = node[$ "children"];
			if (!is_undefined(children)) {
				for (var k = 0; k < array_length(children); k++) {
					var child = children[k]; // this is NODE array pointer
					var childInd = jointNodeMap[child]; // this is the JOINT ARRAY INDEX
					parentJoints[childInd] = j; // PLEASE LET THIS FUCKIONG BE CORRECT
				}
			}
		}
		
		var skinData = new __gltfSkinData(skin.name, mesh.name);
		skinData.textures = textures; // this isnt great, the skin data should pull the textures from mesh/primitive data but oh well
		for (var j = 0; j < jointsCount; j++) {
			var node = nodes[joints[j]];
			
			var T = node[$ "translation"];
			var R = node[$ "rotation"];
			var S = node[$ "scale"];
				
			//var M = matrix_build_quaternion(T[0], T[1], T[2], R, S[0], S[1], S[2]);
			
			/*		https://lisyarus.github.io/blog/posts/gltf-animation.html
			
				bones without a corresponding transform in the animation will have incorrect "default" state
			
			*/
			
			var bAnim = undefined;
			if (!is_undefined(animData)) {
				bAnim = animData[joints[j]];
			}
			
			var boneName = node.name;
			
			var restPose = new gltfPoseTriple(T, R, S);
			var M = restPose.toMatrix();
			
			skinData.addBone(parentJoints[j], M, inverseBindMatrices[j], boneName, restPose, bAnim);
		}
	}
}

function __gltfAccessBuffer(accessorID, dat, buffers) {
	static typeComponentCount = {
		"SCALAR" :	1,
		"VEC2" :	2,
		"VEC3" :	3,
		"VEC4" :	4,
		"MAT2" :	4,
		"MAT3" :	9,
		"MAT4" :	16,
	};
	
	static typeIDs = {
		"_5126" : buffer_f32,
		"_5123" : buffer_u16,
		"_5121" : buffer_u8,
	};
	
	var ac = dat.accessors[accessorID];
	var type = ac.type;
	var comp = ac.componentType;
	var count = ac.count;
	
	var bv = dat.bufferViews[ac.bufferView];
	var byteLength = bv.byteLength;
	var byteOffset = bv.byteOffset;
	//var target = bv[$ target]; // array buff or element array buff
	
	var buff = buffers[bv.buffer];
	
	buffer_seek(buff, buffer_seek_start, byteOffset);
	
	var ret = [ ];
	
	var t = typeIDs[$ $"_{comp}"];
	var dim = typeComponentCount[$ type];
	// if (dim == 1) - array of scalars instead of array of arrays?
	if (dim == 1) {
		for (var i = 0; i < count; i++) {
			ret[i] = buffer_read(buff, t);
		}
	}
	else {
		for (var i = 0; i < count; i++) {
			ret[i] = [ ];
			for (var j = 0; j < dim; j++) {
				ret[i][j] = buffer_read(buff, t);
			}
		}
	}
	
	return ret;
}

/// dump image to %localappdata%\{Project Name}\dat\ for loading
function __gltfBufferExportImage(imageID, dat, buffers, overwrite=false) {
	var img = dat.images[dat.textures[imageID].source];
	var mimeType = img.mimeType;
	var fileType = string_delete(mimeType, 1, string_pos("/", mimeType));
	var fname = "dat\\"+img.name+"."+fileType;
	
	if (!file_exists(fname) || overwrite) {
		var bv = dat.bufferViews[img.bufferView];
	
		var byteLength = bv.byteLength;
		var byteOffset = bv.byteOffset;
		
		var buff = buffers[bv.buffer];
	
		buffer_seek(buff, buffer_seek_start, byteOffset);
	
		var imgdat = buffer_create(byteLength, buffer_fixed, 1);
		
		buffer_copy(buff, byteOffset, byteLength, imgdat, 0);
		
		buffer_save(imgdat, fname);
		
		buffer_delete(imgdat);
	}
	return fname;
}

/// generate a vertex buffer for use with pr_trianglelist.
/// contains vertex positions, normals, texture coords
function __gltfGenerateMesh(v, vn, vt, indices) {
	var buff = vertex_create_buffer();
	vertex_begin(buff, __gltfVertexformat__());
	
	var n = array_length(indices);
	for (var i = 0; i < n; i++) {
		var k = indices[i];
		vertex_position_3d(buff, v[k][0], v[k][1], v[k][2]);
		vertex_normal(buff, vn[k][0], vn[k][1], vn[k][2]);
		vertex_texcoord(buff, vt[k][0], vt[k][1]);
		vertex_color(buff, c_white, 1);
	}
	
	vertex_end(buff);
	vertex_freeze(buff);
	return buff;
}

/// generate a vertex buffer for use with pr_trianglelist.
/// contains vertex positions, normals, texture coords, joint weight data
function __gltfGenerateSkinnedMesh(v, vn, vt, indices, joints, weights) {
	var buff = vertex_create_buffer();
	vertex_begin(buff, __gltfVertexformat__(true));
	
	var n = array_length(indices);
	for (var i = 0; i < n; i++) {
		var k = indices[i];
		vertex_position_3d(buff, v[k][0], v[k][1], v[k][2]);
		vertex_normal(buff, vn[k][0], vn[k][1], vn[k][2]);
		vertex_texcoord(buff, vt[k][0], vt[k][1]);
		vertex_float4(buff, joints[k][0], joints[k][1], joints[k][2], joints[k][3]);
		vertex_float4(buff, weights[k][0], weights[k][1], weights[k][2], weights[k][3]);
		vertex_color(buff, c_white, 1);
	}
	
	vertex_end(buff);
	vertex_freeze(buff);
	return buff;
}

/**
 * Function Description
 * @param {String} name Description
 * @param {Id.VertexBuffer} vbuff Description
 * @param {real} [index]=0 primitiveID
 * @param {Pointer.Texture} [tex]=-1 Description
 * @param {Struct.__gltfAabb} [dims] dimensions
 */
function __gltfStoreMesh(name, vbuff, index, tex, dims) {
	var meshes = __gltfMeshes__();
	if (is_undefined(meshes[$ name])) {
		meshes[$ name] = new __gltfMeshInfo(name);
	}
	var mesh = meshes[$ name];
	mesh.primitives[index] = new __gltfMeshPrimitive(vbuff, tex);
	if (!is_undefined(dims)) {
		mesh.sizeExpand(dims.v1, dims.v2);
	}
}

/// prints all mesh names to console. they are stored in a struct so the order is not guaranteed
function gltfListMeshes() {
	var meshes = __gltfMeshes__();
	var names = variable_struct_get_names(meshes);
	for (var i = 0; i < array_length(names); i++) {
		//__gltfDebugPrint("mesh {0} is called {1}", [ i, names[i] ]);
		// do a normal print statement so this still works when GLTF_DEBUG is false
		show_debug_message($"mesh {i} is called {names[i]}");
	}
}

/// singleton to store mesh data
function __gltfMeshes__() {
	static meshes = { };
	return meshes;
}

/// stores convenient info about a mesh like bounding box and textures
function __gltfMeshInfo(_name, _primitives=[], _info={}) constructor {
	name = _name;
	primititives = _primitives;
	
	// default values
	dimensions = undefined; // will store an AABB with min & max size
	
	__gltfStructCopy(self, _info);
	
	/// get arbitrary value
	static get = function(valueName) {
		return self[$ valueName];
	};
	
	static sizeExpand = function(vMin, vMax) {
		if (is_undefined(dimensions)) {
			dimensions = new __gltfAabb(vMin, vMax);
		}
		else {
			dimensions.expand(vMin, vMax);
		}
	};
	
	/// returns vec3 of the size of the bounding box
	static sizeGet = function() {
		return dimensions.size();
	};
}

/// @desc  simple data structure for a primitive of a mesh
/// @param {Id.VertexBuffer} _vbuff Description
/// @param {Pointer.Texture} _texture Description
/// @param {array<real>} [_uvs] Description
function __gltfMeshPrimitive(_vbuff, _texture, _uvs=[0,0,1,1]) constructor {
	vbuff = _vbuff;
	texture = _texture;
	uvs = _uvs;
}

/// default vertex formats
function __gltfVertexformat__(skinned=false) {
	static format = (function() {
		vertex_format_begin();
		vertex_format_add_position_3d();
		vertex_format_add_normal();
		vertex_format_add_texcoord();
		vertex_format_add_color();
		return vertex_format_end();
	})();
	static formatSkinned = (function() {
		vertex_format_begin();
		vertex_format_add_position_3d();
		vertex_format_add_normal();
		vertex_format_add_texcoord();
		vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // INDICES
		vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // WEIGHTS
		vertex_format_add_color();
		return vertex_format_end();
	})();
	return skinned ? formatSkinned : format;
}

function __gltfDebugPrint(str, args=[]) {
	if (GLTF_DEBUG) show_debug_message(string(current_time)+": "+string_ext(str, args));
}
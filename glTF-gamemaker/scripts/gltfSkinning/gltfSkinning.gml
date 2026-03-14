/// skinned mesh instance
/// @param {string} skinName name of skin
function gltfSkinnedMesh(skinName) constructor {
	var skins = __gltfSkins();
	skin = undefined;
	mesh = undefined;
	for (var i = 0; i < array_length(skins); i++) {
		var _skin = skins[i];
		if (_skin.skinName == skinName) {
			// get reference to the skin data and the appropriate mesh
			skin = _skin;
			mesh = skin.meshName;
			break;
		}
	}
	
	if (is_undefined(skin)) {
		show_error(string("skin not found: {0}", skinName), true);
	}
	
	// foreach primitive in mesh, get default texture
	primitives = gltfMeshPrimitiveCount(mesh);
	texture = array_create(primitives, -1);
	for (var i = 0; i < primitives; i++) {
		if (i < array_length(skin.textures)) {
			texture[i] = skin.textures[i];
		}
		textureUVs[i] = [0, 0, 1, 1];
	}
	
	data = skin.data; // get a reference from the skin (dont write to it!) so i dont have to type skin.data so much
	
	poseMatrices = [ ];
	localTransform = [ ];
	modelTransform = [ ];
	
	for (var i = 0; i < skin.bones; i++) {
		localTransform[i] = array_create(16);
		modelTransform[i] = array_create(16);
	}
	
	currentAnimation = "none";
	
	/// @function animate(t)
	/// @desc animate the mesh with the given timestamp using currentAnimation
	/// @param {float} t in seconds
	static animate = function(t=0) {
		var anim = skin.animate(t, currentAnimation);
		var n = array_length(anim);
		var result = array_create(n);
		for (var i = 0; i < n; i++) {
			result[i] = array_create(16);
			if (is_undefined(anim[i])) {
				result[i] = data[i][1];
			}
			else {
				var rest = skin.restPoses[i];
				result[i] = anim[i].toMatrix(rest.T, rest.R, rest.S);
			}
		}
		return update(result, poseMatrices, true);
	};
	
	/// @function animateBlended(b)
	/// @desc animate mesh using blended animation
	/// @param {Array gltfPoseTriple} b result from blendAnimation
	static animateBlended = function(b) {
		var n = skin.bones;
		var result = array_create(n);
		for (var i = 0; i < n; i++) {
			var rest = skin.restPoses[i];
			result[i] = b[i].toMatrix(rest.T, rest.R, rest.S);
		}
		return update(result, poseMatrices, true);
	};
	
	/// @function blendAnimation(a1, a2, amount)
	/// @desc blend from 1 animation to another using amount. undefined animation channels will always be ignored
	/// @param {Array gltfPoseTriple} a1 result from blendAnimation
	/// @param {Array gltfPoseTriple} a2 result from blendAnimation
	/// @param {float} amount blend from a1 to a2, 0 - 1
	static blendAnimation = function(a1, a2, amount) {
		var n = skin.bones;
		var result = array_create(n);
		for (var i = 0; i < n; i++) {
			result[i] = a1[i].blend(a2[i], amount);
		}
		return result;
	};
	
	/// @function maskAnimation(a, bonenames, inclusive)
	/// @desc mask out specific bones on an animation and return it
	/// @param {Array gltfPoseTriple} a result from skinned.animate
	/// @param {Array string} bonenames array of bone names, that will be masked out
	/// @param {bool} invert if only masked bones should remain
	static maskAnimation = function(a,bonenames, invert = false) {
		var masks = [];
		for (var bn = 0; bn < array_length(bonenames); bn++) {
			var index = getBoneIndex(bonenames[bn]);
			array_push(masks,index);
		} 
		
		var n = skin.bones;
		var result = array_create(n);
		for (var i = 0; i < n; i++) {
			if (array_contains(masks,i) != invert){
				result[i] = new gltfPoseTriple();
			} else {
				result[i] = a[i];
			}
		}
		return result;
	}
	
	/// calc transforms of each bone & return how much they move the vertices.
	/// _fromAnimation should only be set to true when called from the animate function
	static update = function(_in=[], _out=poseMatrices, _fromAnimation=false) {
		for (var i = 0; i < skin.bones; i++) {
			var t = (i<array_length(_in)) ? _in[i] : matrix_build_identity();
			
			if (_fromAnimation) {
				// animation data has all the information we need
				//localTransform[i] = t;
				array_copy(localTransform[i], 0, t, 0, 16);
			}
			else {
				// 
				//localTransform[i] = mulMats(t, data[i][1]);
				array_copy(localTransform[i], 0, __gltfMulMats(data[i][1], t), 0, 16);
			}
		}
		
		// root node never has a parent
		modelTransform[0] = localTransform[0];
		
		for (var i = 1; i < skin.bones; i++) {
			var parentNode = data[i][0];
			if (is_undefined(parentNode)) {
				//modelTransform[i] = localTransform[i];
				array_copy(modelTransform[i], 0, localTransform[i], 0, 16);
			}
			else {
				//modelTransform[i] = mulMats(modelTransform[parentNode], localTransform[i]);
				array_copy(modelTransform[i], 0, __gltfMulMats(modelTransform[parentNode], localTransform[i]), 0, 16);
			}
		}
		
		for (var i = 0; i < min(skin.bones, MAXIMUM_BONES); i++) {
			var m = __gltfMulMats(modelTransform[i], data[i][2]);
			array_copy(_out, i*16, m, 0, 16);
		}
		
		return self;
	};
	
	
	/**
	 * draw the mesh. bone pose information and custom textures from this instance are automatically used
	 * @param {asset.GMShader} [shader]=shGltfSkinnedMesh custom shader
	 * @param {array<Struct.shaderUniform>} [uniforms]=[] additional uniforms if needed with shader (see structs in shaderHelpers)
	 */
	static draw = function(shader=shGltfSkinnedMesh, uniforms=[]) {
		shader_set(shader);
		// all skin draw shaders MUST have a u_bones matrix array uniform
		var uBones = shader_get_uniform(shader, "uBones");
		shader_set_uniform_matrix_array(uBones, poseMatrices);
		
		// additional uniforms
		for (var i = 0; i < array_length(uniforms); i++) {
			uniforms[i].go();
		}
		
		for (var i = 0; i < primitives; i++) {
			vertex_submit(gltfGetMesh(mesh, i), pr_trianglelist, texture[i]);
		}
		shader_reset();
	};
	
	static setTexture = function(ind, tex, uvs=undefined) {
		texture[ind] = tex;
		textureUVs[ind] = uvs ?? textureUVs[ind];
		return self;
	};
	
	static setAnimation = function(animName) {
		currentAnimation = animName;
		return self;
	};
	
	static getAnimationLength = function(animName=currentAnimation) {
		return skin.animLength[$ animName] ?? 0;
	};
	
	
	/**
	 * @return {Struct.vec} .x, .y, .z size of untransformed mesh
	 */
	static getSize = function() {
		return skin.size;
	};
	
	/// get bone index from its string name, useful for procedural animations
	static getBoneIndex = function(bName="Root") {
		return skin.getBoneIndex(bName);
	};
	
	/**
	 * returns index of parent bone, or undefined if it has none
	 * @param {real} boneIndex child bone
	 */
	static getBoneParent = function(boneIndex) {
		return skin.data[boneIndex][0];
	};
	
	/**
	 * poseTriple T,R,S of the default rest pose of bone
	 * @param {real} boneIndex
	 * @return {Struct.poseTriple}
	 */
	static getBoneRestPose = function(boneIndex) {
		return skin.restPoses[boneIndex];
	};
	
	/// local = animation * restpose
	static getBoneLocalTransformMatrix = function(boneIndex) {
		return localTransform[boneIndex];
	};
	
	/// model = model(parent) * local
	static getBoneModelTransformMatrix = function(boneIndex) {
		return modelTransform[boneIndex];
	};
	
	/// placeholder: does not currently draw "leaf" bones because it doesnt display the bones themselves,
	/// it only draws lines from child to parent locations
	static debugDrawBones = function() {
		var buff = vertex_create_buffer();
		
		vertex_begin(buff, __gltfVertexFormatWire());
		
		for (var i = 1; i < skin.bones; i++) {
			var par = skin.data[i][0];
			if (!is_undefined(par)) {
				var m = modelTransform[i];
				repeat(2) {
					vertex_position_3d(buff, m[12], m[13], m[14]);
					vertex_colour(buff, c_white, 1);
					m = modelTransform[par];
				}
			}
		}
		
		vertex_end(buff);
		
		gpu_set_ztestenable(false);
		vertex_submit(buff, pr_linelist, -1);
		gpu_set_ztestenable(true);
		
		vertex_delete_buffer(buff);
	};
	
	static setAnimationIndex = function(ind) {
		var names = variable_struct_get_names(skin.animLength);
		if (ind < array_length(names)) {
			setAnimation(names[ind]);
		}
		return self;
	};
}

/**
 * retrieve skin data
 * @param {String} name
 * @returns {Struct.__skin_data}
 */
function gltfGetSkin(name) {
	var skins = __gltfSkins();
	for (var i = 0; i < array_length(skins); i++) {
		var skin = skins[i];
		if (skin.skinName == name) {
			return skin;
		}
	}
	show_error("skin does not exist: "+string(name), true);
	//return noone;
}

/**
 * helper for generating pose data by lerping between keyframes
 * @param {Array} _keyframes
 * @returns {Struct.__skin_data}
 */
function gltfAnimationSampler(_keyframes, _values, _interp, _isRotation=true) constructor {
	keyframes = _keyframes;
	values = _values;
	interp = _interp;
	// relevant for whether you lerp or slerp linear type interpolations
	// and also the dimension (4 instead of 3) of rotation cubicsplines as they are quaternions
	isRotation = _isRotation;
	
	tMin = 0;
	tMax = __gltfArrayLast(keyframes);
	n = array_length(keyframes);
	
	lerpFunc = undefined;
	
	if (n > 1) {
		switch (interp) {
			case "STEP":
				lerpFunc = function(i, t) {
					return values[i];
				};
				break;
				
			case "LINEAR":
				if (isRotation) {
					lerpFunc = function(i, t) {
						var tween = __gltfInvlerp(keyframes[i], keyframes[i+1], t);
						return __gltfSlerp(values[i], values[i+1], tween);
					};
				}
				else {
					lerpFunc = function(i, t) {
						var tween = __gltfInvlerp(keyframes[i], keyframes[i+1], t);
						return __gltfLerpArray(values[i], values[i+1], tween);
					};
				}
				break;
				
			case "CUBICSPLINE":
				lerpFunc = function(i, tc) {
					/*
						vt = (2t^3-3t^2+1)*vk + td(t^3-2t^2+t)*bk+(-2t^3+3t^2)*v<k+1>+td(t^3-t^2)*a<k+1>
					*/
					
					var tk = keyframes[i];
					var tk1 = keyframes[i+1];
					var td = tk1-tk;
					
					var t = (tc-tk) / td;
					
					// t-squared and t-cubed
					var t2 = t*t;
					var t3 = t2*t;
					
					var vk,bk,ak1,vk1;
					
					vk = values[3*i+1];
					bk = values[3*i+2];
					
					ak1 = values[3*i+3];
					vk1 = values[3*i+4];
					
					var dim = array_length(vk);
					
					var vf = (dim==4) ? __gltfArrayToVec : __gltfArrayToVec3;
					
					var vt =	  (vf(vk).scale(2*t3-3*t2+1))
						.translate(vf(bk).scale(td*(t3-2*t2+t)))
						.translate(vf(vk1).scale(-2*t3+3*t2))
						.translate(vf(ak1).scale(td*(t3-t2)));
					
					return vt.toArray();
					//return lerpArray(values[3*i+1], values[3*i+4], tween);
				};
				break;
		}
	}
	
	
	
	static get = function(time) {
		// base cases - no animation or only one frame
		if (n == 0) {
			__gltfDebugPrint("there is an animation with no frames!");
			return undefined;
		}
		if (n == 1) return values[0];
		
		var i0 = 1;
		if (time >= tMax) { i0 = n-1; time=tMax; } // clamp
		
		for (var i = i0; i < n; i++) {
			if (time <= keyframes[i]) {
				var result = lerpFunc(i-1, time);
				return result;
			}
		}
	};
	
	static toString = function() {
		return string_ext("bone gltfAnimationSampler: {0}: {1} -> {2}", [ interp, string(keyframes), string(values) ]);
	};
}

/// mostly relevant for blending animations together, contains 3 arrays
/// T,R,S - translation[3], rotationQuat[4] OR rotationEuler[3], scale[3]
function gltfPoseTriple(_t=undefined, _r=undefined, _s=undefined) constructor {
	// any of these values can be undefined
	// which is important when blending only bones with animation data
	T = _t;
	R = _r;
	S = _s;
	
	// convert R to quaternion as this is what the model file knows and how rotations are blended together
	// u can get model rotations in euler from the skinnedMesh class
	if (!is_undefined(R) && array_length(R) == 3) R = __gltfAngleToQuaternion(R[0], R[1], R[2]);
	
	/// T0,R0,S0 inputs are fallback values if any of the pose properties are undefined,
	/// eg the default local transform of an armature
	static toMatrix = function(T0=undefined, R0=undefined, S0=undefined) {
		
		// note: another way to do this would be to multiply non-identity matrices only instead of doing a full build
		// given that im *already* branching a lot with the ?? operator
		
		var T1 = (T ?? T0) ?? [ 0, 0, 0 ];
		var R1 = (R ?? R0) ?? [ 0, 0, 0, 1 ];
		var S1 = (S ?? S0) ?? [ 1, 1, 1 ];
		
		return __gltfMatrixBuildQuaternion(T1[0], T1[1], T1[2], R1, S1[0], S1[1], S1[2]);
	};
	
	/// blend pose with a 2nd pose with factor (0 <= time <= 1)
	static blend = function(p2, time) {
		time = clamp(time, 0, 1);
		var T1, R1, S1;
		
		if (is_undefined(T)) T1 = p2.T;
		else if (is_undefined(p2.T)) T1 = T;
		else T1 = __gltfLerpArray(T, p2.T, time);
		
		if (is_undefined(R)) R1 = p2.R;
		else if (is_undefined(p2.R)) R1 = R;
		else R1 = __gltfSlerp(R, p2.R, time);
		
		if (is_undefined(S)) S1 = p2.S;
		else if (is_undefined(p2.S)) S1 = S;
		else S1 = __gltfLerpArray(S, p2.S, time);
		
		return new gltfPoseTriple(T1, R1, S1);
	};
}

/// data structure containing all relevant info about a loaded skinned mesh
function __gltfSkinData(_name, _meshName, _boneCount=MAXIMUM_BONES) constructor {
	// array of [PARENT] [LOCAL TRANSFORM] [INVERSE BIND MATRIX]
	data = array_create(_boneCount);
	// create arrays at the start so they are (hopefully) sequential in memory
	for (var i = 0; i < _boneCount; i++) {
		data[i] = [
			undefined,
			array_create(16, 0),
			array_create(16, 0),
		];
	}
	animSamplers = [ ];
	skinName = _name;
	meshName = _meshName;
	boneNames = [ ];
	restPoses = [ ];
	boneNamesMap = undefined;
	
	animLength = { };
	textures = [ ];
	size = gltfMeshSize(meshName);
	
	__gltfDebugPrint("storing new skin {0}, {1}", [ skinName, meshName ]);
	
	array_push(__gltfSkins(), self);
	
	bones = 0;
	
	static getBoneIndex = function(bName) {
		if (is_undefined(boneNamesMap)) {
			boneNamesMap = __gltfBimap(boneNames);
		}
		return boneNamesMap[$ bName];
	};
	
	/// @desc called by gltfLoad
	/// @param {real} par
	/// @param {array} loc
	/// @param {array} inv
	/// @param {String} boneName
	/// @param {Struct.poseTriple} restPose
	/// @param {Struct} [animData]
	static addBone = function(par, loc, inv, boneName, restPose, animData=undefined) {
		data[bones][0] = par;
		array_copy(data[bones][1], 0, loc, 0, 16);
		array_copy(data[bones][2], 0, inv, 0, 16);
		
		boneNames[bones] = boneName;
		restPoses[bones] = restPose;
		
		if (!is_undefined(animData)) {
			array_push(animSamplers, { });
			var names = variable_struct_get_names(animData);
			for (var i = 0; i < array_length(names); i++) {
				var name = names[i];
				var anim = animData[$ name];
				
				animSamplers[bones][$ name] = { };
				var cnames = variable_struct_get_names(anim);
				for (var j = 0; j < array_length(cnames); j++) {
					var cname = cnames[j];
					var isRotation = (cname == "rotation");
					var ca = anim[$ cname];
					var s = new gltfAnimationSampler(ca.in, ca.out, ca.interp, isRotation);
					animSamplers[bones][$ name][$ cname] = s;
					animLength[$ name] = animLength[$ name] ?? 0;
					animLength[$ name] = max(animLength[$ name], s.tMax);
				}
			}
		}
		bones++;
		return self;
	};
	
	/// this is called by a skinnedMesh instance and it returns an array of poseTriple for each bone
	static animate = function(t, animName) {
		var n = array_length(animSamplers);
		var result = array_create(n, undefined);
		var len = animLength[$ animName] ?? 0;
		if (is_undefined(len)) return result;
		if (len != 0) t %= len;
		for (var i = 0; i < n; i++) {
			var s = animSamplers[i][$ animName];
			if (is_undefined(s)) s = { };
			var T = s[$ "translation"];
			var R = s[$ "rotation"];
			var S = s[$ "scale"];
			T = (is_undefined(T)) ?
				undefined :
				T.get(t);
			R = (is_undefined(R)) ?
				undefined :
				R.get(t);
			S = (is_undefined(S)) ?
				undefined :
				S.get(t);
			
			result[i] = new gltfPoseTriple(T, R, S);
		}
		return result;
	};
}

/// @returns {Array<Struct.__skin_data>}
function __gltfSkins() {
	static skins = [ ];
	return skins;
}

/// simple vertex format for drawing wireframe
function __gltfVertexFormatWire() {
	static format = (function() {
		vertex_format_begin();
		vertex_format_add_position_3d();
		vertex_format_add_color();
		return vertex_format_end();
	})();
	return format;
}
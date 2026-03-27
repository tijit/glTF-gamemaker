// Feather disable all

//builds matrix but with correct rotation preapplied
function gltfMatrixBuild(px=0, py=0, pz=0, rx=0, ry=0, rz=0, scalex=1, scaley=1, scalez=1){
	return matrix_build(px, py, pz, rx, ry+180, rz+180, scalex, scaley, scalez);
}

/**
 * run draw code at transformed coords, corrects for +Yup rotation.
 * useful for drawing models "side on" so the default room view roughly maps to what you see.
 * for more rotation options use gltfDrawTransformed3D
 * @param {real} px x position
 * @param {real} py y position
 * @param {real} pz z position (basically depth)
 * @param {real} rot rotation about z-axis (basically image_angle)
 * @param {real} scale uniform scaling
 * @param {function} drawCode function containing draw code to run with this transform applied
 */
function gltfDrawTransformed(px, py, pz, rot, scale, drawCode=function(){}) {
	matrix_build(px, py, pz, 0, 180, rot+180, scale, scale, scale, __gltfTransform());
	__gltfDrawTransform(drawCode)
}

/**
 * gltfDrawTransformed() with more rotation options, corrects for +Yup rotation
 * @param {real} px x position
 * @param {real} py y position
 * @param {real} pz z position
 * @param {real} rx rotation about x-axis
 * @param {real} ry rotation about y-axis
 * @param {real} rz rotation about z-axis
 * @param {real} scale uniform scaling
 * @param {function} drawCode function containing draw code to run with this transform applied
 */
function gltfDrawTransformed3D(px, py, pz, rx, ry, rz, scale, drawCode=function(){}) {
	matrix_build(px, py, pz, rx, ry+180, rz+180, scale, scale, scale, __gltfTransform());
	__gltfDrawTransform(drawCode);
}

/**
 * for drawing with a premade matrix
 * @param {transform} m world matrix
 * @param {function} drawCode function containing draw code to run with this transform applied
 */
function gltfDrawTransformedMat(m,drawCode=function(){}){
	array_copy(__gltfTransform(),0,m,0,16);
	__gltfDrawTransform(drawCode);
	
}

function __gltfDrawTransform(drawCode){
	matrix_set(matrix_world, __gltfTransform());
	drawCode();
	gltfSetIdentity();
}

function __gltfTransform(){
	static m = array_create(16);
	return m;
}

/// return to default camera view coords
function gltfSetIdentity() {
	static I = matrix_build_identity();
	matrix_set(matrix_world, I);
}

/**
 * gltfTransform() transforms a matrix
 * @param {real} px x position
 * @param {real} py y position
 * @param {real} pz z position
 * @param {real} rx rotation about x-axis
 * @param {real} ry rotation about y-axis
 * @param {real} rz rotation about z-axis
 * @param {real} scalex uniform scaling
 * @param {real} scaley uniform scaling
 * @param {real} scalez uniform scaling
 */
function gltfTransform(m,px=0,py=0,pz=0,rx=0,ry=0,rz=0,scalex=1,scaley=1,scalez=1){
	matrix_multiply(m,matrix_build(px,py,pz,rx,ry,rz,scalex,scaley,scalez),m);
}

/**
 * gltfRotate() rotate a matrix
 * @param {matrix} m x position
 * @param {real} rotx x position
 * @param {real} roty y position
 * @param {real} rotz z position
 */
function gltfRotate(m,rotx,roty,rotz){
	matrix_multiply(m,matrix_build(0,0,0,rotx,roty,rotz,1,1,1),m);
}

/**
 * gltfTranslate() translate a matrix
 * @param {matrix} m x position
 * @param {real} px x position
 * @param {real} py y position
 * @param {real} pz z position
 * @param {real} pixelScale pixel to meter ratio
 */
function gltfTranslate(m,px,py,pz,pixelScale = 1){
	matrix_multiply(m,matrix_build(px*pixelScale,py*pixelScale,pz*pixelScale,0,0,0,1,1,1),m);
}

/**
 * gltfRoomX() returns x position from matrix
 * @param {matrix} m x position
 */
function gltfRoomX(m){
	return m[12];
}

/**
 * gltfRoomY() returns y position from matrix
 * @param {matrix} m y position
 */
function gltfRoomY(m){
	return m[13];
}

/**
 * gltfRoomZ() returns z position from matrix
 * @param {matrix} m z position
 */
function gltfRoomZ(m){
	return m[14];
}
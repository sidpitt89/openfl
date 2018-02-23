package openfl.display;


import Type.ValueType;
import openfl._internal.renderer.cairo.CairoGraphics;
import openfl._internal.renderer.cairo.CairoRenderer;
import openfl._internal.renderer.canvas.CanvasGraphics;
import openfl._internal.renderer.RenderSession;
import openfl.display.Stage;
import openfl.errors.RangeError;
import openfl.errors.TypeError;
import openfl.events.Event;
import openfl.events.EventPhase;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.Vector;

#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end

@:access(openfl.events.Event)
@:access(openfl.display.Graphics)
@:access(openfl.errors.Error)
@:access(openfl.geom.Point)
@:access(openfl.geom.Rectangle)


class DisplayObjectContainer extends InteractiveObject {
	
	
	public var mouseChildren:Bool;
	public var numChildren (get, never):Int;
	public var tabChildren:Bool;

	private var __isInitialized:Bool;
	private var __removedChildren:Vector<DisplayObject>;
	
	
	#if openfljs
	private static function __init__ () {
		
		untyped Object.defineProperty (DisplayObjectContainer.prototype, "numChildren", { get: untyped __js__ ("function () { return this.get_numChildren (); }") });
		
	}
	#end
	
	
	private function new () {
		
		super ();
		
		mouseChildren = true;
		__isInitialized = false;
		__children = new Array<DisplayObject> ();
		__removedChildren = new Vector<DisplayObject> ();

		
	}
	
	
	public function addChild (child:DisplayObject):DisplayObject {

		return addChildAt (child, numChildren);
		
	}

	private function __addChildAtInternal (child:DisplayObject, index:Int):DisplayObject {
		if (child == null) {

			var error = new TypeError ("Error #2007: Parameter child must be non-null.");
			error.errorID = 2007;
			throw error;

		}
		if (index > __children.length || index < 0) {

			throw "Invalid index position " + index;

		}

		if (child.parent == this) {

			if (__children[index] != child) {

				__children.remove (child);
				__children.insert (index, child);

				__setRenderDirty ();

			}

		} else {

			if (child.parent != null) {

				child.parent.removeChild (child);

			}

			__children.insert (index, child);
			child.parent = this;

			var addedToStage = (stage != null && child.stage == null);

			if (addedToStage) {

				this.__setStageReference (stage);

			}

			child.__setTransformDirty ();
			child.__setRenderDirty ();
			__setRenderDirty();

			var event = new Event (Event.ADDED, true);
			event.target = child;
			child.__dispatchWithCapture (event);

			if (addedToStage) {

				var event = new Event (Event.ADDED_TO_STAGE, false, false);
				child.__dispatchWithCapture (event);
				child.__dispatchChildren (event);

			}

		}

		__initializeChild(child);

		return child;
	}

	public function addChildAt (child:DisplayObject, index:Int):DisplayObject {

		__initializeSelf(); //make sure children are initialized

		return __addChildAtInternal(child, index);
	}
	
	
	public function areInaccessibleObjectsUnderPoint (point:Point):Bool {
		
		return false;
		
	}
	
	
	public function contains (child:DisplayObject):Bool {
		
		while (child != this && child != null) {
			
			child = child.parent;
			
		}
		
		return child == this;
		
	}
	
	
	public function getChildAt (index:Int):DisplayObject {

		__initializeSelf();//make sure children are initialized
		if (index >= 0 && index < __children.length) {
			var child =  __children[index];
			return child;
			
		}
		
		return null;
		
	}


	private function __initializeSelf() : Void{
		if(!__isInitialized) {
			__isInitialized = true;
			__enterFrame(0);
		}
	}
	private function __initializeChild(child : DisplayObject) : Void{

		var fun = Reflect.field(child,"__initializeSelf");
		if(Reflect.isFunction(fun))
		{
			Reflect.callMethod(child, fun, [0]);
		}
	}
	
	public function getChildByName (name:String):DisplayObject {

		__initializeSelf();
		for (child in __children) {
			
			if (child.name == name) {
				return child;
			}
			
		}

		return null;
		
	}
	
	
	
	public function getChildIndex (child:DisplayObject):Int {

		__initializeSelf();
		for (i in 0...__children.length) {
			
			if (__children[i] == child) return i;
			
		}
		
		return -1;
		
	}
	
	
	public function getObjectsUnderPoint (point:Point):Array<DisplayObject> {
		
		var stack = new Array<DisplayObject> ();
		__hitTest (point.x, point.y, false, stack, false, this);
		stack.reverse ();
		return stack;
		
	}
	
	
	public function removeChild (child:DisplayObject):DisplayObject {
		
		if (child != null && child.parent == this) {
			
			child.__setTransformDirty ();
			child.__setRenderDirty ();
			__setRenderDirty();
			
			var event = new Event (Event.REMOVED, true);
			child.__dispatchWithCapture (event);
			
			if (stage != null) {
				
				if (child.stage != null && stage.focus == child) {
					
					stage.focus = null;
					
				}
				
				var event = new Event (Event.REMOVED_FROM_STAGE, false, false);
				child.__dispatchWithCapture (event);
				child.__dispatchChildren (event);
				child.__setStageReference (null);
				
			}
			
			child.parent = null;
			__children.remove (child);
			__removedChildren.push (child);
			child.__setTransformDirty ();
			
		}
		
		return child;
		
	}
	
	
	public function removeChildAt (index:Int):DisplayObject {
		
		if (index >= 0 && index < __children.length) {
			
			return removeChild (__children[index]);
			
		}
		
		return null;
		
	}
	
	
	public function removeChildren (beginIndex:Int = 0, endIndex:Int = 0x7FFFFFFF):Void {
		
		if (endIndex == 0x7FFFFFFF) { 
			
			endIndex = __children.length - 1;
			
			if (endIndex < 0) {
				
				return;
				
			}
			
		}
		
		if (beginIndex > __children.length - 1) {
			
			return;
			
		} else if (endIndex < beginIndex || beginIndex < 0 || endIndex > __children.length) {
			
			throw new RangeError ("The supplied index is out of bounds.");
			
		}
		
		var numRemovals = endIndex - beginIndex;
		while (numRemovals >= 0) {
			
			removeChildAt (beginIndex);
			numRemovals--;
			
		}
		
	}

	public override function cleanGraphics ():Void {
		super.cleanGraphics();

		for (child in __children) {
			child.cleanGraphics();
		}
	}
	
	
	private function resolve (fieldName:String):DisplayObject {
		
		if (__children == null) return null;
		
		for (child in __children) {
			
			if (child.name == fieldName) {
				
				return child;
				
			}
			
		}
		
		return null;
		
	}
	
	
	public function setChildIndex (child:DisplayObject, index:Int):Void {

		__initializeSelf();
		if (index < 0 || index > __children.length || child.parent != this || __children[index] == child)
			return;
		__children.remove (child);
		__children.insert (index, child);
		
	}
	
	
	public function stopAllMovieClips ():Void {
		
		__stopAllMovieClips ();
		
	}
	
	
	public function swapChildren (child1:DisplayObject, child2:DisplayObject):Void {

		__initializeSelf();
		if (child1.parent == this && child2.parent == this) {
			
			var index1 = __children.indexOf (child1);
			var index2 = __children.indexOf (child2);
			
			__children[index1] = child2;
			__children[index2] = child1;
			
			__setRenderDirty ();
			
		}
		
	}
	
	
	public function swapChildrenAt (index1:Int, index2:Int):Void {

		__initializeSelf();
		var swap:DisplayObject = __children[index1];
		__children[index1] = __children[index2];
		__children[index2] = swap;
		swap = null;
		__setRenderDirty ();
		
	}
	
	
	private override function __dispatchChildren (event:Event):Void {
		
		if (__children != null) {
			
			for (child in __children) {
				
				event.target = child;
				
				if (!child.__dispatchWithCapture (event)) {
					
					break;
					
				}
				
				child.__dispatchChildren (event);
				
			}
			
		}
		
	}
	
	
	private override function __enterFrame (deltaTime:Int):Void {
		if(__children == null || __renderable == false) return;
		if (!isOnScreen()) {
			return;
		}

		for (child in __children) {
			
			child.__enterFrame (deltaTime);
			
		}
		
	}
	
	
	private override function __getBounds (rect:Rectangle, matrix:Matrix):Void {
		
		super.__getBounds (rect, matrix);
		
		if (__children.length == 0) return;
		
		if (matrix != null) {
			
			__updateTransforms (matrix);
			__updateChildren (true);
			
		}
		
		for (child in __children) {
			
			if (child.__scaleX == 0 || child.__scaleY == 0) continue;
			child.__getBounds (rect, child.__worldTransform);
			
		}
		
		if (matrix != null) {
			
			__updateTransforms ();
			__updateChildren (true);
			
		}
		
	}
	
	
	private override function __getFilterBounds (rect:Rectangle, matrix:Matrix):Void {
		
		super.__getFilterBounds (rect, matrix);
		
		if (__children.length == 0) return;
		
		if (matrix != null) {
			
			__updateTransforms (matrix);
			__updateChildren (true);
			
		}
		
		for (child in __children) {
			
			if (child.__scaleX == 0 || child.__scaleY == 0 || child.__isMask) continue;
			child.__getFilterBounds (rect, child.__worldTransform);
			
		}
		
		if (matrix != null) {
			
			__updateTransforms ();
			__updateChildren (true);
			
		}
		
	}
	
	
	private override function __getRenderBounds (rect:Rectangle, matrix:Matrix):Void {
		
		if (__scrollRect != null) {
			
			super.__getRenderBounds (rect, matrix);
			return;
			
		} else {
			
			super.__getBounds (rect, matrix);
			
		}
		
		if (__children.length == 0) return;
		
		if (matrix != null) {
			
			__updateTransforms (matrix);
			__updateChildren (true);
			
		}
		
		for (child in __children) {
			
			if (child.__scaleX == 0 || child.__scaleY == 0 || child.__isMask) continue;
			child.__getRenderBounds (rect, child.__worldTransform);
			
		}
		
		if (matrix != null) {
			
			__updateTransforms ();
			__updateChildren (true);
			
		}
		
	}
	
	
	private override function __hitTest (x:Float, y:Float, shapeFlag:Bool, stack:Array<DisplayObject>, interactiveOnly:Bool, hitObject:DisplayObject):Bool {
		
		if (!hitObject.visible || __isMask || (interactiveOnly && !mouseEnabled && !mouseChildren)) return false;
		if (mask != null && !mask.__hitTestMask (x, y)) return false;
		
		if (__scrollRect != null) {
			
			var point = Point.__pool.get ();
			point.setTo (x, y);
			__getRenderTransform ().__transformInversePoint (point);
			
			if (!__scrollRect.containsPoint (point)) {
				
				Point.__pool.release (point);
				return false;
				
			}
			
			Point.__pool.release (point);
			
		}
		
		var i = __children.length;
		if (interactiveOnly) {
			
			if (stack == null || !mouseChildren) {
				
				while (--i >= 0) {
					
					if (__children[i].__hitTest (x, y, shapeFlag, null, true, cast __children[i])) {
						
						if (stack != null) {
							
							stack.push (hitObject);
							
						}
						
						return true;
						
					}
					
				}
				
			} else if (stack != null) {
				
				var length = stack.length;
				
				var interactive = false;
				var hitTest = false;
				
				while (--i >= 0) {
					
					interactive = __children[i].__getInteractive (null);
					
					if (interactive || (mouseEnabled && !hitTest)) {
						
						if (__children[i].__hitTest (x, y, shapeFlag, stack, true, cast __children[i])) {
							
							hitTest = true;
							
							if (interactive) {
								
								break;
								
							}
							
						}
						
					}
					
				}
				
				if (hitTest) {
					
					stack.insert (length, hitObject);
					return true;
					
				}
				
			}
			
		} else {
			
			while (--i >= 0) {
				
				__children[i].__hitTest (x, y, shapeFlag, stack, false, cast __children[i]);
				
			}
			
		}
		
		return false;
		
	}
	
	
	private override function __hitTestMask (x:Float, y:Float):Bool {
		
		var i = __children.length;
		
		while (--i >= 0) {
			
			if (__children[i].__hitTestMask (x, y)) {
				
				return true;
				
			}
			
		}
		
		return false;
		
	}
	
	
	private override function __readGraphicsData (graphicsData:Vector<IGraphicsData>, recurse:Bool):Void {
		
		super.__readGraphicsData (graphicsData, recurse);
		
		if (recurse) {
			
			for (child in __children) {
				
				child.__readGraphicsData (graphicsData, recurse);
				
			}
			
		}
		
	}
	
	
	private override function __renderCairo (renderSession:RenderSession):Void {
		
		#if lime_cairo
		if (!__renderable || __worldAlpha <= 0) return;
		
		super.__renderCairo (renderSession);
		
		if (__cacheBitmap != null && !__cacheBitmapRender) return;
		
		renderSession.maskManager.pushObject (this);
		
		if (renderSession.clearRenderDirty) {
			
			for (child in __children) {
				
				child.__renderCairo (renderSession);
				child.__renderDirty = false;
				
			}
			
			__renderDirty = false;
			
		} else {
			
			for (child in __children) {
				
				child.__renderCairo (renderSession);
				
			}
			
		}
		
		for (orphan in __removedChildren) {
			
			if (orphan.stage == null) {
				
				orphan.__cleanup ();
				
			}
			
		}
		
		__removedChildren.length = 0;
		
		renderSession.maskManager.popObject (this);
		#end
		
	}
	
	
	private override function __renderCairoMask (renderSession:RenderSession):Void {
		
		#if lime_cairo
		if (__graphics != null) {
			
			CairoGraphics.renderMask (__graphics, renderSession);
			
		}
		
		for (child in __children) {
			
			child.__renderCairoMask (renderSession);
			
		}
		#end
		
	}

	//S/ Remove this when debugging is no longer needed
	public var childDraws:Int = 0;

	private override function __renderCanvas (renderSession:RenderSession):Void {
		
		if (!__renderable || __worldAlpha <= 0 || (__mask != null && (__mask.width <= 0 || __mask.height <= 0))) return;

		if (calculatedBounds != null && !calculatedBounds.intersects(renderSession.renderer.viewport)) {
			return;
		}
		
		#if !neko
		
		super.__renderCanvas (renderSession);
		
		if (__cacheBitmap != null && !__cacheBitmapRender) return;
		
		renderSession.maskManager.pushObject (this);

		//S/ Remove this when debugging is no longer needed
		childDraws = 0;
		
		if (renderSession.clearRenderDirty) {
			
			for (child in __children) {
				
				child.__renderCanvas (renderSession);
				child.__renderDirty = false;
				
			}
			
			__renderDirty = false;
			
		} else {
			
			for (child in __children) {
				
				child.__renderCanvas (renderSession);
				
			}
			
		}

		//S/ Remove this when debugging is no longer needed
		if (countChildDraws) {
			if (childDraws > Stage.mostDraws) {
				var info:String = "";
				info += this.name;
				if (untyped this.__symbol != null) {
					info += untyped this.__symbol.className;
				}

				Stage.mostDraws = childDraws;
				Stage.mostDrawsInfo = info;
				Stage.mostDrawsTarget = this;
			}
		}

		//S/ Commenting this out for now, because it ultimately causes CanvasElements to be created over and over again.
		//S/ In the future, it may be worth exploring if some parts of orphan.__cleanup() are necessary.
//		for (orphan in __removedChildren) {
//
//			if (orphan.stage == null) {
//
//				orphan.__cleanup ();
//
//			}
//
//		}
//
		__removedChildren.length = 0;
		
		renderSession.maskManager.popObject (this);
		
		#end
		
	}
	
	
	private override function __renderCanvasMask (renderSession:RenderSession):Void {
		
		if (__graphics != null) {
			
			CanvasGraphics.renderMask (__graphics, renderSession);
			
		}
		
		var bounds = Rectangle.__pool.get ();
		__getLocalBounds (bounds);
		
		renderSession.context.rect (bounds.x, bounds.y, bounds.width, bounds.height);
		
		Rectangle.__pool.release (bounds);
		/*for (child in __children) {
			
			child.__renderCanvasMask (renderSession);
			
		}*/
		
	}
	
	
	private override function __renderDOM (renderSession:RenderSession):Void {
		
		#if dom
		
		super.__renderDOM (renderSession);
		
		if (__cacheBitmap != null && !__cacheBitmapRender) return;
		
		renderSession.maskManager.pushObject (this);
		
		if (renderSession.clearRenderDirty) {
			
			for (child in __children) {
				
				child.__renderDOM (renderSession);
				child.__renderDirty = false;
				
			}
			
			__renderDirty = false;
			
		} else {
			
			for (child in __children) {
				
				child.__renderDOM (renderSession);
				
			}
			
		}
		
		for (orphan in __removedChildren) {
			
			if (orphan.stage == null) {
				
				orphan.__renderDOM (renderSession);
				
			}
			
		}
		
		__removedChildren.length = 0;
		
		renderSession.maskManager.popObject (this);
		
		#end
		
	}
	
	
	private override function __renderDOMClear (renderSession:RenderSession):Void {
		
		#if dom
		for (child in __children) {
			child.__renderDOMClear (renderSession);
		}
		
		for (orphan in __removedChildren) {
			if (orphan.stage == null) {
				orphan.__renderDOMClear (renderSession);
			}
		}
		#end
		
	}
	
	
	private override function __renderGL (renderSession:RenderSession):Void {

		if (!__renderable || __worldAlpha <= 0 || (__mask != null && (__mask.width <= 0 || __mask.height <= 0))) return;
		if (calculatedBounds != null && !calculatedBounds.intersects(renderSession.renderer.viewport)) {
			return;
		}
		
		super.__renderGL (renderSession);
		
		if (__cacheBitmap != null && !__cacheBitmapRender) return;
		
		if (__children.length > 0) {
			
			renderSession.maskManager.pushObject (this);
			renderSession.filterManager.pushObject (this);
			
			if (renderSession.clearRenderDirty) {
				
				for (child in __children) {
					
					child.__renderGL (renderSession);
					child.__renderDirty = false;
					
				}
				
				__renderDirty = false;
				
			} else {
				
				for (child in __children) {
					
					child.__renderGL (renderSession);
					
				}
				
			}
			
		}
		
//		for (orphan in __removedChildren) {
//
//			if (orphan.stage == null) {
//
//				orphan.__cleanup ();
//
//			}
//
//		}
		
		__removedChildren.length = 0;
		
		if (__children.length > 0) {
			
			renderSession.filterManager.popObject (this);
			renderSession.maskManager.popObject (this);
			
		}
		
	}
	
	
	private override function __renderGLMask (renderSession:RenderSession):Void {
		
		super.__renderGLMask (renderSession);
		
		if (__cacheBitmap != null && !__cacheBitmapRender) return;
		
		if (renderSession.clearRenderDirty) {
			
			for (child in __children) {
				
				child.__renderGLMask (renderSession);
				child.__renderDirty = false;
				
			}
			
			__renderDirty = false;
			
		} else {
			
			for (child in __children) {
				
				child.__renderGLMask (renderSession);
				
			}
			
		}
		
		for (orphan in __removedChildren) {
			
			if (orphan.stage == null) {
				
				orphan.__cleanup ();
				
			}
			
		}
		
		__removedChildren.length = 0;
		
	}
	
	
	private override function __setStageReference (stage:Stage):Void {
		
		super.__setStageReference (stage);
		
		if (__children != null) {
			
			for (child in __children) {

				if(child != null) {

					child.__setStageReference (stage);

				}

			}
			
		}
		
	}
	
	
	private override function __setWorldTransformInvalid ():Void {
		
		if (!__worldTransformInvalid) {
			
			__worldTransformInvalid = true;
			
			if (__children != null) {
				
				for (child in __children) {
					
					child.__setWorldTransformInvalid ();
					
				}
				
			}
			
		}
		
	}


	private override function __stopAllMovieClips ():Void {
		
		for (child in __children) {
			
			child.__stopAllMovieClips ();
			
		}
		
	}

	//S/ Remove this when debugging is no longer needed
	public var countChildDraws:Bool = true;

	public override function __update (transformOnly:Bool, updateChildren:Bool, ?maskGraphics:Graphics = null):Void {

		var oldCalculatedBounds:Rectangle = (!updateChildren && calculatedBounds != null) ? calculatedBounds.clone() : null;

		super.__update (transformOnly, updateChildren, maskGraphics);

		if (!updateChildren) {
			calculatedBounds = oldCalculatedBounds;
			if (parent != null) {
				parent.applyChildBounds(calculatedBounds);
			}
			return;

		}

		var frameID:UInt = Stage.frameID;
		var selfOrParentChanged = _lastParentOrSelfChangeFrameID == frameID;

		for (child in __children) {

			if (selfOrParentChanged && child.__visible) {

				child._lastParentOrSelfChangeFrameID = frameID;

			}
			if (child._lastParentOrSelfChangeFrameID == frameID || child._lastChildChangeFrameID == frameID) {

				child.__update (transformOnly, true, maskGraphics);

			}
			else {

				applyChildBounds(child.calculatedBounds);

			}
		}

		if (parent != null) {
			parent.applyChildBounds(calculatedBounds);
		}
		
	}

	public override function __forceUpdateTransforms():Void {

		super.__forceUpdateTransforms();

		for (child in __children) {

			child.__forceUpdateTransforms();

		}
	}
	
	public override function __updateChildren (transformOnly:Bool):Void {
		
		super.__updateChildren (transformOnly);

		for (child in __children) {

			child.__forceUpdateTransforms();

		}
		
	}

	private override function postTransformUpdate ():Void {
		calculatedBounds = null;
	}

	public function applyChildBounds(bounds:Rectangle):Void {
		if (calculatedBounds == null) {
			calculatedBounds = bounds != null ? bounds.clone() : null;
		}
		else if (bounds != null) {
			calculatedBounds.merge(bounds);
		}
	}




	// Get & Set Methods
	
	
	
	
	private function get_numChildren ():Int {
		
		return __children.length;
		
	}
	
	
}
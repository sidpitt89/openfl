package format.swf.exporters;


import flash.display.BitmapData;
import flash.text.TextFormatAlign;
import flash.utils.ByteArray;
import format.png.Data;
import format.png.Writer;
import format.swf.data.consts.BitmapFormat;
import format.swf.data.consts.BlendMode;
import format.swf.data.SWFButtonRecord;
import openfl._internal.swf.FilterType;
import openfl._internal.swf.ShapeCommand;
import format.swf.instance.Bitmap;
import lime.tools.helpers.LogHelper;
import openfl._internal.symbols.BitmapSymbol;
import openfl._internal.symbols.ButtonSymbol;
import openfl._internal.symbols.DynamicTextSymbol;
import openfl._internal.symbols.FontSymbol;
import openfl._internal.symbols.ShapeSymbol;
import openfl._internal.symbols.SpriteSymbol;
import openfl._internal.symbols.StaticTextSymbol;
import openfl._internal.symbols.SWFSymbol;
import openfl._internal.timeline.Frame;
import openfl._internal.timeline.FrameObject;
import openfl._internal.timeline.FrameObjectType;
import openfl._internal.swf.SWFLite;
import format.swf.tags.IDefinitionTag;
import format.swf.tags.TagDefineBits;
import format.swf.tags.TagDefineBitsJPEG2;
import format.swf.tags.TagDefineBitsJPEG3;
import format.swf.tags.TagDefineBitsLossless;
import format.swf.tags.TagDefineButton;
import format.swf.tags.TagDefineButton2;
import format.swf.tags.TagDefineEditText;
import format.swf.tags.TagDefineFont;
import format.swf.tags.TagDefineFont2;
import format.swf.tags.TagDefineFont4;
import format.swf.tags.TagDefineShape;
import format.swf.tags.TagDefineSprite;
import format.swf.tags.TagDefineText;
import format.swf.tags.TagPlaceObject;
import format.swf.tags.TagSymbolClass;
import format.swf.SWFRoot;
import format.swf.SWFTimelineContainer;
import format.tools.Deflate;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import lime.graphics.format.JPEG;
import openfl.display.PNGEncoderOptions;
import format.abc.Data;
import format.abc.Data.ABCData;
import format.abc.Data.Name;
import format.swf.tags.TagDefineSound;

using StringTools;
using format.swf.exporters.SWFLiteExporter.AVM2;

class SWFLiteExporter {
	
	
	public var bitmapAlpha:Map <Int, ByteArray>;
	public var bitmaps:Map <Int, ByteArray>;
	public var bitmapTypes:Map <Int, BitmapType>;
	public var sounds:Map <Int, ByteArray>;
	public var soundTypes:Map <Int, SoundType>;
	public var soundSymbolClassNames:Map <Int, String>;
	public var filterClasses:Map <String, Bool>;
	public var swfLite:SWFLite;
	
	private var alphaPalette:Bytes;
	private var data:SWFRoot;
	
	private static var indentationLevel:Int = 0;
	
	public function new (data:SWFRoot) {
		
		this.data = data;
		
		bitmapAlpha = new Map <Int, ByteArray> ();
		bitmaps = new Map <Int, ByteArray> ();
		bitmapTypes = new Map <Int, BitmapType> ();
		sounds = new Map <Int, ByteArray> ();
		soundTypes = new Map <Int, SoundType> ();
		soundSymbolClassNames = new Map <Int, String> ();
		filterClasses = new Map <String, Bool> ();
		
		swfLite = new SWFLite ();
		swfLite.frameRate = data.frameRate;
		
		addSprite (data, true);
		
		for (tag in data.tags) {
			
			if (Std.is (tag, TagSymbolClass)) {
				
				for (symbol in cast (tag, TagSymbolClass).symbols) {
					
					processSymbol (symbol);
					
				}
				
			}
			
		}
		
	}
	
	
	private function addButton (tag:IDefinitionTag):SWFSymbol {
		
		var symbol = new ButtonSymbol ();
		
		if (Std.is (tag, IDefinitionTag)) {
			
			symbol.id = untyped tag.characterId;
			
		}
		
		var processRecords = function (records:Array<SWFButtonRecord>) {
			
			if (records.length > 0) {
				
				var sprite = new SpriteSymbol ();
				var frame = new Frame ();
				frame.labels = [];
				frame.objects = [];
				
				for (i in 0...records.length) {
					
					var object = records[i];
					
					var frameObject = new FrameObject ();
					frameObject.type = FrameObjectType.CREATE;
					frameObject.symbol = object.characterId;
					frameObject.id = i;
					
					processTag (cast data.getCharacter (object.characterId));
					
					if (object.placeMatrix != null) {
						
						var matrix = object.placeMatrix.matrix;
						matrix.tx *= (1 / 20);
						matrix.ty *= (1 / 20);
						
						frameObject.matrix = matrix;
						
					}
					
					if (object.colorTransform != null) {
						
						frameObject.colorTransform = object.colorTransform.colorTransform;
						
					}
					
					if (object.hasBlendMode) {
						
						var blendMode = BlendMode.toString (object.blendMode);
						frameObject.blendMode = blendMode;
						
					}
					
					if (object.hasFilterList) {
						
						var filters:Array<FilterType> = [];
						
						for (filter in object.filterList) {
							
							var type = filter.type;
							
							if (type != null) {
								
								filters.push (filter.type);
								//filterClasses.set (Type.getClassName (Type.getClass (surfaceFilter.filter)), true);
								
							}
							
						}
						
						frameObject.filters = filters;
						
					}
					
					frameObject.depth = i;
					frameObject.clipDepth = 0;
					frameObject.visible = true;
					
					frame.objects.push (frameObject);
					
				}
				
				sprite.frames.push (frame);
				
				return sprite;
				
			}
			
			return null;
			
		}
		
		if (Std.is (tag, TagDefineButton)) {
			
			var defineButton:TagDefineButton = cast tag;
			
			symbol.downState = processRecords (defineButton.getRecordsByState (TagDefineButton.STATE_DOWN));
			symbol.hitState = processRecords (defineButton.getRecordsByState (TagDefineButton.STATE_HIT));
			symbol.overState = processRecords (defineButton.getRecordsByState (TagDefineButton.STATE_OVER));
			symbol.upState = processRecords (defineButton.getRecordsByState (TagDefineButton.STATE_UP));
			
		} else {
			
			var defineButton:TagDefineButton2 = cast tag;
			
			symbol.downState = processRecords (defineButton.getRecordsByState (TagDefineButton.STATE_DOWN));
			symbol.hitState = processRecords (defineButton.getRecordsByState (TagDefineButton.STATE_HIT));
			symbol.overState = processRecords (defineButton.getRecordsByState (TagDefineButton.STATE_OVER));
			symbol.upState = processRecords (defineButton.getRecordsByState (TagDefineButton.STATE_UP));
			
		}
		
		swfLite.symbols.set (symbol.id, symbol);
		
		return symbol;
		
	}
	
	
	private function addBitmap (tag:IDefinitionTag):BitmapSymbol {
		
		var alphaByteArray = null;
		var byteArray = null;
		var type = null;
		
		if (Std.is (tag, TagDefineBitsLossless)) {
			
			var data:TagDefineBitsLossless = cast tag;
			
			var transparent = (data.level > 1);
			var buffer = data.zlibBitmapData;
			buffer.uncompress ();
			buffer.position = 0;
			
			if (data.bitmapFormat == BitmapFormat.BIT_8) {
				
				var palette = Bytes.alloc (data.bitmapColorTableSize * 3);
				var alpha = null;
				
				if (transparent) alpha = Bytes.alloc (data.bitmapColorTableSize);
				var index = 0;
				
				for (i in 0...data.bitmapColorTableSize) {
					
					palette.set (index++, buffer.readUnsignedByte ());
					palette.set (index++, buffer.readUnsignedByte ());
					palette.set (index++, buffer.readUnsignedByte ());
					if (transparent) alpha.set (i, buffer.readUnsignedByte ());
					
				}
				
				var paddedWidth:Int = Math.ceil (data.bitmapWidth / 4) * 4;
				var values = Bytes.alloc ((data.bitmapWidth + 1) * data.bitmapHeight);
				index = 0;
				
				for (y in 0...data.bitmapHeight) {
					
					values.set (index++, 0);
					values.blit (index, buffer, buffer.position, data.bitmapWidth);
					index += data.bitmapWidth;
					buffer.position += paddedWidth;
					
				}
				
				var png = new List ();
				png.add (CHeader ( { width: data.bitmapWidth, height: data.bitmapHeight, colbits: 8, color: ColIndexed, interlaced: false } ));
				png.add (CPalette (palette));
				if (transparent) png.add(CUnknown("tRNS", alpha));
				png.add (CData (Deflate.run (values)));
				png.add (CEnd);
				
				var output = new BytesOutput ();
				var writer = new Writer (output);
				writer.write (png);
				
				byteArray = ByteArray.fromBytes (output.getBytes ());
				type = BitmapType.PNG;
				
			} else {
				
				var bitmapData = new BitmapData (data.bitmapWidth, data.bitmapHeight, transparent);
				
				bitmapData.image.buffer.premultiplied = false;
				bitmapData.setPixels (bitmapData.rect, buffer);
				bitmapData.image.buffer.premultiplied = true;
				bitmapData.image.premultiplied = false;
				
				byteArray = bitmapData.encode (bitmapData.rect, new PNGEncoderOptions ());
				type = BitmapType.PNG;
				
			}
			
		} else if (Std.is (tag, TagDefineBitsJPEG2)) {
			
			var data:TagDefineBitsJPEG2 = cast tag;
			
			if (Std.is (tag, TagDefineBitsJPEG3)) {
				
				var alpha = cast (tag, TagDefineBitsJPEG3).bitmapAlphaData;
				alpha.uncompress ();
				alpha.position = 0;
				
				if (alphaPalette == null) {
					
					alphaPalette = Bytes.alloc (256 * 3);
					var index = 0;
					
					for (i in 0...256) {
						
						alphaPalette.set (index++, i);
						alphaPalette.set (index++, i);
						alphaPalette.set (index++, i);
						
					}
					
				}
				
				var tempFile = lime.tools.helpers.PathHelper.getTemporaryFile ("jpg");
				sys.io.File.saveBytes (tempFile, data.bitmapData);
				var image = lime.graphics.format.JPEG.decodeFile (tempFile, false);
				try { sys.FileSystem.deleteFile (tempFile); } catch (e:Dynamic) {}
				
				var values = Bytes.alloc ((image.width + 1) * image.height);
				var index = 0;
				
				for (y in 0...image.height) {
					
					values.set (index++, 0);
					values.blit (index, alpha, alpha.position, image.width);
					index += image.width;
					alpha.position += image.width;
					
				}
				
				var png = new List ();
				png.add (CHeader ( { width: image.width, height: image.height, colbits: 8, color: ColIndexed, interlaced: false } ));
				png.add (CPalette (alphaPalette));
				png.add (CData (Deflate.run (values)));
				png.add (CEnd);
				
				var output = new BytesOutput ();
				var writer = new Writer (output);
				writer.write (png);
				
				alphaByteArray = ByteArray.fromBytes (output.getBytes ());
				byteArray = data.bitmapData;
				type = BitmapType.JPEG_ALPHA;
				
			} else {
				
				byteArray = data.bitmapData;
				type = BitmapType.JPEG;
				
			}
			
		} else if (Std.is (tag, TagDefineBits)) {
			
			var data:TagDefineBits = cast tag;
			
			byteArray = data.bitmapData;
			type = BitmapType.JPEG;
			
		}
		
		if (byteArray != null) {
			
			var symbol = new BitmapSymbol ();
			symbol.id = tag.characterId;
			
			bitmapAlpha.set (symbol.id, alphaByteArray);
			bitmaps.set (symbol.id, byteArray);
			bitmapTypes.set (symbol.id, type);
			
			symbol.path = "";
			swfLite.symbols.set (symbol.id, symbol);
			
			return symbol;
			
		}
		
		return null;
		
	}
	
	
	private function addFont (tag:IDefinitionTag):FontSymbol {
		
		if (Std.is (tag, TagDefineFont2)) {
			
			var defineFont:TagDefineFont2 = cast tag;
			var symbol = new FontSymbol ();
			symbol.id = defineFont.characterId;
			symbol.glyphs = new Array<Array<ShapeCommand>> ();
			
			//for (i in 0...defineFont.glyphShapeTable.length) {
				//
				//var handler = new ShapeCommandExporter (data);
				//defineFont.export (handler, i);
				//symbol.glyphs.push (handler.commands);
				//
			//}
			
			symbol.advances = new Array<Int> ();
			//symbol.advances = cast defineFont.fontAdvanceTable.copy ();
			symbol.ascent = defineFont.ascent;
			symbol.bold = defineFont.bold;
			symbol.codes = defineFont.codeTable.copy ();
			symbol.descent = defineFont.descent;
			symbol.italic = defineFont.italic;
			symbol.leading = defineFont.leading;
			symbol.name = defineFont.fontName;
			
			swfLite.symbols.set (symbol.id, symbol);
			
			return symbol;
			
		}
		
		return null;
		
	}
	
	
	private function addShape (tag:TagDefineShape):SWFSymbol {
		
		var handler = new ShapeCommandExporter (data);
		tag.export (handler);
		
		// TODO: Remove need for this optimization
		
		#if !disable_bitmap_optimization
		var bitmaps = ShapeBitmapExporter.process (handler);
		#else
		var bitmaps:Array<Dynamic> = null;
		#end
		
		if (bitmaps != null) {
			
			var symbol = new SpriteSymbol ();
			var frame = new Frame ();
			frame.objects = [];
			frame.labels = [];
			var bitmap, frameObject;
			
			for (i in 0...bitmaps.length) {
				
				bitmap = bitmaps[i];
				
				processTag (cast data.getCharacter (bitmap.id));
				
				var bitmapSymbol:BitmapSymbol = cast swfLite.symbols.get (bitmap.id);
				
				if (bitmapSymbol != null) {
					
					// Use smoothing if a shape requests it
					
					if (bitmapSymbol.smooth == null && !bitmap.smooth) {
						
						bitmapSymbol.smooth = false;
						
					} else if (bitmapSymbol.smooth == false && bitmap.smooth) {
						
						bitmapSymbol.smooth = true;
						
					}
					
				}
				
				frameObject = new FrameObject ();
				frameObject.symbol = bitmap.id;
				frameObject.type = FrameObjectType.CREATE;
				frameObject.id = i;
				frameObject.depth = i;
				frameObject.clipDepth = 0;
				frameObject.matrix = bitmap.transform;
				frameObject.visible = true;
				
				frame.objects.push (frameObject);
				
			}
			
			symbol.frames.push (frame);
			symbol.id = tag.characterId;
			
			swfLite.symbols.set (symbol.id, symbol);
			return symbol;
			
		} else {
			
			var symbol = new ShapeSymbol ();
			symbol.id = tag.characterId;
			
			symbol.commands = handler.commands;
			
			for (command in handler.commands) {
				
				switch (command) {
					
					case BeginBitmapFill (bitmapID, _, _, _):
						
						processTag (cast data.getCharacter (bitmapID));
					
					default:
					
				}
				
			}
			
			swfLite.symbols.set (symbol.id, symbol);
			return symbol;
			
		}
		
	}
	
	
	private function addSprite (tag:SWFTimelineContainer, root:Bool = false):SpriteSymbol {
		
		var symbol = new SpriteSymbol ();
		
		if (Std.is (tag, IDefinitionTag)) {
			
			symbol.id = untyped tag.characterId;
			
		}
		
		var instances = new Array<Int> ();
		var lastModified = new Map<Int, Int> ();
		var zeroCharacter = -1;
		
		var frame, frameObject, frameData, placeTag:TagPlaceObject;
		for (frameData in tag.frames) {
			
			frame = new Frame ();

			if (frameData.label != null) {

				frame.label = frameData.label;

			}

			if (frameData.labels != null) {

				frame.labels = frameData.labels;
				
			}

			else {

				frame.labels = [];

			}
			
			instances.splice (0, instances.length);
			
			frame.objects = [];
			
			for (object in frameData.getObjectsSortedByDepth ()) {
				
				instances.push (object.placedAtIndex);
				
				if (object.placedAtIndex == 0 && object.characterId != zeroCharacter) {
					
					lastModified.remove (0);
					zeroCharacter = object.characterId;
					
				}
				
				if (!lastModified.exists (object.placedAtIndex)) {
					
					processTag (cast data.getCharacter (object.characterId));
					
					placeTag = cast tag.tags[object.placedAtIndex];
					
				} else if (object.lastModifiedAtIndex > lastModified.get (object.placedAtIndex)) {
					
					placeTag = cast tag.tags[object.lastModifiedAtIndex];
					
				} else {
					
					continue;
					
				}
				
				frameObject = new FrameObject ();
				frameObject.symbol = object.characterId;
				frameObject.id = object.placedAtIndex;
				
				frameObject.name = placeTag.instanceName;
				
				if (!lastModified.exists (object.placedAtIndex)) {
					
					frameObject.type = FrameObjectType.CREATE;
					
				} else {
					
					frameObject.type = FrameObjectType.UPDATE;
					
				}
				
				if (placeTag.matrix != null) {
					
					var matrix = placeTag.matrix.matrix;
					matrix.tx *= (1 / 20);
					matrix.ty *= (1 / 20);
					
					frameObject.matrix = matrix;
					
				}
				
				if (placeTag.colorTransform != null) {
					
					frameObject.colorTransform = placeTag.colorTransform.colorTransform;
					
				}
				
				if (placeTag.hasFilterList) {
					
					var filters:Array<FilterType> = [];
					
					for (surfaceFilter in placeTag.surfaceFilterList) {
						
						var type = surfaceFilter.type;
						
						if (type != null) {
							
							filters.push (surfaceFilter.type);
							//filterClasses.set (Type.getClassName (Type.getClass (surfaceFilter.filter)), true);
							
						}
						
					}
					
					frameObject.filters = filters;
					
				}
				
				frameObject.depth = placeTag.depth;
				frameObject.clipDepth = (placeTag.hasClipDepth ? placeTag.clipDepth : 0);
				
				if (placeTag.hasVisible) {
					
					frameObject.visible = placeTag.visible != 0;
					
				}
				
				if (placeTag.hasBlendMode) {
					
					var blendMode = BlendMode.toString (placeTag.blendMode);
					frameObject.blendMode = blendMode;
					
				}
				
				if (placeTag.hasCacheAsBitmap) {
					
					frameObject.cacheAsBitmap = placeTag.bitmapCache != 0;
					
				}
				
				lastModified.set (object.placedAtIndex, object.lastModifiedAtIndex);
				
				if (frame.objects == null) {
					
					frame.objects = [];
					
				}
				
				frame.objects.push (frameObject);
				
			}
			
			for (id in lastModified.keys ()) {
				
				if (instances.indexOf (id) == -1) {
					
					lastModified.remove (id);
					
					frameObject = new FrameObject ();
					frameObject.id = id;
					frameObject.type = FrameObjectType.DESTROY;
					
					if (frame.objects == null) {
						
						frame.objects = [];
						
					}
					
					frame.objects.push (frameObject);
					
				}
				
			}
			
			symbol.frames.push (frame);
			
		}
		
		if (root) {
			
			swfLite.root = symbol;
			
		} else {
			
			swfLite.symbols.set (symbol.id, symbol);
			
		}
		
		return symbol;
		
	}
	
	
	private function addDynamicText (tag:TagDefineEditText):DynamicTextSymbol {
		
		var symbol = new DynamicTextSymbol ();
		
		symbol.id = tag.characterId;
		symbol.border = tag.border;
		
		if (tag.hasTextColor) {
			
			symbol.color = tag.textColor;
			
		}
		
		symbol.fontHeight = tag.fontHeight;
		symbol.multiline = tag.multiline;
		symbol.selectable = !tag.noSelect;
		
		if (tag.hasText) {
			
			symbol.html = tag.html;
			symbol.text = tag.initialText;
			
		}
		
		if (tag.hasLayout) {
			
			switch (tag.align) {
				
				case 0: symbol.align = "left";
				case 1: symbol.align = "right";
				case 2: symbol.align = "center";
				case 3: symbol.align = "justify";
				
			}
			
			symbol.leftMargin = tag.leftMargin;
			symbol.rightMargin = tag.rightMargin;
			symbol.indent = tag.indent;
			symbol.leading = tag.leading;
			
		}
		
		symbol.wordWrap = tag.wordWrap;
		symbol.input = !tag.readOnly;
		
		// embedded fonts
		if (tag.hasFont) {
			
			var font:IDefinitionTag = cast data.getCharacter (tag.fontId);
			
			if (font != null) {
				
				//processTag (font);
				
			}
			
			symbol.fontID = tag.fontId;
			symbol.fontName = cast (font, TagDefineFont2).fontName;
			
		}
		
		// shared fonts
		if (tag.hasFontClass) {
			
			symbol.fontName = tag.fontClass;
			
		}
		
		var bounds = tag.bounds.rect;
		symbol.x = bounds.x;
		symbol.y = bounds.y;
		symbol.width = bounds.width;
		symbol.height = bounds.height;
		
		swfLite.symbols.set (symbol.id, symbol);
		
		return symbol;
		
	}
	
	
	private function addStaticText (tag:TagDefineText):StaticTextSymbol {
		
		var symbol = new StaticTextSymbol ();
		symbol.id = tag.characterId;
		
		var records = [];
		
		for (record in tag.records) {
			
			var textRecord = new StaticTextRecord ();
			var font:FontSymbol = null;
			var defineFont:TagDefineFont2 = null;
			
			if (record.hasFont) {
				
				textRecord.fontID = record.fontId;
				
				defineFont = cast data.getCharacter (record.fontId);
				processTag (defineFont);
				font = cast swfLite.symbols.get (record.fontId);
				
			}
			
			if (record.hasColor) textRecord.color = record.textColor;
			if (record.hasXOffset) textRecord.offsetX = record.xOffset;
			if (record.hasYOffset) textRecord.offsetY= record.yOffset;
			textRecord.fontHeight = record.textHeight;
			
			var advances = [];
			var glyphs = [];
			
			if (font != null) {
				
				var handler = new ShapeCommandExporter (data);
				
				for (glyphEntry in record.glyphEntries) {
					
					var index = glyphEntry.index;
					
					advances.push (glyphEntry.advance);
					glyphs.push (index);
					
					if (font.glyphs[index] == null) {
						
						handler.beginShape ();
						defineFont.export (handler, index);
						font.glyphs[index] = handler.commands.copy ();
						font.advances[index] = defineFont.fontAdvanceTable[index];
						
					}
					
				}
				
			}
			
			textRecord.advances = advances;
			textRecord.glyphs = glyphs;
			records.push (textRecord);
			
		}
		
		symbol.records = records;
		
		var matrix = tag.textMatrix.matrix;
		matrix.tx *= (1 / 20);
		matrix.ty *= (1 / 20);
		
		symbol.matrix = matrix;
		
		swfLite.symbols.set (symbol.id, symbol);
		
		return symbol;
		
	}

	private function addSound (tag:IDefinitionTag):Void {

		if (Std.is (tag, TagDefineSound)) {

			var defineSound:TagDefineSound = cast tag;
			
			var byteArray = defineSound.soundData;
			var type:SoundType = switch (defineSound.soundFormat) {
				case 0: SoundType.UNCOMPRESSED_NATIVE_ENDIAN;
				case 1: SoundType.ADPCM;
				case 2: SoundType.MP3;
				case 3: SoundType.UNCOMPRESSED_LITTLE_ENDIAN;
				case 4: SoundType.NELLYMOSER_16_KHZ;
				case 5: SoundType.NELLYMOSER_8_KHZ;
				case 6: SoundType.NELLYMOSER;
				case 7: SoundType.SPEEX;
				case _: throw("invalid sound type!");
			}
			sounds.set (tag.characterId, byteArray);
			soundTypes.set (tag.characterId, type);

		}

		return null;

	}	
	
	
	
	private function processSymbol (symbol:format.swf.data.SWFSymbol):Void {
		
		LogHelper.info ("", "processing symbol "+ symbol.name);
		
		var data2 = processTag (cast data.getCharacter (symbol.tagId));
		
		if (data2 != null) {
			data2.className = symbol.name;
		}
		
		// TODO: guard the rest of this code with appropriate macro
		//       cuz not everyone wants to do it this way

		
		// apply names to sounds
		if (null != sounds.get (symbol.tagId)) {
			soundSymbolClassNames.set(symbol.tagId, symbol.name);
		}
		
		// root symbol is a special case
		if (data2 == null && (~/_fla\.MainTimeline$/.match(symbol.name) || symbol.tagId == 0)) {
			data2 = swfLite.root;
			data2.className = symbol.name;
		}

		if (data2 == null) {
			LogHelper.warn ("", "could not process symbol "+ symbol.name +" at "+ symbol.tagId);
		}
		
		// we only want to operate on DefineSprite tags from here
		if (!Std.is (data2, SpriteSymbol)) {
			return;
		}
		var spriteSymbol:SpriteSymbol = cast data2; 
		
		// find the as3 class definition
		var cls = data.abcData.findClassByName(symbol.name);
		
		// get base class
		var superClsName = data.abcData.resolveMultiNameByIndex(cls.superclass);
		switch (superClsName.nameSpace) {
			case NPublic(_) if (!~/^flash\./.match(superClsName.nameSpaceName)):
				// store on SWFLite object for serialized .dat export
				spriteSymbol.baseClassName =
					("" == superClsName.nameSpaceName ? "" : 
						superClsName.nameSpaceName
							+".")
					+ superClsName.name;
				LogHelper.info ("", "data.className: " + symbol.name + ", baseClass: " + spriteSymbol.baseClassName);
			case _:
		}
		
		// get frame scripts
		if (cls.fields.length > 0) {
			for (field in cls.fields) {
				switch (field.kind) {
					case FMethod(idx, _, _, _):
						var methodName = data.abcData.resolveMultiNameByIndex(field.name);
						if (methodName != null && AVM2.FRAME_SCRIPT_METHOD_NAME.match(methodName.name)) {
							var frameNumOneIndexed = Std.parseInt(AVM2.FRAME_SCRIPT_METHOD_NAME.matched(1));
							LogHelper.info ("", "frame script #"+ frameNumOneIndexed);
							var pcodes:Array<{pos:Int, opr:OpCode}> = data.pcode[idx.getIndex()];
							var js = "";
							var prop:MultiName = null;
							var stack:Array<Dynamic> = new Array();
							var closingBrackets = [];
							var openingBrackets = [];
							indentationLevel = 0;
							var cond_break:Array<String> = [];
							var in_if:Bool = false;
							var while_loops = [];

							for (pindex in 0...pcodes.length) {

								var pcode = pcodes[pindex];
								switch (pcode.opr) {
									case OThis:
										stack.push("this");
									case OScope:
										stack.pop();
									case OPop:
										stack.pop();
									case OFindPropStrict(nameIndex):
//										prop = data.abcData.resolveMultiNameByIndex(nameIndex);
									case OGetLex(nameIndex):
										LogHelper.info ("", "OGetLex: " + nameIndex);
										prop = data.abcData.resolveMultiNameByIndex(nameIndex);

										var fullname = "";

										if (prop != null)
										{
											fullname += AVM2.getFullName(data.abcData, prop, cls);
											stack.push(fullname);
										}
									case OGetProp(nameIndex):
										var fullname = "";

										prop = data.abcData.resolveMultiNameByIndex(nameIndex);

										if (prop != null)
										{
											if (prop.name != null)
											{
												fullname += stack.pop() + "." + AVM2.getFullName(data.abcData, prop, cls);
											}
											else
											{
												var name = stack.pop();
												fullname += stack.pop() + "[" + name + "]";
											}
										}

										LogHelper.info ("", "OGetProp fullname: " + fullname);

										stack.push(fullname);
									case OSetProp(nameIndex):
										prop = data.abcData.resolveMultiNameByIndex(nameIndex);
										LogHelper.info ("", "OSetProp stack: " + prop + ", " + stack);

										var result = stack.pop();

										var name = null;

										if (prop != null)
										{
											if (prop.name != null)
											{
												name = "." + prop.name;
											}
											else
											{
												name = "[" + stack.pop() + "]";
											}
										}
										else
										{
											LogHelper.info ("", "OSetProp stack prop is null");
											break;
										}

										var instance = Std.string(stack.pop());

										if (!instance.startsWith("this"))
										{
											instance = "this" + "." + instance;
										}

										js += ind() + instance + name + " = " + result + ";";
									case OString(strIndex):
										var str = data.abcData.getStringByIndex(strIndex);
										stack.push("\"" + str + "\"");
									case OInt(i):
										stack.push(i);
										LogHelper.info ("", "int: " + i);
									case OIntRef(nameIndex):
										stack.push(data.abcData.getIntByIndex(nameIndex));
									case OSmallInt(i):
										stack.push(i);
										LogHelper.info ("", "smallint: " + i);
									case OFloat(nameIndex):
										stack.push(data.abcData.getFloatByIndex(nameIndex));
									case OCallPropVoid(nameIndex, argCount):
										var temp = AVM2.parseFunctionCall(data.abcData, cls, nameIndex, argCount, stack);

										var callpropvoid:String = "";

										if (stack.length > 0)
										{
											callpropvoid += stack.pop() + ".";
										}
										else
										{
											if(!temp.startsWith("this.")) callpropvoid += "this" + ".";
										}

										callpropvoid += temp;
										callpropvoid += ";";

										js += ind() + callpropvoid;
										// prop = null;
									case OCallProperty(nameIndex, argCount):
										LogHelper.info ("", "OCallProperty stack: " + stack);

//										stack.pop();
//										if (prop != null)
//										{
//											var temp = AVM2.getFullName(data.abcData, prop, cls) + "." + AVM2.parseFunctionCall(data.abcData, cls, nameIndex, argCount, stack);
//											trace("OCallProperty pushed to stack", temp);
//											stack.push(temp);
//										}

										var temp = AVM2.parseFunctionCall(data.abcData, cls, nameIndex, argCount, stack);

										var prop2 = data.abcData.resolveMultiNameByIndex(nameIndex);

										var result = "";

										if (prop2 != null)
										{
											if (prop2.name != "int")
											{
												result += stack.pop() + "." + temp;
											}
											else
											{
												result += temp;
											}
										}

										LogHelper.info("", "OCallProperty result" + Std.string(result));
										stack.push(result);
									case OConstructProperty(nameIndex, argCount):
										LogHelper.info ("", "OConstructProperty stack: " + stack);

										var temp = "";
										temp += AVM2.parseFunctionCall(data.abcData, cls, nameIndex, argCount, stack);
										if(temp == "int()") {
											temp = "0";
										} else if(temp.indexOf("[") == 0) {
											// Array
										} else {
											temp = "new " + temp;
										}
										stack.push(temp);

										LogHelper.info ("", "OConstructProperty value: " + temp);
									case OInitProp(nameIndex):
										LogHelper.info ("", "OInitProp stack: " + stack);

										prop = data.abcData.resolveMultiNameByIndex(nameIndex);

										var temp = stack.pop();

										js += ind() + stack.pop() + "." + prop.name + " = " + Std.string(temp) + ";";
									case ODup:
										stack.push(stack[stack.length - 1]);
									case OArray(argCount):
										LogHelper.info ("", "before array: " + stack);

										var str = "";
										var temp = [];
										for (i in 0...argCount)
										{
											temp.push(stack.pop());
										}
										temp.reverse();
										stack.push(temp);

										LogHelper.info ("", "after array: " + stack);
									case ORetVoid:
									case ONull:
										stack.push(null);
									case OOp(op):
										var operator = null;
										var incr_operator = null;

										var next_pcode = pcodes[pindex+1];
										var _inverted:Bool = false;

										// if next pcode is OpNot
										// then we actually need to negate the boolean outcome
										if(next_pcode != null) {
											switch (next_pcode.opr) {
												case OOp(_op):
													if(_op == OpNot) _inverted = true;
												case _ :
											}
										}

										switch (op) {
											case OpMul:
												operator = "*";
											case OpAdd:
												operator = "+";
											case OpSub:
												operator = "-";
											case OpDiv:
												operator = "/";
											case OpGt:
												operator = ">";
												if(_inverted) operator = "<=";
											case OpLt:
												operator = "<";
												if(_inverted) operator = ">=";
											case OpEq:
												operator = "==";
												if(_inverted) operator = "!=";
											case OpPhysEq:
												operator = "===";
												if(_inverted) operator = "!==";
											case OpGte:
												operator = ">=";
												if(_inverted) operator = "<";
											case OpLte:
												operator = "<=";
												if(_inverted) operator = ">";
											case OpAnd:
												operator = "&&";
											case OpOr:
												operator = "||";
											case OpIncr:
												incr_operator = " + 1";
											case OpDecr:
												incr_operator = " - 1";
											case OpIIncr:
												incr_operator = "++";
											case OpIDecr:
												incr_operator = "--";
											case OpNot:

											case OpAs:

											case _:
												LogHelper.warn ("", "Unhandled OOp: " + op, true);
										}

										if (op == OpAs)
										{
											var discard = stack.pop();
											LogHelper.info ("", "cast to " + discard + " is discarded");
										}

										if (operator != null)
										{
											var temp = stack.pop();
											stack.push(Std.string(stack.pop()) + " " + operator + " " + Std.string(temp));
										}

										if (incr_operator != null)
										{
											stack.push(Std.string(stack.pop()) + incr_operator);
										}
									case OJump(j, delta):

										var if_cond = null;
										
										switch (j) {
											case JNeq | JEq | JPhysNeq | JPhysEq | JNotGt | JNotLt | JNotGte | JNotLte | JLt | JGt | JLte | JGte :

												var operator = null;
												var next_pcode = pcodes[pindex+1];
												var _inverted:Bool = false;

												// if next pcode is an Always Jump,
												// then we're actually checking the opposite
												if(next_pcode != null) {
													switch (next_pcode.opr) {
														case OJump(_j, _d):
															if(_j == JAlways) _inverted = true;
														case _ :
													}
												}

												if(!_inverted) {
													switch(j) {
														case JNeq:
															operator = "==";
														case JEq:
															operator = "!=";
														case JPhysNeq:
															operator = "===";
														case JPhysEq:
															operator = "!==";
														case JNotGt:
															operator = ">";
														case JNotLt:
															operator = "<";
														case JNotGte:
															operator = ">=";
														case JNotLte:
															operator = "<=";
														case JLt:
															operator = "<";
														case JGt:
															operator = ">";
														case JLte:
															operator = "<=";
														case JGte:
															operator = ">=";
														case _:
													}
												} else {
													switch(j) {
														case JNeq:
															operator = "!=";
														case JEq:
															operator = "==";
														case JPhysNeq:
															operator = "!==";
														case JPhysEq:
															operator = "===";
														case JNotGt:
															operator = "<=";
														case JNotLt:
															operator = ">=";
														case JNotGte:
															operator = "<";
														case JNotLte:
															operator = ">";
														case JLt:
															operator = ">=";
														case JGt:
															operator = "<=";
														case JLte:
															operator = ">";
														case JGte:
															operator = "<";
														case _:
													}
												}

												var temp = stack.pop();

												if_cond = Std.string(stack.pop()) + " " + operator + " " + Std.string(temp);

												if (closingBrackets.indexOf(pcode.pos + delta) == -1)
												{
													closingBrackets.push(pcode.pos + delta);
												}

												LogHelper.info("", "indentationLevel " + indentationLevel + " jump style " + j + "closingBrackets" + Std.string(closingBrackets));
											case JAlways:
												LogHelper.info("", "JAlways " + delta + " " + pcode.pos);

//												if (closingBrackets.indexOf(pcode.pos + delta) == -1)
//												{
													closingBrackets.push(pcode.pos + delta);
//												}
											case JFalse:
												if((pcodes[pindex-1] != null && pcodes[pindex-1].opr == ODup) && (pcodes[pindex+1] != null && pcodes[pindex+1].opr == OPop )) {
													// We are in between an "AND" if conditional
													cond_break.push("&&");
													if_cond = Std.string(stack.pop());
												}else{
													if_cond = Std.string(stack.pop());
													if (closingBrackets.indexOf(pcode.pos + delta) == -1)
													{
														closingBrackets.push(pcode.pos + delta);
													}
												}
												LogHelper.info("", "indentationLevel " + indentationLevel + " jump style " + j + " closingBrackets " + closingBrackets);
											case JTrue:
												if((pcodes[pindex-1] != null && pcodes[pindex-1].opr == ODup) && (pcodes[pindex+1] != null && pcodes[pindex+1].opr == OPop )) {
													// We are in between an "OR" if conditional
													cond_break.push("||");
													if_cond = Std.string(stack.pop());
												}else{
													if_cond = "!" + Std.string(stack.pop());
													if (closingBrackets.indexOf(pcode.pos + delta) == -1)
													{
														closingBrackets.push(pcode.pos + delta);
													}
												}
												LogHelper.info("", "indentationLevel " + indentationLevel + " jump style " + j + " closingBrackets " + closingBrackets);
											case _:
												LogHelper.info ("", "OJump" + j + delta);
										}

										LogHelper.info("", Std.string(closingBrackets));

										var in_while = false;
										var out = "";
										if(if_cond != null) {
											if(!in_if) {
												if(while_loops.indexOf(pcode.pos + delta + 1) > -1) {
													out += "while (" + if_cond;
													in_while = true;
												} else {
													// Already have indentation from "else"
													if(js.endsWith("else ")) {
														out += "if (" + if_cond;
													}else{
														out += ind() + "if (" + if_cond;
													}
												}
											} else {
												out += if_cond;
											}

											// If the next pcode is a OPop we're in a conditional
											if((pcodes[pindex+1] != null && pcodes[pindex+1].opr == OPop) || (pcodes[pindex+2] != null && pcodes[pindex+2].opr == OPop)) {
												out += " " + cond_break.pop() + " ";
												in_if = true;
											} else {
												if(in_while) {
													out += ")";
												}else{
													out += ")" + ind() + "{";
													indentationLevel++;
												}
 												in_if = false;
											}
										}

										if(while_loops.indexOf(pcode.pos + delta + 1) > -1) {
											js = js.replace("[[[loop"+ (pcode.pos + delta + 1) +"]]]", out);
											//indentationLevel--;
											closingBrackets.push(pcode.pos);
											//js += ind() + "}";
										} else if (out != "") {
											js += out;
										}

										LogHelper.info("", j + " " + delta);
									case OTrue:
										stack.push(true);
									case OFalse:
										stack.push(false);
									case OLabel:
										// Indicator for while loop position
										// OJump(JAlways) can bring us back here at end of loop
										LogHelper.info ("", "Label reached " + pcode);

										var prev_pcode = pcodes[pindex-1];

										// if next pcode is a Label,
										// then we're actually in a while loop
										if(prev_pcode != null) {
											switch (prev_pcode.opr) {
												case OJump(_j, _delta):
													if (_j == JAlways) 
														while_loops.push((pcode.pos));
														js += ind() + "[[[loop"+ (pcode.pos) +"]]]";
														js += ind() + "{";
														indentationLevel++;
												case _ :
											}
										}

									case _:
										// TODO: throw() on unsupported pcodes
										LogHelper.warn ("", "unsupported pcode "+ pcode, true);
										//throw(pcode);
								}

								for (i in 0...closingBrackets.length) {
									if(in_if) break;
									if (indentationLevel > -1 && pcode.pos == closingBrackets[i])
									{
										LogHelper.info("", "found a pcode for opening bracket" + pcode);
										if(indentationLevel > 0) {
											indentationLevel--;
											js += ind() + "}";
										}
										closingBrackets.remove(i);
										LogHelper.info("", "decreased indentationLevel" + indentationLevel + " " + closingBrackets);

										switch (pcode.opr) {
											case OJump(j, delta):
												if (j == JAlways) {
													if(delta < 0) return;
													js += ind() + "else ";

													var foundConditionals = false;

													for (k in pcodes.indexOf(pcode)+1...pcodes.length) {
														LogHelper.info("", "pcodes to look for conditional" + pcodes[k]);

														switch(pcodes[k].opr) {
															case OSetProp(_) | OCallPropVoid(_, _) | OInitProp(_):
																foundConditionals = false;
																break;
															case OJump(_, _):
																foundConditionals = true;
																break;
															case _:

														}

														if (pcodes[k].pos > pcode.pos + delta) {
															break;
														}
														else
														{
															if (pcodes[k].opr.match(OJump(j2, delta2))) {
																foundConditionals = true;
															}
														}
													}

													LogHelper.info("", "foundConditionals" + foundConditionals);
													if (!foundConditionals) {
														js += ind() + "{";
														indentationLevel += 1;
														LogHelper.info("", "indentationLevel" + j + indentationLevel + closingBrackets);
													}
												}
											case _:
										}
//										break;
									}

//									if (pcode.pos == openingBrackets[i])
//									{
//										trace("found a pcode for a OJump (JNeq)", pcode);
//										openingBrackets.remove(i);
//
//										var index = pcodes.indexOf(pcode);
//
//										if (index + 1 < pcodes.length - 1)
//										{
//											switch (pcodes[index + 1].opr)
//											{
//												case OJump(jumpStyle, delta):
//													trace("pcode is OJump", jumpStyle);
//												case _:
//													trace("pcode", pcodes[index + 1].opr);
//											}
//										}
//
//										js += ind() + "{ \\\\opening\n";
//										break;
//									}
								}
							}

							var _force_close = (indentationLevel > 0);
							while (indentationLevel > 0) {
								indentationLevel--;
								js += ind() + "}";
							}
							if(_force_close) js += ind() + "// force close due to same bracket close collision, double-check statements";

							// take care of common replacements
							js = js.replace(" int(", " parseInt(");
							js = js.replace("flash_", "openfl_");
							js = js.replace("flash.", "openfl.");
							js = js.replace ("fl_motion", "wwlib_graphics");

							LogHelper.info ("", "javascript:\n"+js);

							LogHelper.info("", Std.string(pcodes));
							// store on SWFLite object for serialized .dat export
							spriteSymbol.frames[frameNumOneIndexed-1].scriptSource = js;
						}
					case _:
				}
			}
		}
	}
	
	
	private function processTag (tag:IDefinitionTag):SWFSymbol {
		
		if (tag == null) return null;
		
		if (!swfLite.symbols.exists (tag.characterId)) {
			
			if (Std.is (tag, TagDefineSprite)) {
				
				var data2 = addSprite (cast tag);
				data2.className = "Sprite" + data2.id;
				return data2;
				
			} else if (Std.is (tag, TagDefineBits) || Std.is (tag, TagDefineBitsJPEG2) || Std.is (tag, TagDefineBitsLossless)) {
				
				return addBitmap (tag);
				
			} else if (Std.is (tag, TagDefineButton) || Std.is (tag, TagDefineButton2)) {
				
				return addButton (cast tag);
				
			} else if (Std.is (tag, TagDefineEditText)) {
				
				return addDynamicText (cast tag);
				
			} else if (Std.is (tag, TagDefineText)) {
				
				return addStaticText (cast tag);
				
			} else if (Std.is (tag, TagDefineShape)) {
				
				return addShape (cast tag);
				
			} else if (Std.is (tag, TagDefineFont) || Std.is (tag, TagDefineFont4)) {
				
				return addFont (tag);
				
			} else if (Std.is (tag, TagDefineSound)) {

				addSound (tag);

			}
			
			return null;
			
		} else {
			
			return swfLite.symbols.get (tag.characterId);
			
		}
		
	}

	public static function ind():String
	{
		var a:String = "\n";
		for(_ in 0...indentationLevel) a += "	";
		return a;
	}
	
}


enum BitmapType {
	
	PNG;
	JPEG_ALPHA;
	JPEG;
	
}

enum SoundType {
	UNCOMPRESSED_NATIVE_ENDIAN;
	ADPCM;
	MP3;
	UNCOMPRESSED_LITTLE_ENDIAN;
	NELLYMOSER_16_KHZ;
	NELLYMOSER_8_KHZ;
	NELLYMOSER;
	SPEEX;
}

/**
 * AVM2 ActionScript3 Byte Code (ABC) Instruction Traversal
 */

typedef MultiName = {
	var name: String;
	var nameIndex: Index<Name>;
	var nameSpace: Namespace;
	var nameSpaceName: String;
} 

class AVM2 {
	public static var FRAME_SCRIPT_METHOD_NAME = ~/frame(\d+)/;
	
	public static function getIndex<T>( idx: Index<T>): Int {
		return switch(idx) {
			case Idx(i): i;
		};
	}
	
	public static function getMultiNameByIndex(abcData: ABCData, i: Index<Name>): Name {
		return abcData.names[i.getIndex()-1];
	}

	public static function getStringByIndex(abcData: ABCData, i: Index<String>): String {
		return abcData.strings[i.getIndex()-1];
	}

	public static function getIntByIndex(abcData: ABCData, i: Index<Int>): Int {
		return abcData.ints[i.getIndex()-1];
	}

	public static function getFloatByIndex(abcData: ABCData, i: Index<Float>): Float {
		return abcData.floats[i.getIndex()-1];
	}

	public static function getNameSpaceByIndex(abcData: ABCData, i: Index<Namespace>): Namespace {
		return abcData.namespaces[i.getIndex()-1];
	}

	public static function getFunctionByIndex(abcData: ABCData, i: Index<MethodType>): Function {
		return abcData.functions[i.getIndex()];
	}
	
	public static function resolveMultiNameByIndex(abcData: ABCData, i: Index<Name>): MultiName {
		var multiName = abcData.getMultiNameByIndex(i);
		switch (multiName) {
			case NName(nameIndex, nsIndex): // a.k.a. QName
				var nameSpace = abcData.getNameSpaceByIndex(nsIndex);
				switch (nameSpace) {
					case NPublic(nsNameIndex) | NInternal(nsNameIndex) | NPrivate(nsNameIndex) | NProtected(nsNameIndex): // a.k.a. PackageNamespace, PackageInternalNS
						return {
							name: abcData.getStringByIndex(nameIndex),
							nameIndex: i,
							nameSpace: nameSpace,
							nameSpaceName: abcData.getStringByIndex(nsNameIndex)
						}
					case _:
						LogHelper.warn ("", "other type of namespace " + nameSpace);
				}
			case NMulti(nameIndex, nsIndexSet):
				return {
					name: abcData.getStringByIndex(nameIndex),
					nameIndex: i,
					nameSpace: null,
					nameSpaceName: null
				}
			case NMultiLate(nset):
				return {
					name: null,
					nameIndex: i,
					nameSpace: null,
					nameSpaceName: null
				}
			case _:
				LogHelper.warn ("", "other type of name " + multiName);
		}
		return null;
	}
	
	public static function findClassByName(abcData: ABCData, s: String): ClassDef {
		var x = s.lastIndexOf(".");
		var pkgName = "";
		var clsName = s;
		if (-1 != x) {
			pkgName = s.substr(0, x);
			clsName = s.substr(x+1);
		}
		for (cls in abcData.classes) {
			if (cls.isInterface) continue;

			var multiName = abcData.resolveMultiNameByIndex(cls.name);

			if (multiName != null)
			{
				if (clsName == multiName.name &&
					pkgName == multiName.nameSpaceName)
				{
					return cls;
				}
			}
			else
			{
				LogHelper.info ("", "multiname: " + multiName);
			}
		}

		return null;
	}

	public static function classHasField(abcData: ABCData, cls: ClassDef, name: String):Bool
	{
		var classHasField = false;

		for (field in cls.fields) {
			switch (field.kind) {
				case FMethod(idx, _, _, _):
					var methodName = abcData.resolveMultiNameByIndex(field.name);
					if (methodName.name == name)
					{
						classHasField = true;
						break;
					}
				case FVar(_, _, _):
					var methodName = abcData.resolveMultiNameByIndex(field.name);
					if (methodName.name == name)
					{
						classHasField = true;
						break;
					}
				case _:
			}
		}

		return classHasField;
	}

	public static function getFullName(abcData: ABCData, prop: MultiName, cls:ClassDef): String
	{
		var js = null;

		if (prop == null)
		{
			LogHelper.info ("", "unable to get full name of property, prop = null");
			return "";
		}

		if (prop.nameSpace == null)
		{
			LogHelper.info ("", "namespace is null");
			js = prop.name;
		}
		else
		{
			switch (prop.nameSpace) {
				case NPublic(_) if ("" != prop.nameSpaceName):
					js = prop.nameSpaceName.replace(".", "_") +"_"+ prop.name;
				case NProtected(_) if ("" != prop.nameSpaceName):
					js = prop.nameSpaceName.replace(".", "_") +"_"+ prop.name;
				case NInternal(_) if (cls.name == prop.nameIndex):
					js = "this." + prop.name;
				case NPublic(_):
					switch (prop.name) {
						case "trace":
							js = "console.log";
						case _:
//						var classHasField = classHasField(abcData, cls, prop.name);
//
//						if (classHasField)
//						{
//							js = "this." + prop.name;
//						}
//						else
//						{
							js = prop.name;
//						}
					}
				case NPrivate(_) | NInternal(_) | NProtected(_) :
					LogHelper.info ("", "Namespace "+ prop.nameSpace + " " + prop.name);
					js = prop.name;
				case _:
					// TODO: throw() on unsupported namespaces
					LogHelper.warn ("", "unsupported namespace "+ prop.nameSpace);
			}
		}

		return js;
	}

	public static function parseFunctionCall(abcData: ABCData, cls: ClassDef, nameIndex: IName, argCount: Int, stack:Array<Dynamic>):String
	{
		var is_array:Bool = false;
		var prop = abcData.resolveMultiNameByIndex(nameIndex);

		if (prop == null)
		{
			LogHelper.info ("", "parseFunctionCall is stopped, prop = null");
			return "";
		}

		var js = getFullName(abcData, prop, cls);
		if(js == "Array") {
			js = "[";
			is_array = true;
		}else {
			// invoke function
			js += "(";
		}

		var temp = [];
		for (i in 0...argCount) {
//			if (i > 0) js += ", ";
			var arg = stack.pop();
			if (Std.is(arg, String))
			{
//				js += arg;
				temp.push(arg);
			}
			else
			{
//				js += haxe.Json.stringify(arg);
				temp.push(haxe.Json.stringify(arg));
			}
		}
		temp.reverse();
		js += temp.join(", ");
		if(is_array) {
			js += "]";
		} else {
			js += ")";
		}

		return js;
	}

}